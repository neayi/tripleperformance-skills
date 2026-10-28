---
name: conventions
description: Règles communes pour travailler sur le wiki Triple Performance (tripleperformance.fr et ses versions *.tripleperformance.ag) — URLs des wikis par langue, utilisation de la CLI mediawiki, ImageMagick, Pandoc, structure des pages et règles de publication. À charger avant toute lecture ou écriture sur Triple Performance, et par les autres skills de ce plugin.
---

# Conventions Triple Performance

## Les wikis

| Langue | URL de base | API |
|---|---|---|
| Français | `https://wiki.tripleperformance.fr` | `https://wiki.tripleperformance.fr/api.php` |
| Autres (`en`, `de`, `es`, `it`, `nl`, `pl`, `pt`, `ar`, `el`, `fi`, `hu`) | `https://<code>.tripleperformance.ag` | `https://<code>.tripleperformance.ag/api.php` |

`tripleperformance.fr` redirige vers `wiki.tripleperformance.fr` : utilise directement `wiki.tripleperformance.fr` dans les commandes. Une page a pour URL `<base>/wiki/<Titre_avec_underscores>`.

Espaces de noms : en français `Catégorie:`, `Modèle:`, `Fichier:`, `Formulaire:`, `Utilisateur:` ; en anglais `Category:`, `Template:`, `File:`, `Form:`, `User:`.

## Outils

### CLI `mediawiki`

```bash
mediawiki read  <url-page>  > page.wiki                       # lire (échoue si la page n'existe pas)
mediawiki write <url-page> page.wiki --summary "Résumé"       # créer ou remplacer la page entière
mediawiki upload <url-Fichier:Nom.jpg> image.jpg --description desc.wiki --summary "..."
mediawiki rename <url-page> <nouvelle-url> --reason "..."
```

- `mediawiki read` sert aussi à tester l'existence d'une page (code de sortie 1 si absente).
- Les commandes d'écriture échouent avec `not logged in to <wiki>` si l'utilisateur n'est pas connecté : propose-lui alors de lancer `! mediawiki login <url-du-wiki>`.
- Il n'y a pas de commande de recherche : utilise la skill `recherche` ou l'API (`action=query&list=search`).

### ImageMagick

Sur ImageMagick 7 la commande est `magick` ; sur ImageMagick 6 (Debian/Ubuntu) c'est `convert`. Vérifie avec `command -v magick || command -v convert`.

Pour préparer, nommer, placer et téléverser des images (photo en JPEG de 1000 px de large, PNG conservé pour schémas et logos, image d'illustration du modèle, galeries), utilise la skill `images`.

### Pandoc et Poppler

```bash
pdftotext -layout fichier.pdf tp-travail/fichier.txt      # texte d'un PDF
pdftoppm -png -r 150 -f 3 -l 3 fichier.pdf tp-travail/p   # page 3 en image
pdfimages -png fichier.pdf tp-travail/img                 # images incluses
pandoc document.docx -t mediawiki -o tp-travail/doc.wiki  # docx/html/md → wikitext
```

### Python

Les scripts des skills utilisent Python 3 sans dépendance. Sous Windows, si `python3` est introuvable, utilise `python` ou `py`.

Pour lire ou produire un fichier Excel (`.xlsx`), utilise le module `openpyxl`, installé par les scripts d'installation. Charge le classeur avec `openpyxl.load_workbook(chemin, data_only=True)` pour obtenir les valeurs calculées des formules plutôt que les formules elles-mêmes. S'il manque, propose à l'utilisateur de relancer `./scripts/install.sh` (ou `install.ps1`) du dépôt des skills.

## Dossier de travail

Écris tous les fichiers intermédiaires (wikitext, images converties, extraits de PDF) dans `tp-travail/<sujet>/` dans le dossier courant. Ne modifie jamais les fichiers sources de l'utilisateur.

## Structure d'un article

- Un article commence par l'appel d'un modèle de page (`{{Pratique ...}}`, `{{Portrait de ferme ...}}`, `{{Culture ...}}`…) dont les paramètres alimentent Semantic MediaWiki ; ce modèle pose aussi les catégories. Les modèles disponibles sont listés dans `Catégorie:Modèles de catégories`.
- **Paragraphe introductif obligatoire.** Juste après le modèle de page et avant le premier titre `==`, écris un paragraphe d'introduction : c'est lui que l'extension Description2 reprend comme description de la page (balises `description` et `og:description`), affichée quand l'article est partagé (réseaux sociaux, messageries) et dans les moteurs de recherche. Elle est tronquée vers 300 caractères : la première ou les deux premières phrases doivent dire à elles seules de quoi parle la page et ce qu'elle a d'intéressant (qui, quoi, où, résultat). Texte simple uniquement — ni image, ni modèle, ni liste, ni tableau avant ce paragraphe. Seule exception : les pages Vidéo, dont le résumé est dans le modèle (skill `video-youtube`).
- Le corps est en wikitext : titres `==`, listes `*`, liens internes `[[Titre]]` ou `[[Titre|texte]]`, références `<ref>...</ref>` puis `{{Références}}` ou `<references />` en fin de page.
- Les graphiques utilisent l'extension ECharts : voir la skill `graphique-depuis-image`.
- **N'ajoute pas toi-même de liens internes** vers les articles du wiki : une fois la page en ligne, l'extension LinkTitles les pose automatiquement (étape 9 des règles de publication). Restent écrits à la main seulement les liens qui font partie de la structure : liens interlangues, images (`[[Fichier:...]]`), catégories, et ceux que l'utilisateur demande explicitement. Vérifie ces titres en une fois avec `search.py --exists "Titre 1" "Titre 2" ...` (skill `recherche`).
- Les liens interlangues se placent en fin de page, un par langue : `[[en:STIR]]`. Ils sont réciproques (la page anglaise porte `[[fr:...]]`) et peuvent viser une redirection. Voir la skill `traduction`.

Pour le détail des éléments de mise en page, voir [references/wikitext.md](references/wikitext.md).

## Titre des pages

Le titre suit des règles propres à chaque type de page (nom d'action pour un retour d'expérience, infinitif pour une fiche technique, nom de la ferme pour un portrait, nom au singulier pour un concept, année entre parenthèses pour un livre…) : voir [references/titres.md](references/titres.md). Propose toujours le titre à l'utilisateur avant de rédiger.

## Règles de publication (obligatoires)

1. **Lire avant d'écrire.** Avant de modifier une page existante, récupère sa version actuelle avec `mediawiki read`.
2. **Écrire en local d'abord.** Produis le wikitext complet dans `tp-travail/`.
3. **Prévisualiser sans enregistrer.** Fais rendre le wikitext complet par l'API avec le script `scripts/preview.py` de cette skill :

   ```bash
   python3 <dossier-de-la-skill-conventions>/scripts/preview.py tp-travail/<sujet>/page.wiki --title "<Titre de la page>" [--lang en]
   ```

   Il signale les erreurs de références (`<ref>` sans contenu, doublons), les erreurs de modèles ou de parser functions, les liens rouges et les avertissements de l'analyseur (code de sortie 1). Corrige-les avant de montrer le résultat, ou explique à l'utilisateur pourquoi un lien rouge est volontaire. `--html apercu.html` enregistre le rendu pour qu'il puisse l'ouvrir dans un navigateur.
4. **Montrer et faire valider.** Pour une page nouvelle, montre le wikitext (ou un résumé structuré s'il est long, avec le chemin du fichier). Pour une page existante, montre `diff -u ancien.wiki nouveau.wiki`. Attends un accord explicite.
5. **Résumé de modification** en français, précis, avec `--summary` (ex. « Création de la page à partir du compte rendu d'essai 2024 de la Chambre d'agriculture »).
6. **Jamais de suppression ni de renommage** sans demande explicite de l'utilisateur.
7. **Images** (détails dans la skill `images`) : vérifie que le fichier n'existe pas déjà (`mediawiki read <base>/wiki/Fichier:Nom.jpg`), mentionne la source et la licence dans la description, et demande à l'utilisateur s'il a le droit de publier l'image.
8. Après publication, donne l'URL de la page à l'utilisateur.
9. **Liens internes automatiques.** Juste après avoir publié un article (création ou modification), fais poser les liens par LinkTitles, présent sur tous les wikis Triple Performance. Annonce cette étape au moment de la validation (étape 4) : l'accord donné pour publier la couvre.

   ```bash
   mediawiki api "<base>/api.php?action=linktitles&page=<Titre_avec_underscores>"
   mediawiki read "<base>/wiki/<Titre_avec_underscores>" > tp-travail/<sujet>/apres-liens.wiki
   diff -u tp-travail/<sujet>/page.wiki tp-travail/<sujet>/apres-liens.wiki
   ```

   La CLI se charge du jeton et du POST ; l'utilisateur doit être connecté. Montre les liens ajoutés à l'utilisateur. Si l'un d'eux est hors sujet (homonyme, lien dans une citation), propose de le retirer : c'est une nouvelle modification, à faire valider comme les autres. Si la page cible est un homonyme courant (ex. `Verse`, `Rouille`, `Test`), propose aussi d'ajouter `__NOAUTOLINKTARGET__` en fin de page cible (redirections comprises) pour que LinkTitles ne la vise plus ; l'API `prop=pageprops` doit alors renvoyer `MAG_LINKTITLES_NOTARGET`.

## Améliorer cette skill

Quand tu découvres une convention du wiki qui n'est pas documentée ici (champ obligatoire, catégorie, formulation attendue), signale-la à l'utilisateur et propose de l'ajouter à ce fichier ou à `references/`.
