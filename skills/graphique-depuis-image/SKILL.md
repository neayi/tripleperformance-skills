---
name: graphique-depuis-image
description: Convertit une image de graphique (histogramme, courbes, camembert, nuage de points, treemap, schéma de rotation…) en graphique natif pour Triple Performance (options ECharts ou rotation TIKA, stockées en sous-page JSON). À utiliser quand l'utilisateur fournit une capture ou une page de PDF contenant un graphique et veut un graphique interactif dans le wiki.
---

# Convertir une image de graphique en graphique natif

Applique les règles de la skill `conventions`. Cette skill couvre la lecture de l'image ; le format du JSON, le stockage en sous-page et la publication relèvent de la skill `graphiques`, à suivre à partir de l'étape 4.

## Déroulé

1. **Prépare l'image** (recadrage, agrandissement) dans `tp-travail/<sujet>/` comme pour un tableau (voir skill `tableau-depuis-image`).

2. **Analyse le graphique** :
   - type (barres groupées/empilées, lignes, aire, camembert/anneau, nuage, treemap, combiné barres + courbe à deux axes, rotation en cercle ou frise d'itinéraire technique) ;
   - titre, axes (libellés, unités, échelle, min/max), légende, séries et couleurs ;
   - **valeurs** : utilise les étiquettes de données si elles sont affichées ; sinon estime-les à partir des graduations et signale à l'utilisateur qu'il s'agit d'estimations (et propose-lui de fournir les données sources).
   - Une rotation ou un itinéraire technique (cultures successives, interventions datées) se convertit en graphique TIKA, pas en camembert.

3. **Écris les données** d'abord dans `tp-travail/<sujet>/donnees.csv` (pour une rotation : une ligne par étape puis par intervention, avec leurs dates) et montre-les à l'utilisateur pour validation : c'est l'étape où les erreurs se repèrent le plus facilement.

4. **Construis le JSON** dans `tp-travail/<sujet>/<nom>.json` à partir des gabarits de la skill `graphiques` :
   - reprends les couleurs de l'original quand elles ont du sens (ex. vert = bio) ;
   - ajoute `tooltip`, une `legend` s'il y a plusieurs séries, les unités dans `name` des axes ou dans un `formatter` ;
   - textes en langue du wiki cible.

5. **Vérifie, prévisualise et publie** selon la skill `graphiques` (`graphique.py verifie`, `graphique.py apercu`, sous-page JSON publiée avec `--content-model=json`, appel `{{Graphique Triple Performance}}` dans l'article).

6. **Source** : ajoute sous le graphique une ligne « Source : … » ou une `<ref>`.
