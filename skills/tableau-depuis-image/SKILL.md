---
name: tableau-depuis-image
description: Convertit une image de tableau (capture d'écran, photo, page de PDF) en tableau wikitext natif pour Triple Performance, en reproduisant fidèlement en-têtes, cellules fusionnées et unités. À utiliser quand l'utilisateur fournit une image contenant un tableau et veut un vrai tableau éditable dans le wiki.
---

# Convertir une image de tableau en tableau wiki

Applique les règles de la skill `conventions`.

## Déroulé

1. **Prépare l'image si nécessaire** dans `tp-travail/<sujet>/` : si le tableau est petit dans une grande image, recadre-le ; si le texte est flou, agrandis-le.

   ```bash
   magick source.png -crop LARGEURxHAUTEUR+X+Y +repage tp-travail/<sujet>/tableau.png
   magick tp-travail/<sujet>/tableau.png -resize 200% tp-travail/<sujet>/tableau-x2.png
   ```

   Pour un tableau dans un PDF : `pdftoppm -png -r 200 -f N -l N fichier.pdf tp-travail/<sujet>/page`.

2. **Lis l'image** et identifie : titre/légende, lignes et colonnes d'en-tête, cellules fusionnées (`colspan`, `rowspan`), unités, notes de bas de tableau, mises en évidence (gras, couleurs significatives).

3. **Produis le wikitext** dans `tp-travail/<sujet>/tableau.wiki` :

   ```
   {| class="wikitable"
   |+ Rendements en blé selon le couvert (q/ha, 2024)
   ! Modalité !! Rendement !! Écart au témoin
   |-
   | Témoin sol nu || 72 || –
   |-
   | Couvert féverole || 78 || +6
   |}
   ```

   - les unités vont dans l'en-tête ou la légende plutôt que dans chaque cellule ;
   - les nombres gardent la virgule décimale française sur le wiki français ;
   - ajoute `class="wikitable sortable"` si le tri a du sens ;
   - si la couleur porte une information, utilise `style="background:#…"` sur la cellule et explique-la dans la légende ;
   - les notes de bas de tableau vont sous le tableau, ou en `<ref>`.

4. **Vérification cellule par cellule.** Relis l'image et compare chaque valeur. Liste à l'utilisateur les cellules illisibles ou incertaines (marque-les `?` dans le tableau) plutôt que de deviner.

5. Si un nombre important de lignes/colonnes rend le tableau illisible sur mobile, propose de le scinder ou de le représenter en graphique (skill `graphique-depuis-image`).

6. Remets le wikitext à l'utilisateur, ou insère-le dans la page cible en suivant les règles de publication de `conventions`.
