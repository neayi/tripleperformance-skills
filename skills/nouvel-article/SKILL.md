---
name: nouvel-article
description: Crée un nouvel article sur Triple Performance à partir d'un des modèles de la Catégorie:Modèles de catégories (Pratique, Culture, Bioagresseur, Auxiliaire, Matériel, Intrant, Outil d'aide, Exemple de mise en œuvre, ITK (itinéraire technique), Livre, Vidéo, Label, Projet étudiant…). À utiliser quand l'utilisateur veut créer, rédiger ou initialiser une page, une fiche pratique, une fiche culture, une fiche matériel, etc.
---

# Créer un article à partir d'un modèle

Applique les règles de la skill `conventions`.

## Déroulé

1. **Vérifie que la page n'existe pas.** Utilise la skill `recherche` sur le sujet. Si une page proche existe, montre-la et demande s'il faut plutôt la compléter.

2. **Choisis le modèle.** Liste les modèles disponibles :

   ```bash
   python3 <dossier-skill-recherche>/scripts/search.py --category "Modèles de catégories" --limit 50
   ```

   Propose le plus adapté à l'utilisateur et fais-le confirmer s'il y a un doute (ex. « Pratique » vs « Exemple de mise en œuvre »). Pour une vidéo YouTube, utilise plutôt la skill `video-youtube`.

3. **Récupère la structure attendue** dans `tp-travail/<sujet>/` :
   - les paramètres du modèle via TemplateData et les pièges propres à chaque modèle : voir [references/modeles.md](references/modeles.md) ;
   - le formulaire Page Forms, s'il existe, pour les valeurs possibles des champs (listes, catégories proposées) ;
   - **deux ou trois articles existants** utilisant ce modèle, de préférence bien remplis, comme exemples de ton, de plan et de remplissage des champs :

     ```bash
     python3 <dossier-skill-recherche>/scripts/search.py --template "<Modèle>" --limit 20
     ```

4. **Rassemble le contenu.** Demande à l'utilisateur ses sources (notes, PDF → skill `article-depuis-pdf`, liens, témoignages) et les informations manquantes pour les champs obligatoires. N'invente pas de données chiffrées ni de témoignages.

5. **Rédige le wikitext** dans `tp-travail/<sujet>/<Titre>.wiki` :
   - appel du modèle en tête, avec les champs du formulaire, une ligne par champ (`| Champ = valeur`) ; les valeurs multiples suivent le séparateur indiqué par le formulaire (souvent `,`) ;
   - paragraphe introductif avant le premier titre, autonome et informatif dès les 300 premiers caractères (voir « Structure d'un article » dans `conventions`) ;
   - plan inspiré des articles exemples ;
   - pas de liens internes : ils sont ajoutés par LinkTitles une fois la page en ligne (voir `conventions`)
   - Utilise `<ref>` pour les références, en précisant l'url de la page ou du PDF, le nom de l'auteur et la date si possible.
   - ton : clair, factuel, orienté agriculteurs ; citations d'agriculteurs entre guillemets et en italique si c'est l'usage dans les exemples.

6. **Fais valider puis publie** selon les règles de publication de `conventions` :

   ```bash
   mediawiki write "https://wiki.tripleperformance.fr/wiki/<Titre>" tp-travail/<sujet>/<Titre>.wiki --summary "Création de la page <Titre>"
   ```

   puis ajoute les liens internes avec LinkTitles (étape 9 des règles de publication).

7. **Images** : choisis l'image d'illustration du modèle (`Image`, `Bannière`, `Logo`… selon le modèle), prépare et téléverse les images avec la skill `images`, avant la page qui les utilise.

## Titre de la page

Applique les règles de titre par type de page de la skill `conventions` (`references/titres.md`) : « Mise en place d'une serre en aquaponie de 1600 m² dans le Gers » pour un retour d'expérience, « Autoconstruire un semoir à dent » pour une fiche technique (`Pratique`), « EARL Besnard » pour un portrait de ferme, « Bruche du pois » pour un concept, « Le pâturage tournant dynamique (2020) » pour un livre. Ne recopie pas la forme des titres existants quand elle s'en écarte. Fais valider le titre en même temps que le choix du modèle (étape 2).

## À enrichir

Consigne les champs obligatoires et pièges rencontrés, modèle par modèle, dans [references/modeles.md](references/modeles.md).
