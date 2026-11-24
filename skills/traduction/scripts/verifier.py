#!/usr/bin/env python3
"""Compare une page source et sa traduction pour repérer ce que la traduction a cassé.

Exemples :
    python3 verifier.py tp-travail/sujet/source.wiki tp-travail/sujet/en.wiki --lang en
    python3 verifier.py --json tp-travail/sujet/source.json tp-travail/sujet/en.json

Mode wikitext : modèles et noms de paramètres, valeurs protégées, fichiers, références,
titres, tableaux, liens interlangues, espaces de noms restés en français, liens internes,
espaces collés aux liens, écart de longueur (oubli ou ajout de texte).

Mode --json : sous-page JSON d'un graphique ; même structure, mêmes nombres, mêmes
identifiants, dates et couleurs, seuls les textes changent.

Code de sortie 1 s'il y a au moins une erreur ; les avertissements sont à examiner.
"""

import argparse
import json
import re
import sys
import unicodedata

# Paramètres dont la valeur ne se traduit jamais (voir references/parametres-proteges.md).
PROTECTED_PARAMS = {
    "glyph", "icone", "banniere", "photo de l'agriculteur", "logo", "photo d'illustration",
    "logo organisme", "image", "class", "type de page", "frame", "query",
}
# Paramètre dont la valeur change de façon attendue (chemin de la sous-page traduite).
JSON_PARAM = "json"

FILE_NAMESPACES = r"(?:Fichier|File|Image|Datei|Archivo|Ficheiro|Bestand|Plik|Immagine)"
FRENCH_NAMESPACES = ("Catégorie:", "Fichier:", "Modèle:", "Formulaire:", "Utilisateur:", "Aide:", "Portail:")
LANG_CODES = {"fr", "en", "de", "es", "it", "nl", "pl", "pt", "ar", "el", "fi", "hu"}
STRUCTURAL_LINK = re.compile(
    rf"^:?\s*(?:{FILE_NAMESPACES}|Catégorie|Category|Media|Média|{'|'.join(sorted(LANG_CODES))})\s*:",
    re.IGNORECASE,
)

errors = []
warnings = []


def error(message):
    errors.append(message)


def warn(message):
    warnings.append(message)


def normalize(name):
    name = name.strip().lower()
    return "".join(c for c in unicodedata.normalize("NFD", name) if unicodedata.category(c) != "Mn")


# --- Analyse du wikitext ---------------------------------------------------------------

def strip_comments(text):
    return re.sub(r"<!--.*?-->", "", text, flags=re.DOTALL)


def find_templates(text):
    """Retourne tous les appels {{...}} (imbriqués compris), dans l'ordre d'ouverture."""
    found = []
    stack = []
    i = 0
    while i < len(text) - 1:
        pair = text[i:i + 2]
        if pair == "{{":
            # {{{paramètre}}} : argument de modèle, pas un appel
            if text[i:i + 3] == "{{{":
                end = text.find("}}}", i)
                if end != -1:
                    i = end + 3
                    continue
            stack.append(i)
            i += 2
        elif pair == "}}" and stack:
            start = stack.pop()
            found.append((start, text[start:i + 2]))
            i += 2
        else:
            i += 1
    found.sort()
    return [body for _, body in found]


def split_top_level(inner):
    """Découpe le contenu d'un modèle sur les | qui ne sont pas dans un {{ }} ou [[ ]] imbriqué."""
    parts, depth_braces, depth_brackets, current = [], 0, 0, []
    i = 0
    while i < len(inner):
        pair = inner[i:i + 2]
        if pair == "{{":
            depth_braces += 1
            current.append(pair)
            i += 2
            continue
        if pair == "}}" and depth_braces:
            depth_braces -= 1
            current.append(pair)
            i += 2
            continue
        if pair == "[[":
            depth_brackets += 1
            current.append(pair)
            i += 2
            continue
        if pair == "]]" and depth_brackets:
            depth_brackets -= 1
            current.append(pair)
            i += 2
            continue
        if inner[i] == "|" and not depth_braces and not depth_brackets:
            parts.append("".join(current))
            current = []
        else:
            current.append(inner[i])
        i += 1
    parts.append("".join(current))
    return parts


def parse_template(body):
    """Retourne (nom, [(clé, valeur)]) ; clé positionnelle = '1', '2'…"""
    inner = body[2:-2]
    if inner.lstrip().startswith("#") and ":" in inner:
        name, rest = inner.split(":", 1)
        return name.strip(), [("1", rest)]
    parts = split_top_level(inner)
    name = parts[0].strip()
    params, position = [], 0
    for part in parts[1:]:
        if "=" in part and not part.split("=", 1)[0].count("{{") and not part.split("=", 1)[0].count("[["):
            key, value = part.split("=", 1)
            params.append((key.strip(), value.strip()))
        else:
            position += 1
            params.append((str(position), part.strip()))
    return name, params


def wikilinks(text):
    return re.findall(r"\[\[([^\[\]]+?)\]\]", text)


def file_names(text):
    names = [m.strip() for m in re.findall(rf"\[\[\s*{FILE_NAMESPACES}\s*:([^|\]]+)", text, re.IGNORECASE)]
    for gallery in re.findall(r"<gallery[^>]*>(.*?)</gallery>", text, re.DOTALL | re.IGNORECASE):
        for line in gallery.splitlines():
            line = re.sub(rf"^\s*{FILE_NAMESPACES}\s*:", "", line.strip(), flags=re.IGNORECASE)
            if line:
                names.append(line.split("|", 1)[0].strip())
    return [n.replace("_", " ") for n in names]


def interlanguage_links(text):
    """Liens interlangues véritables : [[xx:Titre]] sans deux-points initial."""
    return [(m.group(1).lower(), m.group(2).strip())
            for m in re.finditer(r"\[\[([a-z]{2,3}):([^\]|]+)\]\]", text)
            if m.group(1).lower() in LANG_CODES]


def plain_text(text):
    """Texte visible approximatif : sans modèles, balises ni liens structurels."""
    text = strip_comments(text)
    for body in sorted(set(find_templates(text)), key=len, reverse=True):
        text = text.replace(body, " ")
    text = re.sub(r"<ref[^>]*/>|<ref[^>]*>.*?</ref>", " ", text, flags=re.DOTALL)
    text = re.sub(r"<[^>]+>", " ", text)
    text = re.sub(r"\[\[[^\]]*\]\]", lambda m: m.group(0).split("|")[-1] if not STRUCTURAL_LINK.match(m.group(0)[2:]) else " ", text)
    return re.sub(r"\s+", " ", text).strip()


def count(pattern, text, flags=re.MULTILINE):
    return len(re.findall(pattern, text, flags))


def check_wikitext(source, target, lang, source_lang):
    source, target = strip_comments(source), strip_comments(target)

    # Équilibre des délimiteurs
    for opening, closing in (("{{", "}}"), ("[[", "]]"), ("{|", "|}")):
        if target.count(opening) != target.count(closing):
            error(f"{opening} et {closing} déséquilibrés dans la traduction "
                  f"({target.count(opening)} / {target.count(closing)})")

    # Modèles : même suite de noms, mêmes clés, valeurs protégées intactes
    src_tpl = [parse_template(t) for t in find_templates(source)]
    tgt_tpl = [parse_template(t) for t in find_templates(target)]
    src_names = [n for n, _ in src_tpl]
    tgt_names = [n for n, _ in tgt_tpl]
    if src_names != tgt_names:
        missing = [n for n in src_names if src_names.count(n) > tgt_names.count(n)]
        added = [n for n in tgt_names if tgt_names.count(n) > src_names.count(n)]
        error("Les modèles diffèrent de la source"
              + (f" ; manquants ou renommés : {', '.join(sorted(set(missing)))}" if missing else "")
              + (f" ; ajoutés : {', '.join(sorted(set(added)))}" if added else ""))
    for index, ((s_name, s_params), (t_name, t_params)) in enumerate(zip(src_tpl, tgt_tpl), 1):
        if s_name != t_name:
            continue
        s_keys = [k for k, _ in s_params]
        t_keys = [k for k, _ in t_params]
        if s_name.startswith("#"):
            continue
        if s_keys != t_keys:
            lost = [k for k in s_keys if k not in t_keys]
            new = [k for k in t_keys if k not in s_keys]
            error(f"Modèle n°{index} {{{{{s_name}}}}} : paramètres modifiés"
                  + (f" ; disparus : {', '.join(lost)}" if lost else "")
                  + (f" ; nouveaux (nom traduit ?) : {', '.join(new)}" if new else ""))
        t_values = dict(t_params)
        for key, value in s_params:
            norm = normalize(key)
            if norm in PROTECTED_PARAMS and key in t_values and t_values[key] != value:
                error(f"{{{{{s_name}}}}} : la valeur de « {key} » ne doit pas être traduite "
                      f"(« {value} » devenu « {t_values[key]} »)")
            if norm == JSON_PARAM and key in t_values:
                if t_values[key] == value and lang != source_lang:
                    warn(f"{{{{{s_name}}}}} : « json » pointe encore vers la sous-page source « {value} »")
                elif not t_values[key].lower().endswith(".json") or "/" not in t_values[key]:
                    error(f"{{{{{s_name}}}}} : « json » doit être « <Titre traduit>/<Nom>.json » "
                          f"(trouvé « {t_values[key]} »)")
                else:
                    print(f"Sous-page JSON : {value} → {t_values[key]} (à créer sur le wiki cible)")

    # Fichiers
    s_files, t_files = sorted(file_names(source)), sorted(file_names(target))
    if s_files != t_files:
        lost = sorted(set(s_files) - set(t_files))
        new = sorted(set(t_files) - set(s_files))
        error("Les fichiers diffèrent"
              + (f" ; disparus ou renommés : {', '.join(lost)}" if lost else "")
              + (f" ; nouveaux : {', '.join(new)}" if new else ""))

    # Structure
    checks = (
        ("de références <ref>", r"<ref[\s>/]", re.IGNORECASE),
        ("de titres de section", r"^=+[^=].*=+\s*$", re.MULTILINE),
        ("de tableaux", r"^\s*\{\|", re.MULTILINE),
        ("d’éléments de liste", r"^[*#]+", re.MULTILINE),
        ("de galeries", r"<gallery", re.IGNORECASE),
    )
    for label, pattern, flags in checks:
        s, t = count(pattern, source, flags), count(pattern, target, flags)
        if s != t:
            (error if label in ("de références <ref>", "de tableaux", "de galeries") else warn)(
                f"Nombre {label} : {s} dans la source, {t} dans la traduction")

    # Liens interlangues
    for m in re.finditer(r"\[\[:([a-z]{2,3}):([^\]]+)\]\]", target):
        if m.group(1) in LANG_CODES:
            error(f"[[:{m.group(1)}:{m.group(2)}]] est un lien dans le texte, pas un lien interlangue : "
                  f"écris [[{m.group(1)}:{m.group(2)}]]")
    links = interlanguage_links(target)
    langs = [l for l, _ in links]
    if lang and lang in langs:
        error(f"La traduction contient un lien interlangue vers sa propre langue ([[{lang}:…]])")
    for code in set(langs):
        if langs.count(code) > 1:
            error(f"Plusieurs liens interlangues vers « {code} »")
    if source_lang and source_lang != lang and source_lang not in langs:
        warn(f"Lien interlangue [[{source_lang}:<Titre source>]] absent de la traduction")

    # Espaces de noms restés en français
    if lang and lang != "fr":
        for ns in FRENCH_NAMESPACES:
            n = target.count("[[" + ns) + target.count("[[:" + ns)
            if n:
                error(f"{n} lien(s) avec l'espace de noms français « {ns} » dans la traduction")

    # Liens internes (LinkTitles les posera)
    internal = [l for l in wikilinks(target) if not STRUCTURAL_LINK.match(l)]
    if internal:
        shown = ", ".join(f"[[{l}]]" for l in internal[:5])
        warn(f"{len(internal)} lien(s) interne(s) restant(s) ({shown}{'…' if len(internal) > 5 else ''}) : "
             "remplace-les par leur texte traduit, LinkTitles posera les liens du wiki cible")

    # Espaces collés aux liens
    glued = r"[^\W\d_]\[\[(?!" + FILE_NAMESPACES + r")|\]\][^\W\d_]{3,}"
    s_glued, t_glued = len(re.findall(glued, source)), len(re.findall(glued, target))
    if t_glued > s_glued:
        warn(f"{t_glued - s_glued} lien(s) collé(s) au mot voisin (espace perdu, ex. « The[[…]]are »)")

    # Longueur du texte visible
    s_len, t_len = len(plain_text(source)), len(plain_text(target))
    if s_len > 200:
        ratio = t_len / s_len
        if ratio < 0.6:
            error(f"Traduction beaucoup plus courte que la source ({ratio:.0%}) : passage oublié ?")
        elif ratio > 1.6:
            error(f"Traduction beaucoup plus longue que la source ({ratio:.0%}) : texte ajouté ?")
        elif ratio < 0.75 or ratio > 1.35:
            warn(f"Longueur du texte : {ratio:.0%} de la source, vérifie qu'il ne manque ni ne s'ajoute rien")


# --- Sous-pages JSON -------------------------------------------------------------------

UNTOUCHABLE_KEYS = {"id", "color", "colour", "couleur", "type", "category", "categorie", "icon", "symbol"}
DATE_RE = re.compile(r"^\d{4}-\d{2}(-\d{2})?([T ][\d:.]+Z?)?$|^\d{1,2}/\d{1,2}(/\d{2,4})?$")
COLOR_RE = re.compile(r"^(#[0-9a-fA-F]{3,8}|rgba?\(.*\)|hsla?\(.*\))$")


def compare_json(src, tgt, path="$"):
    if type(src) is not type(tgt):
        error(f"{path} : type changé ({type(src).__name__} → {type(tgt).__name__})")
        return
    if isinstance(src, dict):
        if list(src) != list(tgt):
            lost = [k for k in src if k not in tgt]
            new = [k for k in tgt if k not in src]
            error(f"{path} : clés modifiées"
                  + (f" ; disparues : {', '.join(lost)}" if lost else "")
                  + (f" ; nouvelles (clé traduite ?) : {', '.join(new)}" if new else ""))
        for key in src:
            if key in tgt:
                sub = f"{path}.{key}"
                if normalize(key) in UNTOUCHABLE_KEYS and src[key] != tgt[key]:
                    error(f"{sub} : valeur modifiée (« {src[key]} » → « {tgt[key]} »), elle ne se traduit pas")
                else:
                    compare_json(src[key], tgt[key], sub)
    elif isinstance(src, list):
        if len(src) != len(tgt):
            error(f"{path} : {len(src)} éléments dans la source, {len(tgt)} dans la traduction")
        for i, (a, b) in enumerate(zip(src, tgt)):
            compare_json(a, b, f"{path}[{i}]")
    elif isinstance(src, str):
        if (DATE_RE.match(src.strip()) or COLOR_RE.match(src.strip())) and src != tgt:
            error(f"{path} : date ou couleur modifiée (« {src} » → « {tgt} »)")
    elif src != tgt:
        error(f"{path} : valeur modifiée ({src} → {tgt})")


def check_json(source_path, target_path):
    docs = []
    for path in (source_path, target_path):
        try:
            with open(path, encoding="utf-8") as f:
                docs.append(json.load(f))
        except json.JSONDecodeError as e:
            error(f"{path} : JSON invalide ({e})")
            return
    compare_json(*docs)


def main():
    parser = argparse.ArgumentParser(description="Vérifie une traduction de page ou de sous-page JSON.")
    parser.add_argument("source", help="fichier source (.wiki ou .json)")
    parser.add_argument("traduction", help="fichier traduit")
    parser.add_argument("--lang", help="langue de la traduction (en, de…)")
    parser.add_argument("--source-lang", default="fr", help="langue de la source (défaut : fr)")
    parser.add_argument("--json", action="store_true", help="compare deux sous-pages JSON")
    args = parser.parse_args()

    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")

    if args.json:
        check_json(args.source, args.traduction)
    else:
        with open(args.source, encoding="utf-8") as f:
            source = f.read()
        with open(args.traduction, encoding="utf-8") as f:
            target = f.read()
        check_wikitext(source, target, args.lang, args.source_lang)

    for message in errors:
        print(f"ERREUR : {message}")
    for message in warnings:
        print(f"Avertissement : {message}")
    if not errors and not warnings:
        print("Aucun écart détecté.")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
