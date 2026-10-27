#!/usr/bin/env python3
"""Fait rendre un wikitext par l'API de Triple Performance, sans rien enregistrer,
et signale les problèmes visibles avant publication.

Contrôles : erreurs de références (Cite), erreurs de modèles et de parser functions,
liens rouges (pages inexistantes), avertissements de l'analyseur.

Exemples :
    python3 preview.py tp-travail/stir/page.wiki --title "Soil Tillage Intensity Rating (STIR)"
    python3 preview.py traduction.wiki --title "STIR" --lang en --html apercu.html

Code de sortie : 0 si aucun problème, 1 si des problèmes sont détectés, 2 en cas d'erreur.
"""

import argparse
import html
import json
import re
import sys
import urllib.parse
import urllib.request

USER_AGENT = "tripleperformance-skills/0.1 (https://github.com/neayi/tripleperformance-skills)"

ERROR_RE = re.compile(r'<(?:span|strong|div)[^>]*class="[^"]*\berror\b[^"]*"[^>]*>(.*?)</(?:span|strong|div)>', re.S)
RED_LINK_RE = re.compile(r'<a [^>]*class="[^"]*\bnew\b[^"]*"[^>]*title="([^"]+)"')


def base_url(lang):
    if lang == "fr":
        return "https://wiki.tripleperformance.fr"
    return f"https://{lang}.tripleperformance.ag"


def parse(lang, title, text):
    data = urllib.parse.urlencode({
        "action": "parse", "format": "json", "formatversion": "2",
        "prop": "text|parsewarnings|categories", "contentmodel": "wikitext",
        "disablelimitreport": "1", "title": title, "text": text,
    }).encode()
    request = urllib.request.Request(f"{base_url(lang)}/api.php", data=data, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        result = json.load(response)
    if "error" in result:
        raise RuntimeError(result["error"].get("info", result["error"]))
    return result["parse"]


def strip_tags(fragment):
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", "", fragment))).strip()


def main():
    parser = argparse.ArgumentParser(description="Prévisualise un wikitext sur Triple Performance sans l'enregistrer")
    parser.add_argument("file", help="fichier wikitext (- pour l'entrée standard)")
    parser.add_argument("--title", required=True, help="titre de la page (influence {{PAGENAME}} et les liens relatifs)")
    parser.add_argument("--lang", default="fr", help="code langue du wiki (fr, en, de…)")
    parser.add_argument("--html", help="enregistre le HTML rendu dans ce fichier")
    args = parser.parse_args()

    text = sys.stdin.read() if args.file == "-" else open(args.file, encoding="utf-8").read()
    try:
        result = parse(args.lang, args.title, text)
    except Exception as exc:
        print(f"Erreur lors du rendu : {exc}", file=sys.stderr)
        return 2

    rendered = result["text"]
    if args.html:
        with open(args.html, "w", encoding="utf-8") as out:
            out.write(rendered)

    errors = sorted({strip_tags(m) for m in ERROR_RE.findall(rendered)} - {""})
    red_links = sorted({html.unescape(t).removesuffix(" (page inexistante)").removesuffix(" (page does not exist)")
                        for t in RED_LINK_RE.findall(rendered)})
    warnings = result.get("parsewarnings", [])
    categories = [c["category"].replace("_", " ") for c in result.get("categories", [])]

    print(f"Rendu de « {args.title} » sur {base_url(args.lang)} : {len(rendered)} caractères HTML")
    if categories:
        print(f"Catégories : {', '.join(categories)}")
    for label, items in (("Erreurs", errors), ("Liens rouges", red_links), ("Avertissements", warnings)):
        if items:
            print(f"\n{label} ({len(items)}) :")
            for item in items:
                print(f"  - {item}")

    if errors or red_links or warnings:
        return 1
    print("\nAucun problème détecté.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
