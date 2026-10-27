---
name: graphique-depuis-image
description: Convertit une image de graphique (histogramme, courbes, camembert, nuage de points, treemap…) en graphique natif ECharts pour Triple Performance, avec la syntaxe {{#echarts:}} du wiki. À utiliser quand l'utilisateur fournit une capture ou une page de PDF contenant un graphique et veut un graphique interactif dans le wiki, ou veut créer un graphique ECharts à partir de données.
---

# Convertir une image de graphique en ECharts

Applique les règles de la skill `conventions`. La syntaxe de l'extension et des exemples sont dans [references/echarts.md](references/echarts.md).

## Déroulé

1. **Prépare l'image** (recadrage, agrandissement) dans `tp-travail/<sujet>/` comme pour un tableau (voir skill `tableau-depuis-image`).

2. **Analyse le graphique** :
   - type (barres groupées/empilées, lignes, aire, camembert/anneau, nuage, treemap, combiné barres + courbe à deux axes) ;
   - titre, axes (libellés, unités, échelle, min/max), légende, séries et couleurs ;
   - **valeurs** : utilise les étiquettes de données si elles sont affichées ; sinon estime-les à partir des graduations et signale à l'utilisateur qu'il s'agit d'estimations (et propose-lui de fournir les données sources).

3. **Écris les données** d'abord dans `tp-travail/<sujet>/donnees.csv` et montre-les à l'utilisateur pour validation : c'est l'étape où les erreurs se repèrent le plus facilement.

4. **Construis l'option ECharts** en JSON dans `tp-travail/<sujet>/option.json` et vérifie qu'il est valide :

   ```bash
   jq . tp-travail/<sujet>/option.json > /dev/null && echo "JSON valide"
   ```

   - reprends les couleurs de l'original quand elles ont du sens (ex. vert = bio) ;
   - ajoute `tooltip`, une `legend` s'il y a plusieurs séries, les unités dans `name` des axes ou dans un `formatter` ;
   - textes en langue du wiki cible.

5. **Assemble l'appel** dans `tp-travail/<sujet>/graphique.wiki` :

   ```
   {{#echarts:
     title=Rendement du blé selon le précédent
   | width=100%
   | height=400px
   | option = <contenu de option.json sur une ligne>
   }}
   ```

   Compacte le JSON avec `jq -c . option.json`. Attention : dans un appel de parser function, `|` et `}}` dans le JSON casseraient la syntaxe (voir la référence pour les contournements).

6. **Source** : ajoute sous le graphique une ligne « Source : … » ou une `<ref>`.

7. **Prévisualisation** (optionnel) : génère `tp-travail/<sujet>/apercu.html` avec ECharts depuis un CDN et la même option, pour que l'utilisateur vérifie le rendu dans son navigateur avant publication.

8. Insère dans la page cible selon les règles de publication de `conventions`.
