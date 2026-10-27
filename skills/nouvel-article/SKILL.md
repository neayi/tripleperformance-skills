---
name: nouvel-article
description: Crée un nouvel article sur Triple Performance à partir d'un des modèles de la Catégorie:Modèles de catégories (Pratique, Culture, Bioagresseur, Auxiliaire, Matériel, Intrant, Outil d'aide, Exemple de mise en œuvre, Livre, Vidéo, Label, Projet étudiant…). À utiliser quand l'utilisateur veut créer, rédiger ou initialiser une page, une fiche pratique, une fiche culture, une fiche matériel, etc.
---

# Créer un article à partir d'un modèle

Applique les règles de la skill `conventions`.

## Déroulé

1. **Vérifie que la page n'existe pas.** Utilise la skill `recherche` sur le sujet. Si une page proche existe, montre-la et demande s'il faut plutôt la compléter.

2. **Choisis le modèle.** Liste les modèles disponibles :

   ```bash
   python3 <dossier-skill-recherche>/scripts/search.py --category "Modèles de catégories" --limit 50
   ```

   Propose le plus adapté à l'utilisateur et fais-le confirmer s'il y a un doute (ex. « Pratique » vs « Exemple de mise en œuvre »).

3. **Récupère la structure attendue** dans `tp-travail/<sujet>/` :
   - le formulaire Page Forms, qui liste les champs et leurs valeurs possibles : `mediawiki read https://wiki.tripleperformance.fr/wiki/Formulaire:<Modèle>` (s'il contient `#REDIRECTION [[...]]`, lis la cible) ;
   - le modèle lui-même si besoin : `mediawiki read https://wiki.tripleperformance.fr/wiki/Modèle:<Modèle>` (la partie `<noinclude>` documente parfois l'usage) ;
   - **deux ou trois articles existants** utilisant ce modèle, de préférence bien remplis, comme exemples de ton, de plan et de remplissage des champs :

     ```bash
     python3 <dossier-skill-recherche>/scripts/search.py --template "<Modèle>" --limit 20
     ```

4. **Rassemble le contenu.** Demande à l'utilisateur ses sources (notes, PDF → skill `article-depuis-pdf`, liens, témoignages) et les informations manquantes pour les champs obligatoires. N'invente pas de données chiffrées ni de témoignages.

5. **Rédige le wikitext** dans `tp-travail/<sujet>/<Titre>.wiki` :
   - appel du modèle en tête, avec les champs du formulaire, une ligne par champ (`| Champ = valeur`) ; les valeurs multiples suivent le séparateur indiqué par le formulaire (souvent `,`) ;
   - plan inspiré des articles exemples ;
   - liens internes vers les pages existantes (vérifiées), références en `<ref>` ;
   - ton : clair, factuel, orienté agriculteurs ; citations d'agriculteurs entre guillemets et en italique si c'est l'usage dans les exemples.

6. **Fais valider puis publie** selon les règles de publication de `conventions` :

   ```bash
   mediawiki write "https://wiki.tripleperformance.fr/wiki/<Titre>" tp-travail/<sujet>/<Titre>.wiki --summary "Création de la page <Titre>"
   ```

7. Si l'article prévoit une image (champ `Image`, `Bannière`…), prépare-la et téléverse-la selon `conventions`, après accord.

## Titre de la page

Reprends la forme des titres existants du même modèle (singulier/pluriel, majuscule initiale uniquement, pas d'article en tête sauf usage contraire).

## À enrichir

Consigne ici, modèle par modèle, les champs obligatoires et pièges rencontrés (ex. séparateur `@` pour `Objectif` et `Type de production` dans `Pratique`).
