#!/usr/bin/env python3
"""Recherche des pages sur Triple Performance via l'API MediaWiki.

Exemples :
    python3 search.py "couverts végétaux"
    python3 search.py "cover crops" --lang en --limit 20
    python3 search.py "luzerne" --titles            # titres commençant par « luzerne »
    python3 search.py --category "Pratiques"        # pages d'une catégorie
    python3 search.py --template "Pratique"         # pages utilisant un modèle
    python3 search.py "semis direct" --json
    python3 search.py --exists "Charrue" "Houe rotative" "Fraise rotative"
    python3 search.py --langlinks "Soil Tillage Intensity Rating (STIR)"
"""

import argparse
import html
import json
import re
import sys
import urllib.parse
import urllib.request

USER_AGENT = "tripleperformance-skills/0.1 (https://github.com/neayi/tripleperformance-skills)"
NAMESPACE_PREFIXES = {
    "fr": {"category": "Catégorie", "template": "Modèle"},
    "default": {"category": "Category", "template": "Template"},
}


def base_url(lang):
    if lang == "fr":
        return "https://wiki.tripleperformance.fr"
    return f"https://{lang}.tripleperformance.ag"


def api_get(lang, params):
    params = {**params, "format": "json", "formatversion": "2"}
    url = f"{base_url(lang)}/api.php?{urllib.parse.urlencode(params)}"
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=30) as response:
        data = json.load(response)
    if "error" in data:
        raise RuntimeError(data["error"].get("info", data["error"]))
    return data


def page_url(lang, title):
    return f"{base_url(lang)}/wiki/{urllib.parse.quote(title.replace(' ', '_'), safe=":/'")}"


def clean_snippet(snippet):
    text = re.sub(r"<[^>]+>", "", snippet or "")
    return re.sub(r"\s+", " ", html.unescape(text)).strip()


def prefix(lang, kind, name):
    labels = NAMESPACE_PREFIXES.get(lang, NAMESPACE_PREFIXES["default"])
    if ":" in name:
        return name
    return f"{labels[kind]}:{name}"


def check_titles(args):
    """Vérifie l'existence de plusieurs titres (redirections suivies), par lots de 50."""
    results = []
    for start in range(0, len(args.query), 50):
        batch = args.query[start:start + 50]
        params = {"action": "query", "titles": "|".join(batch), "redirects": 1}
        if args.langlinks:
            params.update({"prop": "langlinks", "lllimit": "max"})
        query = api_get(args.lang, params)["query"]
        normalized = {n["from"]: n["to"] for n in query.get("normalized", [])}
        redirects = {r["from"]: r["to"] for r in query.get("redirects", [])}
        pages = {p["title"]: p for p in query["pages"]}
        for title in batch:
            name = normalized.get(title, title)
            target = redirects.get(name)
            page = pages.get(target or name, {})
            result = {"title": name, "exists": bool(page) and not page.get("missing")}
            if target:
                result["redirect"] = target
            if args.langlinks:
                result["langlinks"] = {l["lang"]: l["title"] for l in page.get("langlinks", [])}
            results.append(result)
    return results


def search(args):
    if args.category:
        data = api_get(args.lang, {
            "action": "query", "list": "categorymembers",
            "cmtitle": prefix(args.lang, "category", args.category), "cmlimit": args.limit,
        })
        return [{"title": p["title"]} for p in data["query"]["categorymembers"]], None

    if args.template:
        data = api_get(args.lang, {
            "action": "query", "list": "embeddedin",
            "eititle": prefix(args.lang, "template", args.template), "eilimit": args.limit,
            "einamespace": 0,
        })
        return [{"title": p["title"]} for p in data["query"]["embeddedin"]], None

    if args.titles:
        data = api_get(args.lang, {
            "action": "query", "list": "prefixsearch",
            "pssearch": " ".join(args.query), "pslimit": args.limit,
        })
        return [{"title": p["title"]} for p in data["query"]["prefixsearch"]], None

    if args.exists or args.langlinks:
        return check_titles(args), None

    data = api_get(args.lang, {
        "action": "query", "list": "search", "srsearch": " ".join(args.query),
        "srlimit": args.limit, "srnamespace": args.namespace, "srprop": "snippet|wordcount|timestamp",
    })
    results = [
        {
            "title": p["title"],
            "snippet": clean_snippet(p.get("snippet")),
            "wordcount": p.get("wordcount"),
            "timestamp": p.get("timestamp"),
        }
        for p in data["query"]["search"]
    ]
    return results, data["query"].get("searchinfo", {}).get("totalhits")


def main():
    parser = argparse.ArgumentParser(description="Recherche sur Triple Performance")
    parser.add_argument("query", nargs="*", help="texte recherché, ou titres avec --exists / --langlinks")
    parser.add_argument("--lang", default="fr", help="code langue du wiki (fr, en, de…)")
    parser.add_argument("--limit", type=int, default=10, help="nombre de résultats (max 500)")
    parser.add_argument("--namespace", default="0", help="espace(s) de noms, ex. 0 ou 0|14 (défaut : articles)")
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--titles", action="store_true", help="recherche par début de titre")
    group.add_argument("--category", help="liste les pages d'une catégorie")
    group.add_argument("--template", help="liste les articles qui utilisent un modèle")
    group.add_argument("--exists", action="store_true", help="vérifie l'existence de chaque titre donné")
    group.add_argument("--langlinks", action="store_true", help="liste les liens interlangues de chaque titre donné")
    parser.add_argument("--json", action="store_true", help="sortie JSON")
    args = parser.parse_args()

    if not (args.query or args.category or args.template):
        parser.error("indiquez un texte à rechercher, --category ou --template")

    try:
        results, total = search(args)
    except Exception as exc:  # erreur réseau ou API : message lisible pour Claude
        print(f"Erreur lors de la recherche : {exc}", file=sys.stderr)
        return 1

    for result in results:
        result["url"] = page_url(args.lang, result["title"])

    if args.json:
        json.dump({"total": total, "results": results}, sys.stdout, ensure_ascii=False, indent=2)
        print()
        return 0

    if total is not None:
        print(f"{total} résultat(s) au total, {len(results)} affiché(s)\n")
    for result in results:
        if "exists" in result:
            status = "OK" if result["exists"] else "--"
            redirect = f" → {result['redirect']} (redirection)" if "redirect" in result else ""
            print(f"{status}  {result['title']}{redirect}")
            for lang, title in result.get("langlinks", {}).items():
                print(f"      [[{lang}:{title}]]")
            continue
        print(f"- {result['title']}\n  {result['url']}")
        if result.get("snippet"):
            print(f"  {result['snippet'][:240]}")
    if not results:
        print("Aucun résultat.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
