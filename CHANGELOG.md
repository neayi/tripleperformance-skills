# Journal des modifications

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/), versionnage [sémantique](https://semver.org/lang/fr/).

## Non publié

### Modifié

- Les skills n'écrivent plus de liens internes elles-mêmes : après publication, elles appellent l'API `linktitles` (extension LinkTitles) via `mediawiki api`, puis montrent les liens ajoutés (`diff -u`). Nouvelle étape 9 des règles de publication dans `conventions`.

### Ajouté

- `conventions/references/titres.md` : règles de choix du titre par type de page (retour d'expérience, portrait de ferme, fiche technique, concept, livre, vidéo), appliquées par `nouvel-article`, `article-depuis-pdf` et `traduction`.
- Skill `images` : nommage explicite, photos en JPEG de 1000 px de large, PNG conservé pour schémas, tableaux et logos, choix de l'image d'illustration selon le modèle (partage OpenGraph), images dans le corps (vignette, centrée, galerie), proposition de conversion des tableaux et graphiques. Script `analyse_images.py`.
- Paragraphe introductif obligatoire avant le premier titre (sauf pages Vidéo) : il sert de description OpenGraph via l'extension Description2, tronquée vers 300 caractères.
- Skill `video-youtube` : import d'une vidéo YouTube (modèle Vidéo, vignette `thumbnail_youtube_<id>.jpg`, transcription brute, article mis en forme), avec le script `youtube.py`, qui vérifie d'abord par Semantic MediaWiki (`A une URL de vidéo`) que la vidéo n'est pas déjà sur le wiki.
- yt-dlp et Deno ajoutés aux outils installés (exécutable officiel de yt-dlp sous Linux, Homebrew sur macOS, winget sous Windows).
- `search.py --exists` : vérifie en une requête l'existence d'une liste de titres, redirections comprises.
- `search.py --langlinks` : liste les liens interlangues d'une ou plusieurs pages.
- Skill `traduction` : liaison réciproque des versions par liens interlangues (`[[en:...]]` / `[[fr:...]]`).
- `conventions/scripts/preview.py` : rendu d'un wikitext par l'API sans enregistrement, avec détection des erreurs de références, de modèles et des liens rouges. Étape ajoutée aux règles de publication.
- openpyxl ajouté aux outils installés (paquet système, ou pip `--user` sur macOS et Windows), pour lire les fichiers Excel.

## 0.1.0 - 2026-10-27

### Ajouté

- Structure du dépôt en plugin Claude Code avec marketplace.
- Scripts d'installation des outils pour Linux, macOS, WSL (`install.sh`) et Windows (`install.ps1`).
- Skills initiales : `conventions`, `recherche`, `nouvel-article`, `article-depuis-pdf`, `traduction`, `tableau-depuis-image`, `graphique-depuis-image`.
- Validation des skills (`scripts/validate_skills.py`) et intégration continue GitHub Actions.
