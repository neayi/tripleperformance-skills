# ECharts sur Triple Performance

Extension : [mw-echarts](https://github.com/neayi/mw-echarts) ([page MediaWiki](https://www.mediawiki.org/wiki/Extension:ECharts)). Documentation des options : <https://echarts.apache.org/en/option.html>.

## Syntaxe

```
{{#echarts:
  title=Titre du graphique
| width=100%
| height=400px
| option = { ...options ECharts... }
}}
```

- `width` : en `%` ou `px` ; `height` : en `px`.
- `option` : objet d'options ECharts. Du JSON strict est recommandé ; des pages existantes utilisent aussi des fonctions JavaScript (ex. `formatter`), à n'employer que si nécessaire.
- Les valeurs texte acceptent des liens wiki : `"name":"[[Blé]] d'hiver"` (rendu en lien dans les étiquettes), comme sur la page *Ferme des Pâtures*. N'en ajoute que si l'utilisateur le demande : les liens internes sont normalement posés par LinkTitles (voir `conventions`).

## Caractères à éviter dans le JSON

Le contenu est passé comme paramètre de parser function :

- `|` coupe le paramètre : évite-le dans les textes (ou utilise `{{!}}`).
- `}}` ferme l'appel : sépare les accolades fermantes consécutives par un espace (`} }` au lieu de `}}`), comme le font les pages existantes.
- Pour du HTML dans les infobulles, les pages existantes encodent `&`, `<`, `>`, `"` en `¤amp;`, `¤lt;`, `¤gt;`, `¤quot;` et les décodent dans un `formatter`.

## Exemples

### Barres groupées

```
{{#echarts:
  title=Rendement selon le précédent
| width=100%
| height=400px
| option = {"tooltip":{"trigger":"axis"},"legend":{},"xAxis":{"type":"category","data":["2022","2023","2024"]},"yAxis":{"type":"value","name":"q/ha"},"series":[{"name":"Après féverole","type":"bar","data":[78,74,81]},{"name":"Après blé","type":"bar","data":[70,66,72]}]}
}}
```

### Camembert / anneau

```
{{#echarts:
  title=Assolement 2024
| width=100%
| height=400px
| option = {"tooltip":{"formatter":"{b} : {c} ha ({d} %)"},"series":[{"type":"pie","radius":["40%","70%"],"data":[{"name":"Prairies","value":28},{"name":"Blé","value":16},{"name":"Luzerne","value":22} ]}]}
}}
```

### Treemap (assolement)

Voir la section « Assolement » de [Ferme des Pâtures](https://wiki.tripleperformance.fr/wiki/Ferme_des_P%C3%A2tures) : `"type":"treemap"` avec un niveau `children` par culture, `label.formatter` `"{b} - {c}ha"`.

### Rotation (anneaux concentriques)

Même page, section « Rotation type » : trois séries `pie` concentriques (cultures, mois, années).

## À enrichir

Ajoute ici les gabarits validés (courbes avec deux axes, barres empilées, nuage de points…) et les palettes de couleurs habituelles du wiki.
