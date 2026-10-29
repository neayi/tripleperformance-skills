# Graphiques ECharts sur Triple Performance

Extension : [mw-echarts](https://github.com/neayi/mw-echarts) (ECharts 6.1 embarqué). Documentation des options : <https://echarts.apache.org/en/option.html> ; exemples éditables : <https://echarts.apache.org/examples/en/index.html>. Page d'aide du wiki : [Aide:Insérer des graphiques dans une page](https://wiki.tripleperformance.fr/wiki/Aide:Ins%C3%A9rer_des_graphiques_dans_une_page).

Une sous-page JSON est reconnue comme options ECharts dès qu'elle contient une clé `series` à la racine. Elle doit être du JSON strict (pas de fonction).

## Formateurs nommés

L'extension remplace certaines chaînes de `tooltip.formatter` par une fonction :

| Valeur | Effet |
|---|---|
| `"assolement"` | Infobulle d'un treemap : `Colza : 32ha (19%)`, pourcentage calculé sur le total. |
| `"rotation"` | Infobulle : nom en gras puis `data.description` de l'élément (texte HTML autorisé). Pour les anciens anneaux de rotation ; préfère TIKA pour une nouvelle rotation. |

Ailleurs, utilise les gabarits de chaînes d'ECharts : `{a}` série, `{b}` catégorie ou nom, `{c}` valeur, `{d}` pourcentage (camembert), `{value}` dans `axisLabel.formatter`.

## Gabarits

Ces gabarits reprennent les graphiques de la page d'aide (sous-pages `Aide:Insérer des graphiques dans une page/*.json`), que l'add-on Google Sheets produit aussi : suivre leur structure garde une apparence homogène.

### Assolement (treemap) — `type = Assolement`

Un groupe par grande catégorie (couleur sur le groupe), une feuille par culture, surfaces en ha.

```json
{
  "tooltip": { "formatter": "assolement", "confine": true },
  "series": [{
    "type": "treemap", "roam": false, "name": "Assolement 2024",
    "itemStyle": { "borderWidth": 0, "gapWidth": 2 },
    "data": [
      { "name": "Cultures de vente", "itemStyle": { "color": "#ffe599" }, "children": [
        { "name": "Blé tendre", "value": 76, "label": { "formatter": "{b} - {c}ha", "color": "#000000" } },
        { "name": "Colza", "value": 32, "label": { "formatter": "{b} - {c}ha", "color": "#000000" } }
      ] },
      { "name": "Surface fourragère", "itemStyle": { "color": "#afd095" }, "children": [
        { "name": "Prairie permanente", "value": 25, "label": { "formatter": "{b} - {c}ha", "color": "#000000" } }
      ] },
      { "name": "SIE", "itemStyle": { "color": "#ead1dc" }, "children": [
        { "name": "Haies", "value": 5, "label": { "formatter": "{b} - {c}ha", "color": "#000000" } }
      ] }
    ]
  }]
}
```

Couleurs de catégories de l'aide : cultures de vente `#ffe599`, surface fourragère `#afd095`, jachère `#efefef`, SIE `#ead1dc` (ou `#b6d7a8`).

### Barres par année — `type = Bar chart par année`

Barres empilées (même `stack`) ; retire `stack` pour des barres côte à côte.

```json
{
  "tooltip": {},
  "title": { "left": "center", "text": "Marge brute par culture" },
  "legend": { "bottom": 10, "type": "scroll" },
  "xAxis": { "type": "category", "axisLabel": { "fontWeight": "bold" }, "data": ["2022", "2023", "2024"] },
  "yAxis": { "type": "value", "axisLabel": { "formatter": "{value} €/ha" } },
  "series": [
    { "type": "bar", "name": "Blé", "stack": "total", "barMaxWidth": "150px",
      "label": { "show": true, "position": "inside", "formatter": "{c} €" },
      "emphasis": { "focus": "series" }, "itemStyle": { "color": "#fdcf74" },
      "data": [450, 520, 480] },
    { "type": "bar", "name": "Méteil", "stack": "total", "barMaxWidth": "150px",
      "label": { "show": true, "position": "inside", "formatter": "{c} €" },
      "emphasis": { "focus": "series" }, "itemStyle": { "color": "#afd095" },
      "data": [300, 280, 310] }
  ]
}
```

Les années en chaînes (`"2022"`) évitent qu'ECharts les traite comme des nombres. Pour comparer des modalités d'essai, remplace les années par les modalités.

### Radar — `type = Radar`

Souvent `width=500px | align=right`. Chaque axe a son propre `max`. Une série « Moyenne » ou « Groupe » permet la comparaison.

```json
{
  "legend": {},
  "tooltip": {},
  "radar": {
    "radius": "60%", "center": ["50%", "60%"],
    "indicator": [
      { "name": "Autonomie fourragère", "max": 100 },
      { "name": "EBE / produit", "max": 50 },
      { "name": "Temps de travail", "max": 10 }
    ]
  },
  "series": [{
    "type": "radar",
    "data": [
      { "name": "La ferme", "value": [85, 38, 7],
        "itemStyle": { "color": "#f1894c" }, "lineStyle": { "width": 3, "color": "#f1894c" },
        "areaStyle": { "color": "#f1894c", "opacity": 0.3 } },
      { "name": "Moyenne du groupe", "value": [60, 30, 6], "lineStyle": { "width": 3 } }
    ]
  }]
}
```

### Diagramme ombrothermique — `type = Ombrothermique`

Précipitations en barres (axe de droite), température en courbe (axe de gauche). La bande grise min–max est facultative : série `Min` invisible puis série `Max` = (max − min), empilées.

```json
{
  "tooltip": { "trigger": "axis", "axisPointer": { "type": "cross" } },
  "grid": { "left": 0, "right": 5, "bottom": 0, "containLabel": true },
  "legend": { "data": ["Température", "Précipitation"] },
  "xAxis": [{ "type": "category", "data": ["J","F","M","A","M","J","J","A","S","O","N","D"], "axisPointer": { "type": "shadow" } }],
  "yAxis": [
    { "type": "value", "name": "Précipitation", "position": "right", "min": 0, "max": 200, "alignTicks": true, "axisLabel": { "formatter": "{value} mm" } },
    { "type": "value", "name": "Température", "position": "left", "min": 0, "max": 40, "alignTicks": true, "axisLabel": { "formatter": "{value} °C" } }
  ],
  "series": [
    { "name": "Température", "type": "line", "yAxisIndex": 1, "lineStyle": { "width": 3 }, "itemStyle": { "color": "rgba(210, 55, 55, 1)" },
      "data": [4.5, 4.7, 7.5, 10.5, 14.6, 19, 21.5, 21.4, 17.6, 13.9, 8.9, 5.5] },
    { "name": "Précipitation", "type": "bar", "barWidth": "100%", "barGap": 0, "yAxisIndex": 0,
      "itemStyle": { "color": "rgba(55, 108, 181, 1)", "borderColor": "#FFF" },
      "data": [73, 67, 70, 96, 82, 63, 39, 44, 91, 128, 143, 86] }
  ]
}
```

Convention de Gaussen : l'échelle des précipitations vaut le double de celle des températures (200 mm ↔ 40 °C par défaut) ; garde ce rapport si tu changes les maxima.

### Camembert / anneau

```json
{
  "tooltip": { "trigger": "item", "formatter": "{b} : {c} ha ({d} %)" },
  "legend": { "orient": "vertical", "left": "left", "top": "center" },
  "series": [{
    "type": "pie", "radius": ["40%", "70%"], "center": ["65%", "50%"],
    "data": [ { "name": "Vente directe", "value": 45 }, { "name": "Coopérative", "value": 55 } ]
  }]
}
```

### Courbes, deux axes, nuage de points

Partir des [exemples d'ECharts](https://echarts.apache.org/examples/en/index.html), en n'y gardant que l'objet `option` traduit en JSON strict. Ajoute toujours `tooltip`, une `legend` s'il y a plusieurs séries, et les unités dans `name` des axes ou dans `axisLabel.formatter`.

## Graphiques en ligne

Sur des pages anciennes, les options sont écrites dans la page :

```
{{#echarts:
  title=Bilan environnemental
| width=500px
| height=400px
| align=right
| option = {"legend":{},"radar":{ ... } }
}}
```

- Les paramètres `width`, `height`, `align`, `title`, `json` sont reconnus par leur nom ; tout le reste est recollé avec `|` et évalué en JavaScript (`eval`). Des fonctions sont donc possibles ici, mais pas dans une sous-page.
- `|` dans un texte coupe le paramètre : utiliser `{{!}}`.
- `}}` ferme l'appel : séparer les accolades fermantes (`} }`).
- Pour du HTML dans les infobulles, les pages existantes encodent `&`, `<`, `>`, `"` en `¤amp;`, `¤lt;`, `¤gt;`, `¤quot;` et les décodent dans un `formatter`.
- Des valeurs texte peuvent contenir des liens wiki (`"name":"[[Blé]] d'hiver"`) : n'en ajoute que si l'utilisateur le demande (les liens internes sont posés par LinkTitles, voir `conventions`).

Pour migrer un tel graphique vers une sous-page : extraire l'objet, le convertir en JSON strict (guillemets doubles, pas de fonction ni de virgule finale), vérifier avec `graphique.py verifie`, publier la sous-page, puis remplacer l'appel par le modèle `Graphique Triple Performance` avec le `type` adéquat.

## Graphiques à paramètres

Ces graphiques ne passent pas par une sous-page JSON ; les données sont des paramètres de l'appel.

- **Bilan économique** sur plusieurs années, avec détail en treemap au clic :

  ```
  {{#economic_charts:
   title=Bilan économique
   | Semences et plants 2023 = 23360
   | Fertilisation 2023 = 24160
   | Vente de produits végétaux 2023 = 450000
   | EBE total 2023 = 190760
  }}
  ```

  Chaque paramètre est `<poste> <année> = <montant>` ; seuls les postes connus de l'extension sont acceptés (la liste s'affiche en cas d'erreur, voir aussi la page d'aide) ; un poste hors liste peut être rattaché à une catégorie connue sous la forme `<Catégorie>/<Poste> <année> = <montant>`. Produits et charges doivent s'équilibrer à 10 % près (EBE compris), sinon le graphique affiche une erreur. Vérifie avec `preview.py` de `conventions`.

- **Camembert simple** : `{{#pie_chart: title=Débouchés | align=right | Vente directe = 45 | Coopérative = 55 }}` (450 × 300 px, à droite par défaut ; `formatter` facultatif).

- **Modèles dédiés** : `{{EChart Radar MSV}}`, `{{EChart Capacité d'autoproduction MSV}}`, `{{EChart Stratégie commerciale MSV}}` (portraits MSV), `{{Fleur de l'Agroécologie|Viabilité économique=3|...|align=right|width=300px}}`. Lis leur TemplateData (API `action=templatedata`, voir skill `nouvel-article`) pour la liste des paramètres.
