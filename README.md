# Skills Triple Performance pour Claude Code

Un ensemble de [skills](https://docs.claude.com/en/docs/claude-code/skills) pour [Claude Code](https://claude.com/claude-code) qui aident les contributeurs de [Triple Performance](https://tripleperformance.fr), le wiki collaboratif de l'agroécologie, à rédiger, traduire et enrichir des articles.

Les skills s'appuient sur des outils en ligne de commande : la CLI [`mediawiki`](https://github.com/neayi/Mediawiki-LLM-Cli) pour lire et modifier les pages, ImageMagick pour les images, Pandoc et Poppler pour les documents.

## Skills disponibles

| Skill | Ce qu'elle fait | Exemple de demande |
|---|---|---|
| `conventions` | Socle commun : URLs des wikis, usage de la CLI, règles de sécurité. Chargée par les autres skills. | — |
| `recherche` | Cherche les articles existants sur Triple Performance (toutes langues). | « Est-ce qu'il existe déjà un article sur le semis direct sous couvert ? » |
| `nouvel-article` | Crée un article à partir d'un modèle de la [Catégorie:Modèles de catégories](https://wiki.tripleperformance.fr/wiki/Cat%C3%A9gorie:Mod%C3%A8les_de_cat%C3%A9gories) (Pratique, Culture, Matériel…). | « Crée une page Pratique sur le pâturage tournant dynamique. » |
| `article-depuis-pdf` | Rédige un article à partir d'un ou plusieurs PDF (comptes rendus d'essais, fiches techniques…). | « Fais un article à partir de ces deux PDF de la chambre d'agriculture. » |
| `traduction` | Traduit une page d'une version linguistique du wiki vers une autre. | « Traduis la page Ferme des Pâtures en anglais. » |
| `tableau-depuis-image` | Convertit une image de tableau en tableau wiki natif. | « Transforme cette capture de tableau en tableau wiki. » |
| `graphique-depuis-image` | Convertit une image de graphique en graphique natif ECharts. | « Refais ce graphique en ECharts. » |
| `images` | Nomme, convertit, redimensionne et place les images d'un article ; choisit l'image d'illustration du modèle. | « Ajoute ces photos à l'article et choisis l'image principale. » |
| `video-youtube` | Importe une vidéo YouTube : fiche Vidéo, vignette, transcription et article mis en forme. | « Importe cette vidéo : https://www.youtube.com/watch?v=KZ5Tz3IGoSI » |

Les skills se déclenchent automatiquement quand votre demande correspond à leur description. Vous pouvez aussi les appeler explicitement, par exemple `/triple-performance:recherche`.

## Installation

### 1. Installer les outils

Clonez ce dépôt, puis lancez le script correspondant à votre système. Il détecte ce qui est déjà installé et n'installe que ce qui manque.

**Linux, macOS, WSL**

```bash
git clone https://github.com/neayi/tripleperformance-skills.git
cd tripleperformance-skills
./scripts/install.sh            # installe ce qui manque
./scripts/install.sh --check    # vérifie seulement, n'installe rien
```

Gestionnaires de paquets pris en charge : `apt` (Debian, Ubuntu, WSL), `dnf` (Fedora), `pacman` (Arch), `zypper` (openSUSE) et Homebrew (macOS, installé au besoin après confirmation).

**Windows (PowerShell)**

```powershell
git clone https://github.com/neayi/tripleperformance-skills.git
cd tripleperformance-skills
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1           # installe
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Check    # vérifie seulement
```

Le script utilise `winget`, présent par défaut sur Windows 10 et 11.

Outils installés :

| Outil | Commande | Rôle |
|---|---|---|
| Mediawiki-LLM-Cli | `mediawiki` | Lire, écrire, renommer des pages, téléverser des fichiers |
| ImageMagick | `magick` (ou `convert` en v6) | Convertir, recadrer, redimensionner les images |
| Pandoc | `pandoc` | Convertir entre formats (docx, html, markdown → wikitext…) |
| Poppler | `pdftotext`, `pdftoppm`, `pdfimages` | Extraire texte, pages et images des PDF |
| jq | `jq` | Manipuler le JSON des API |
| Python 3 | `python3` | Scripts d'assistance des skills (bibliothèque standard uniquement) |
| openpyxl | module Python | Lire et écrire les fichiers Excel (`.xlsx`) fournis par les contributeurs |
| yt-dlp | `yt-dlp` | Récupérer titre, description, vignette et transcription des vidéos YouTube |
| Deno | `deno` | Moteur JavaScript dont yt-dlp a besoin pour YouTube |
| curl, git | `curl`, `git` | Appels API, mise à jour du dépôt |

### 2. Se connecter au wiki

La lecture ne demande pas de compte. Pour écrire, connectez-vous une fois par wiki :

```bash
mediawiki login https://wiki.tripleperformance.fr
mediawiki login https://en.tripleperformance.ag    # si vous traduisez vers l'anglais
```

La commande ouvre la page `Spécial:BotPasswords` et vous guide pour créer un mot de passe de robot. Accordez au moins les droits d'édition, de création de pages et de téléversement de fichiers.

### 3. Installer les skills dans Claude Code

Dans Claude Code :

```
/plugin marketplace add neayi/tripleperformance-skills
/plugin install triple-performance@triple-performance
```

Pour récupérer les nouvelles versions : `/plugin marketplace update triple-performance`.

## Utilisation

Ouvrez Claude Code dans un dossier de travail (celui où se trouvent vos PDF ou images, par exemple) et décrivez ce que vous voulez faire. Les fichiers intermédiaires sont écrits dans un sous-dossier `tp-travail/` de ce dossier.

Les skills ne publient **jamais** sur le wiki sans vous avoir montré le texte final (ou le diff, pour une page existante) et obtenu votre accord explicite.

## Contribuer

Les skills sont faites pour s'améliorer au fil de l'usage : si une skill se trompe, fait un détour inutile ou ignore une convention du wiki, corrigez-la. Voir [CONTRIBUTING.md](CONTRIBUTING.md) pour l'organisation du dépôt, le test en local et le processus de publication.
