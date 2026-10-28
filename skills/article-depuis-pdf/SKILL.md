---
name: article-depuis-pdf
description: Rédige ou complète un article Triple Performance à partir d'un ou plusieurs documents PDF (compte rendu d'essai, fiche technique, rapport, présentation, article de presse agricole). Extrait texte, tableaux, graphiques et images, puis produit un wikitext structuré. À utiliser quand l'utilisateur fournit des PDF et veut en tirer un article, une synthèse ou une page wiki.
---

# Rédiger un article à partir de PDF

Applique les règles de la skill `conventions`.

## Déroulé

1. **Inventaire.** Pour chaque PDF : `pdfinfo fichier.pdf` (nombre de pages, titre, auteur, date). Demande à l'utilisateur quel est l'objectif : nouvel article, ou enrichissement d'une page existante ? Pour quel public ?

2. **Extraction** dans `tp-travail/<sujet>/` :

   ```bash
   pdftotext -layout fichier.pdf tp-travail/<sujet>/fichier.txt
   ```

   - Si le texte extrait est vide ou illisible (PDF scanné), convertis les pages en images (`pdftoppm -png -r 150`) et lis-les directement.
   - Pour les pages contenant des tableaux ou graphiques, génère l'image de la page (`pdftoppm -png -r 150 -f N -l N`) et regarde-la : la mise en page de `pdftotext` déforme souvent les tableaux.
   - Images utiles (photos de parcelles, matériel) : `pdfimages -png -f N -l N fichier.pdf tp-travail/<sujet>/img`, puis tri, nommage, conversion et choix de l'image d'illustration avec la skill `images`.

3. **Vérifie l'existant** avec la skill `recherche` : page déjà existante sur le sujet, pages à lier (cultures, pratiques, matériels cités).

4. **Plan.** Choisis le modèle de page (voir skill `nouvel-article`) et le titre selon les règles de `conventions` (`references/titres.md`), et propose un plan à l'utilisateur avant de rédiger si le document est long ou couvre plusieurs sujets (il peut falloir plusieurs articles).

5. **Rédaction** dans `tp-travail/<sujet>/<Titre>.wiki` :
   - commence, après le modèle, par un paragraphe introductif qui présente le document et son apport principal (voir « Structure d'un article » dans `conventions`) ;
   - reformule pour un public d'agriculteurs, ne recopie pas des pages entières ;
   - garde **tous les chiffres exacts** (doses, rendements, dates, surfaces) et indique leur contexte (année, lieu, conditions) ;
   - tableaux → wikitext natif (voir skill `tableau-depuis-image`) ;
   - graphiques → ECharts (voir skill `graphique-depuis-image`) quand ils apportent une information clé ;
   - cite la source avec `<ref>` (auteur/organisme, titre, année, URL si disponible) et ajoute une section « Références ».

6. **Contrôle.** Relis le wikitext en comparant aux sources : aucun chiffre ni affirmation qui ne soit dans les PDF ; signale à l'utilisateur les points ambigus ou contradictoires entre documents.

7. **Droits.** Demande à l'utilisateur s'il est autorisé à reprendre les images et le contenu du PDF (et sous quelle licence). Mentionne l'origine dans la description des fichiers téléversés.

8. **Validation et publication** selon `conventions`. Pour joindre le PDF lui-même au wiki, téléverse-le comme `Fichier:` et ajoute un lien vers lui, avec l'accord de l'utilisateur.

## Plusieurs PDF

Traite chaque document séparément (étapes 1-2), puis fais une synthèse : regroupe par thème, signale les résultats divergents entre essais plutôt que de les moyenner.
