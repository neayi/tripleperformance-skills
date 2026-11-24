#!/usr/bin/env python3
"""Calcule les liens interlangues attendus pour toutes les versions linguistiques d'une page.

Lecture seule : le script ne modifie aucune page. Il prépare, pour chaque page à corriger,
le wikitext actuel et le wikitext proposé, à montrer en diff avant `mediawiki write`.

Exemples :
    python3 interlangues.py "Soil Tillage Intensity Rating (STIR)"
    python3 interlangues.py https://en.tripleperformance.ag/wiki/STIR
    python3 interlangues.py "Trèfle" --ajoute en:Clover --sortie tp-travail/trefle/interlangues
    python3 interlangues.py "Trèfle" --dev

Démarche (reprise de gpt_wiki_translator/scripts/sync_interwiki.py) :
  1. part de la page donnée et suit les liens interlangues de proche en proche, sur tous les wikis ;
  2. suit les redirections et écarte les pages qui n'existent pas ;
  3. ajoute les pages passées par --ajoute (traduction tout juste publiée, ou à publier) ;
  4. pour chaque page, le bloc attendu est la liste triée des autres langues ;
  5. signale les pages dont les liens diffèrent, et les conflits (deux pages pour une langue).
"""

import argparse
import json
import re
import sys
import urllib.parse
import urllib.request
from pathlib import Path

USER_AGENT = "tripleperformance-skills/0.1 (https://github.com/neayi/tripleperformance-skills)"
# Langues des wikis Triple Performance. `gr` et `po` existent dans l'interwikimap mais
# ne sont pas des langues : [[gr:…]] ferait un lien dans le texte.
LANGS = ["ar", "de", "el", "en", "es", "fi", "fr", "hu", "it", "nl", "pl", "pt"]


def base_url(lang, dev=False):
    if dev:
        return f"https://{lang}.dev.tripleperformance.ag"
    if lang == "fr":
        return "https://wiki.tripleperformance.fr"
    return f"https://{lang}.tripleperformance.ag"


def page_url(lang, title, dev=False):
    return f"{base_url(lang, dev)}/wiki/{urllib.parse.quote(title.replace(' ', '_'), safe=':/()')}"


def api_get(lang, params, dev=False):
    params = {**params, "format": "json", "formatversion": "2"}
    url = f"{base_url(lang, dev)}/api.php?{urllib.parse.urlencode(params)}"
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    context = None
    if dev:
        import ssl
        context = ssl._create_unverified_context()  # certificats auto-signés en dev
    with urllib.request.urlopen(request, timeout=30, context=context) as response:
        data = json.load(response)
    if "error" in data:
        raise RuntimeError(data["error"].get("info", data["error"]))
    return data


def parse_target(text, lang):
    """Accepte une URL de page ou un titre ; retourne (langue, titre)."""
    if text.startswith("http"):
        u = urllib.parse.urlparse(text)
        host = u.netloc.lower()
        if host in ("wiki.tripleperformance.fr", "tripleperformance.fr"):
            lang = "fr"
        else:
            lang = host.split(".", 1)[0]
        if "/wiki/" in u.path:
            title = u.path.split("/wiki/", 1)[1]
        else:
            title = urllib.parse.parse_qs(u.query).get("title", [""])[0]
        return lang, urllib.parse.unquote(title).replace("_", " ")
    return lang, text.replace("_", " ")


def resolve(lang, title, dev):
    """Retourne (titre réel, langlinks) ou (None, {}) si la page n'existe pas."""
    data = api_get(lang, {
        "action": "query", "titles": title, "redirects": 1,
        "prop": "langlinks", "lllimit": "max",
    }, dev)
    pages = data["query"]["pages"]
    if not pages or pages[0].get("missing") or pages[0].get("invalid"):
        return None, {}
    page = pages[0]
    return page["title"], {l["lang"]: l["title"] for l in page.get("langlinks", [])}


def fetch_wikitext(lang, title, dev):
    data = api_get(lang, {
        "action": "query", "titles": title, "prop": "revisions",
        "rvprop": "content", "rvslots": "main",
    }, dev)
    page = data["query"]["pages"][0]
    return page["revisions"][0]["slots"]["main"]["content"]


MARKER_RE = re.compile(r"\[\[\s*(" + "|".join(LANGS) + r")\s*:([^\]|]*)\]\]", re.IGNORECASE)


def existing_markers(content):
    markers = {}
    for m in MARKER_RE.finditer(content):
        title = m.group(2).strip().replace("_", " ")
        markers[m.group(1).lower()] = title[:1].upper() + title[1:]  # MediaWiki capitalise la 1re lettre
    return markers


def rewrite(content, expected):
    """Retire tous les liens interlangues puis ajoute le bloc attendu en fin de page."""
    cleaned_lines = []
    for line in content.split("\n"):
        new_line = MARKER_RE.sub("", line)
        if new_line != line and not new_line.strip():
            continue  # la ligne ne contenait que des liens interlangues
        cleaned_lines.append(new_line.rstrip() if new_line != line else new_line)
    cleaned = "\n".join(cleaned_lines).rstrip()
    block = "\n".join(f"[[{lang}:{title}]]" for lang, title in sorted(expected.items()))
    return f"{cleaned}\n{block}\n" if block else f"{cleaned}\n"


def build_cluster(seed_lang, seed_title, extra, dev):
    cluster, conflicts, missing = {}, [], []
    to_visit = [(seed_lang, seed_title, "page de départ")]
    visited = set()
    while to_visit:
        lang, title, origin = to_visit.pop(0)
        if (lang, title) in visited:
            continue
        visited.add((lang, title))
        real, links = resolve(lang, title, dev)
        if real is None:
            missing.append((lang, title, origin))
            continue
        if real != title:
            print(f"Redirection : {lang}:{title} → {real}")
        if lang in cluster and cluster[lang] != real:
            conflicts.append((lang, cluster[lang], real, origin))
            continue
        cluster[lang] = real
        for other_lang, other_title in links.items():
            if other_lang in LANGS:
                to_visit.append((other_lang, other_title, f"lien depuis {lang}:{real}"))
    for lang, title in extra:
        if lang in cluster and cluster[lang] != title:
            conflicts.append((lang, cluster[lang], title, "--ajoute"))
        cluster.setdefault(lang, title)
    return cluster, conflicts, missing


def main():
    parser = argparse.ArgumentParser(description="Liens interlangues attendus pour un groupe de pages traduites.")
    parser.add_argument("page", help="titre ou URL de la page de départ")
    parser.add_argument("--lang", default="fr", help="langue du titre s'il n'est pas une URL (défaut : fr)")
    parser.add_argument("--ajoute", action="append", default=[], metavar="LANG:TITRE",
                        help="page à inclure même si elle n'est pas encore reliée (répétable)")
    parser.add_argument("--sortie", help="dossier où écrire <lang>.avant.wiki et <lang>.apres.wiki des pages à corriger")
    parser.add_argument("--dev", action="store_true", help="wikis de développement (<lang>.dev.tripleperformance.ag)")
    parser.add_argument("--json", action="store_true", help="sortie JSON")
    args = parser.parse_args()

    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")

    extra = []
    for item in args.ajoute:
        if ":" not in item:
            parser.error(f"--ajoute attend LANG:TITRE, pas {item!r}")
        lang, title = item.split(":", 1)
        extra.append((lang.strip().lower(), title.strip().replace("_", " ")))

    seed_lang, seed_title = parse_target(args.page, args.lang)
    cluster, conflicts, missing = build_cluster(seed_lang, seed_title, extra, args.dev)
    if not cluster:
        print(f"La page {seed_lang}:{seed_title} n'existe pas.")
        sys.exit(1)

    out_dir = Path(args.sortie) if args.sortie else None
    if out_dir:
        out_dir.mkdir(parents=True, exist_ok=True)

    report = {"pages": cluster, "a_corriger": {}, "a_publier": [], "conflits": conflicts, "absentes": missing}
    for lang, title in sorted(cluster.items()):
        expected = {l: t for l, t in cluster.items() if l != lang}
        real, _ = resolve(lang, title, args.dev)
        if real is None:
            report["a_publier"].append(lang)
            continue
        content = fetch_wikitext(lang, real, args.dev)
        current = existing_markers(content)
        duplicated = len(MARKER_RE.findall(content)) > len(current)
        if current == expected and not duplicated:
            continue
        details = {
            "manquants": sorted(l for l in expected if l not in current),
            "faux": sorted(l for l in expected if l in current and current[l] != expected[l]),
            "en_trop": sorted(l for l in current if l not in expected),
            "doublons": duplicated,
        }
        report["a_corriger"][lang] = details
        if out_dir:
            (out_dir / f"{lang}.avant.wiki").write_text(content, encoding="utf-8")
            (out_dir / f"{lang}.apres.wiki").write_text(rewrite(content, expected), encoding="utf-8")

    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
        sys.exit(1 if conflicts else 0)

    print("Versions linguistiques :")
    for lang, title in sorted(cluster.items()):
        state = "à publier" if lang in report["a_publier"] else (
            "à corriger" if lang in report["a_corriger"] else "à jour")
        print(f"  {lang}  {title}  [{state}]  {page_url(lang, title, args.dev)}")
    for lang, title, origin in missing:
        print(f"Lien vers une page absente, à retirer : {lang}:{title} ({origin})")
    for lang, first, second, origin in conflicts:
        print(f"CONFLIT {lang} : « {first} » et « {second} » ({origin}). "
              f"Demande à l'utilisateur laquelle garder ; « {first} » est retenue ici.")
    for lang, details in sorted(report["a_corriger"].items()):
        parts = []
        if details["manquants"]:
            parts.append("manquants : " + ", ".join(details["manquants"]))
        if details["faux"]:
            parts.append("à corriger : " + ", ".join(details["faux"]))
        if details["en_trop"]:
            parts.append("en trop : " + ", ".join(details["en_trop"]))
        if details["doublons"]:
            parts.append("liens en double")
        print(f"{lang}:{cluster[lang]} → " + " ; ".join(parts))
        if out_dir:
            print(f"  diff -u {out_dir / (lang + '.avant.wiki')} {out_dir / (lang + '.apres.wiki')}")
    for lang in report["a_publier"]:
        block = "\n".join(f"[[{l}:{t}]]" for l, t in sorted(cluster.items()) if l != lang)
        print(f"Bloc à placer en fin de la page {lang}:{cluster[lang]} avant publication :\n{block}")
    if not report["a_corriger"] and not report["a_publier"]:
        print("Tous les liens interlangues sont à jour.")
    sys.exit(1 if conflicts else 0)


if __name__ == "__main__":
    main()
