#!/usr/bin/env python3
"""Outils pour les graphiques de Triple Performance stockés en sous-pages JSON.

Sous-commandes :
    verifie FICHIER.json        valide le JSON et détecte son format (options ECharts ou rotation TIKA)
    apercu FICHIER.json -o X    produit une page HTML autonome qui rend le graphique comme sur le wiki
    liste TITRE [--lang en]     liste les graphiques d'une page du wiki et l'état de leurs sous-pages JSON

Exemples :
    python3 graphique.py verifie tp-travail/longueil/rotation.json
    python3 graphique.py apercu tp-travail/longueil/rotation.json -o tp-travail/longueil/apercu.html
    python3 graphique.py liste "Ferme de Longueil"

Code de sortie : 0 si tout va bien, 1 si des erreurs sont détectées, 2 en cas d'erreur d'usage ou réseau.
"""

import argparse
import html
import json
import re
import sys
import urllib.parse
import urllib.request
from datetime import datetime, timezone

USER_AGENT = "tripleperformance-skills/0.1 (https://github.com/neayi/tripleperformance-skills)"

# ECharts dans la version embarquée par l'extension du wiki ; TIKA dans la version publiée sur npm.
ECHARTS_JS = "https://cdn.jsdelivr.net/npm/echarts@6.1.0/dist/echarts.min.js"
TIKA_BASE = "https://cdn.jsdelivr.net/npm/@osfarm/itineraire-technique@1.2.15"
JQUERY_JS = "https://cdn.jsdelivr.net/npm/jquery@3.7.1/dist/jquery.min.js"
UNDERSCORE_JS = "https://cdn.jsdelivr.net/npm/underscore@1.13.7/underscore-umd-min.js"
BOOTSTRAP_CSS = "https://cdn.jsdelivr.net/npm/bootstrap@5.2.3/dist/css/bootstrap.min.css"

TEMPLATE_RE = re.compile(r"\{\{\s*Graphique Triple Performance\s*\|(.*?)\}\}", re.S | re.I)
ECHARTS_RE = re.compile(r"\{\{\s*#echarts:(.*?)\n?\}\}", re.S | re.I)
HEX_COLOR_RE = re.compile(r"^#[0-9a-fA-F]{6}$")
VIEWS = ("horizontal", "donut", "vertical")  # "vertical" (anciens fichiers) s'affiche en donut
INTERVENTION_TYPES = ("intervention_top", "intervention_bottom")
MAX_YEARS = 20


def base_url(lang):
    if lang == "fr":
        return "https://wiki.tripleperformance.fr"
    return f"https://{lang}.tripleperformance.ag"


def load_json(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def detect_format(data):
    """Même règle que mw.echarts.js : sans clé `series` à la racine, c'est une rotation TIKA."""
    if isinstance(data, dict) and "series" in data:
        return "echarts"
    return "tika"


def parse_date(value):
    if not isinstance(value, str) or not value:
        return None
    try:
        d = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    return d if d.tzinfo else d.replace(tzinfo=timezone.utc)


def check_echarts(data):
    errors, warnings = [], []
    series = data.get("series")
    if not isinstance(series, list) or not series:
        errors.append("`series` doit être une liste non vide")
        series = []
    for i, s in enumerate(series):
        if not isinstance(s, dict) or not s.get("type"):
            errors.append(f"series[{i}] : `type` manquant")
    if len(series) > 1 and "legend" not in data:
        warnings.append("plusieurs séries sans `legend`")
    if "tooltip" not in data:
        warnings.append("pas de `tooltip` : aucune valeur ne s'affiche au survol")
    text = json.dumps(data, ensure_ascii=False)
    if re.search(r"function\s*\(|=>", text):
        warnings.append("du code JavaScript semble présent dans une chaîne : il ne sera pas exécuté dans une page JSON")
    return errors, warnings


def check_tika(data):
    errors, warnings = [], []
    if not isinstance(data, dict):
        return ["une rotation TIKA doit être un objet JSON"], []
    if not data.get("title"):
        warnings.append("`title` vide : le titre ne s'affichera pas au-dessus de la frise")
    options = data.get("options") or {}
    view = options.get("view", "horizontal")
    if view not in VIEWS:
        warnings.append(f"options.view = {view!r} : valeurs attendues 'horizontal' ou 'donut' (toute autre valeur donne le donut)")
    climate = options.get("climate_data")
    if options.get("show_climate_diagram") and not climate:
        warnings.append("show_climate_diagram sans climate_data : le diagramme ne s'affichera pas")
    if climate:
        for key in ("temperatures", "precipitations"):
            values = climate.get(key)
            if not isinstance(values, list) or len(values) != 12:
                errors.append(f"options.climate_data.{key} doit contenir 12 valeurs mensuelles")
    if any(k in options for k in ("address", "region", "latitude", "longitude")):
        warnings.append("options.address/region/latitude/longitude : ancien format, "
                        "l'adresse va désormais dans `address` à la racine (sans effet sur le rendu)")

    steps = data.get("steps")
    if not isinstance(steps, list) or not steps:
        return errors + ["`steps` doit être une liste non vide d'étapes"], warnings

    with_attributes = []
    previous_end = None
    first_start = last_end = None
    for i, step in enumerate(steps):
        label = f"steps[{i}] ({step.get('name', '?')})"
        if not step.get("name"):
            errors.append(f"steps[{i}] : `name` manquant")
        start, end = parse_date(step.get("startDate")), parse_date(step.get("endDate"))
        if start is None:
            errors.append(f"{label} : startDate absente ou illisible (format AAAA-MM-JJ ou ISO 8601)")
        if end is None:
            errors.append(f"{label} : endDate absente ou illisible")
        if start and end:
            if end <= start:
                errors.append(f"{label} : endDate doit être postérieure à startDate")
            first_start = start if first_start is None else min(first_start, start)
            last_end = end if last_end is None else max(last_end, end)
            if not step.get("secondary_crop") and previous_end:
                gap = (start - previous_end).days
                if gap < 0:
                    warnings.append(f"{label} : commence {-gap} j avant la fin de l'étape principale précédente "
                                    "(chevauchement ; utiliser secondary_crop pour une culture associée ou un couvert)")
            if not step.get("secondary_crop"):
                previous_end = end
        color = step.get("color")
        if color and not HEX_COLOR_RE.match(color):
            warnings.append(f"{label} : couleur {color!r} au format inattendu (#rrggbb)")
        if not color:
            warnings.append(f"{label} : pas de `color`")
        if step.get("attributes"):
            with_attributes.append(step.get("name", str(i)))
        for j, inter in enumerate(step.get("interventions") or []):
            ilabel = f"{label} intervention {j} ({inter.get('name', '?')})"
            if not inter.get("name"):
                errors.append(f"{ilabel} : `name` manquant")
            try:
                day = int(str(inter.get("day")).strip())
            except ValueError:
                errors.append(f"{ilabel} : `day` doit être un nombre de jours depuis startDate")
                day = None
            if inter.get("type") not in INTERVENTION_TYPES:
                warnings.append(f"{ilabel} : type {inter.get('type')!r} affiché en bas (attendu {INTERVENTION_TYPES})")
            if day is not None and start and end and not (-365 <= day <= (end - start).days + 365):
                warnings.append(f"{ilabel} : jour {day} loin de la période de l'étape ({(end - start).days} j)")
    if with_attributes:
        warnings.append("`attributes` (obsolète, ajouté par le rendu à la fin de la description) dans : "
                        + ", ".join(with_attributes) + " ; pour un nouveau fichier, écrire ces lignes dans `description`")
    if first_start and last_end and (last_end - first_start).days > MAX_YEARS * 365:
        errors.append(f"la rotation dépasse {MAX_YEARS} ans : le rendu refuse de l'afficher")
    return errors, warnings


def cmd_verifie(args):
    try:
        data = load_json(args.fichier)
    except json.JSONDecodeError as exc:
        print(f"ERREUR  JSON invalide : {exc}")
        return 1
    fmt = detect_format(data)
    errors, warnings = check_echarts(data) if fmt == "echarts" else check_tika(data)
    print(f"Format : {'options ECharts' if fmt == 'echarts' else 'rotation / itinéraire technique TIKA'}")
    if fmt == "tika":
        steps = data.get("steps") or []
        n_inter = sum(len(s.get("interventions") or []) for s in steps if isinstance(s, dict))
        print(f"Étapes : {len(steps)}, interventions : {n_inter}, vue : {(data.get('options') or {}).get('view', 'horizontal')}")
    for e in errors:
        print(f"ERREUR  {e}")
    for w in warnings:
        print(f"ATTENTION  {w}")
    if not errors and not warnings:
        print("Aucun problème détecté.")
    return 1 if errors else 0


def cmd_apercu(args):
    data = load_json(args.fichier)
    fmt = detect_format(data)
    payload = json.dumps(data, ensure_ascii=False).replace("</", "<\\/")
    default_title = data.get("title") if isinstance(data.get("title"), str) else "Aperçu"
    title = html.escape(args.titre or default_title)
    if fmt == "echarts":
        head = f'<script src="{ECHARTS_JS}"></script>'
        # Mêmes formateurs nommés que mw.echarts.js sur le wiki.
        body = f"""<div id="chart" style="width:{args.width};height:{args.height};margin:auto"></div>
<script>
const option = {payload};
const f = option.tooltip && option.tooltip.formatter;
if (f === 'rotation') {{
  option.tooltip.extraCssText = 'text-wrap: wrap;';
  option.tooltip.formatter = (item) => item.marker + '<b>' + item.name + '</b><br>' + item.data.description;
}} else if (f === 'assolement') {{
  option.tooltip.formatter = (info) => info.name + ' : ' + info.value + 'ha ('
    + Math.round(100 * info.value / info.treeAncestors[0].value) + '%)';
}}
const chart = echarts.init(document.getElementById('chart'));
chart.setOption(option);
window.addEventListener('resize', () => chart.resize());
</script>"""
    else:
        head = (f'<link href="{BOOTSTRAP_CSS}" rel="stylesheet">\n'
                f'<script src="{ECHARTS_JS}"></script>\n<script src="{JQUERY_JS}"></script>\n'
                f'<script src="{UNDERSCORE_JS}"></script>\n'
                f'<link href="{TIKA_BASE}/css/styles-rendering.css" rel="stylesheet">\n'
                f'<script src="{TIKA_BASE}/js/chart-render.js"></script>')
        body = f"""<div id="itk"></div>
<script>
new RotationRenderer('itk', {payload}).render();
</script>"""
    page = f"""<!DOCTYPE html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
{head}
<style>body{{font-family:sans-serif;margin:16px;background:#fff}}</style>
</head><body>
<h2>{title}</h2>
{body}
</body></html>
"""
    with open(args.output, "w", encoding="utf-8") as f:
        f.write(page)
    print(f"Aperçu écrit dans {args.output} (ouvrir dans un navigateur ; nécessite une connexion pour les CDN).")
    return 0


def api_get(lang, params):
    url = base_url(lang) + "/api.php?" + urllib.parse.urlencode({**params, "format": "json", "formatversion": "2"})
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp)


def template_params(body):
    params = {}
    for part in body.split("|"):
        if "=" in part:
            key, value = part.split("=", 1)
            params[key.strip().lower()] = value.strip()
    return params


def cmd_liste(args):
    try:
        res = api_get(args.lang, {"action": "query", "prop": "revisions", "rvprop": "content",
                                  "rvslots": "main", "titles": args.titre, "redirects": "1"})
    except OSError as exc:
        print(f"Erreur réseau : {exc}", file=sys.stderr)
        return 2
    page = res["query"]["pages"][0]
    if page.get("missing"):
        print(f"La page {args.titre!r} n'existe pas.", file=sys.stderr)
        return 2
    text = page["revisions"][0]["slots"]["main"]["content"]
    charts = []
    for m in TEMPLATE_RE.finditer(text):
        p = template_params(m.group(1))
        charts.append({"appel": "modèle", "titre": p.get("title", ""), "type": p.get("type", ""),
                       "json": p.get("json", "")})
    for m in ECHARTS_RE.finditer(text):
        p = template_params(m.group(1))
        charts.append({"appel": "#echarts", "titre": p.get("title", ""), "type": "",
                       "json": p.get("json", "")})
    if not charts:
        print(f"Aucun graphique dans « {page['title']} ».")
        return 0

    json_titles = sorted({c["json"] for c in charts if c["json"]})
    info = {}
    if json_titles:
        res = api_get(args.lang, {"action": "query", "prop": "info", "titles": "|".join(json_titles)})
        normalized = {n["from"]: n["to"] for n in res["query"].get("normalized", [])}
        by_title = {p["title"]: p for p in res["query"]["pages"]}
        for t in json_titles:
            p = by_title.get(normalized.get(t, t), {})
            info[t] = "absente" if p.get("missing") else p.get("contentmodel", "?")

    print(f"Graphiques de « {page['title']} » :")
    for c in charts:
        if c["json"]:
            state = info.get(c["json"], "?")
            where = f"{c['json']} [{state}]"
            if state not in ("json", "absente"):
                where += "  <- modèle de contenu inattendu, attendu json"
        else:
            where = "options en ligne dans la page"
        typ = f" ({c['type']})" if c["type"] else ""
        print(f"- {c['appel']}{typ} « {c['titre']} » : {where}")
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("verifie", help="valider un fichier JSON de graphique")
    p.add_argument("fichier")
    p = sub.add_parser("apercu", help="générer un aperçu HTML")
    p.add_argument("fichier")
    p.add_argument("-o", "--output", required=True)
    p.add_argument("--titre")
    p.add_argument("--width", default="100%")
    p.add_argument("--height", default="400px")
    p = sub.add_parser("liste", help="lister les graphiques d'une page du wiki")
    p.add_argument("titre")
    p.add_argument("--lang", default="fr")
    args = parser.parse_args()
    try:
        return {"verifie": cmd_verifie, "apercu": cmd_apercu, "liste": cmd_liste}[args.cmd](args)
    except FileNotFoundError as exc:
        print(f"Fichier introuvable : {exc.filename}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
