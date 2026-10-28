---
name: video-youtube
description: Importe une vidéo YouTube sur Triple Performance — crée la page avec le modèle Vidéo (producteur, date, durée, intervenants, mots-clés, résumé), téléverse la vignette, ajoute la transcription brute puis un article complet mis en forme à partir de cette transcription. À utiliser quand l'utilisateur donne un lien YouTube et veut l'importer, le référencer, en faire une page ou un article sur le wiki.
---

# Importer une vidéo YouTube

Applique les règles de la skill `conventions`. Les fichiers de travail vont dans `tp-travail/youtube-<id>/`.

## 1. Récupérer la vidéo

```bash
python3 <dossier-de-cette-skill>/scripts/youtube.py "<url-youtube>"
```

Le script vérifie d'abord si la vidéo est déjà sur le wiki, en interrogeant la propriété Semantic MediaWiki `A une URL de vidéo` :

```
https://wiki.tripleperformance.fr/api.php?action=ask&format=json&query=[[A une URL de vidéo::~*<id>*]]|?A une URL de vidéo
```

S'il trouve une page, il l'affiche et s'arrête (code de sortie 3) sans rien télécharger : montre la page à l'utilisateur et demande s'il faut la compléter plutôt. Relance avec `--force` seulement s'il le demande.

Sinon, il appelle `yt-dlp` et écrit dans `tp-travail/youtube-<id>/` :

| Fichier | Contenu |
|---|---|
| `video.json` | id, URL canonique, titre d'origine et titre nettoyé, chaîne, date (`YYYY-MM-DD`), durée (`N minutes`), chapitres, licence |
| `description.txt` | description de la vidéo |
| `transcription.txt` | transcription brute (sous-titres manuels, sinon automatiques), sans horodatage |
| `transcription-chapitres.txt` | la même découpée selon les chapitres de la vidéo, quand il y en a |
| `thumbnail_youtube_<id>.jpg` | vignette convertie en JPEG, métadonnées retirées |

- Si `yt-dlp` manque, propose de relancer `./scripts/install.sh` (ou `install.ps1`) du dépôt des skills. S'il échoue sur une vidéo pourtant publique, il est probablement trop ancien : `yt-dlp -U` (ou réinstallation via le gestionnaire de paquets).
- `--lang en` force la langue de la transcription (par défaut : langue de la vidéo).
- Sans transcription disponible, préviens l'utilisateur : la page peut être créée avec le modèle seul, sans corps d'article.

## 2. Titre de la page

Le script propose `titre_page` : caractères interdits (`# < > [ ] | { } _`) et emojis retirés, titre tout en capitales passé en minuscules avec majuscule initiale. Relis-le :

- rétablis les majuscules des noms propres, sigles et lieux (« Lucien seguy » → « Lucien Séguy »), en t'appuyant sur la description ;
- ne garde pas de mots isolés en capitales sauf les sigles (`SEGUY` → `Séguy`, mais `CIRAD`, `MSV` restent) ;
- retire les fioritures sans intérêt pour un titre de wiki (« [REPLAY] », « 🔴 LIVE », numéro d'épisode seul) si l'utilisateur est d'accord.

Vérifie qu'aucune autre page ne porte déjà ce titre : `search.py --exists "<titre>"` (skill `recherche`). Si c'est le cas, propose un titre distinct à l'utilisateur.

## 3. Remplir le modèle Vidéo

```
{{Vidéo
| Producteur = <nom de la chaîne YouTube>
| Titre = <titre de la vidéo>
| Programme = 
| Pertinence =
| Top30_VdT =
| Thématique =
| Intervenants 0 = <Prénom Nom>
| Intervenants 1 = <Prénom Nom>
| Vignette = thumbnail_youtube_<id>.jpg
| Date de mise en ligne = <YYYY-MM-DD>
| Durée = <N> minutes
| Production =
| Vidéo = https://www.youtube.com/watch?v=<id>
| Mots-clés = <Mot-clé 1>, <Mot-clé 2>, ...
| Résumé = <résumé>
}}
```

Règles champ par champ :

- **Producteur** : `producteur` de `video.json` (nom de la chaîne), tel quel.
- **Titre** : le titre de la vidéo, avec les mêmes corrections de casse que le titre de la page.
- **Programme** : Le programme de recherche associé à la vidéo (ex : Conserwa, NBSOIL, SOL Couverts, etc.). Laisse vide si aucun programme n'est mentionné dans la vidéo ou la description. Le programme doit correspondre à une entrée de la catégorie https://wiki.tripleperformance.fr/wiki/Cat%C3%A9gorie:Projets
- **Pertinence**, **Top30_VdT**, **Thématique**, **Production** : laisser vides (ce sont des choix éditoriaux de l'équipe).
- **Intervenants 0, 1, 2…** : les personnes qui s'expriment, tirées du titre et de la description (pas de la transcription seule, trop peu fiable pour les noms). Un champ par personne, numéroté à partir de 0, au format `Prénom Nom` avec la bonne casse et les accents. Pas d'organisme ici. En cas de doute sur une personne, demande à l'utilisateur.
- **Vignette** : `thumbnail_youtube_<id>.jpg`.
- **Date de mise en ligne** : `date` de `video.json` (`YYYY-MM-DD`).
- **Durée** : `duree` de `video.json` (ex. `199 minutes`).
- **Vidéo** : URL au format `https://www.youtube.com/watch?v=<id>`, jamais `youtu.be` ni paramètres en plus.
- **Mots-clés** : 5 à 10 notions agronomiques réellement traitées dans la transcription, séparées par des virgules, chacune commençant par une majuscule (`Couverts végétaux, Semis direct, Potentiel redox`). Reprends de préférence des intitulés de pages existantes du wiki (vérifie avec `search.py --exists`).
- **Résumé** : 150 à 200 mots, en un seul paragraphe, qui résume le contenu de la transcription (pas la description YouTube). Tu peux utiliser du wikitext (gras, italique), mais pas de retour à la ligne, sans `|` ni `}}`, sans lien.

## 4. Transcription brute

Juste après le modèle :

```
{{Transcription
| transcription = <contenu de transcription.txt, tel quel>
}}
```

Copie le texte sans le corriger. Seule exception, pour ne pas casser le modèle : remplace `|` par `{{!}}` et entoure de `<nowiki>…</nowiki>` les éventuels `{{`, `}}`, `[[`, `]]`. Pour un fichier long, assemble la page avec un script plutôt qu'en recopiant le texte (voir étape 6).

## 5. Article mis en forme

Après la transcription, écris le corps de l'article à partir de la transcription. **Ce n'est pas un résumé** : c'est la transcription remise en forme pour être lue.

- Reste au plus près de ce qui est dit : garde tous les arguments, exemples, chiffres, anecdotes et nuances, dans l'ordre de la vidéo. N'ajoute aucune information qui n'est pas dans la vidéo.
- Transforme l'oral en écrit : phrases complètes, ponctuation, paragraphes ; supprime hésitations, répétitions et apartés sans contenu (« euh », « voilà donc bon », consignes techniques de la salle).
- Corrige les erreurs de reconnaissance vocale, en particulier les noms propres (personnes, organismes, lieux, produits) à l'aide du titre et de la description (« reddox » → « redox », « wageningen » → « Wageningen »). Si un passage reste incompréhensible, ne l'invente pas : signale-le à l'utilisateur.
- Les dialogues et questions du public peuvent être rendus en « Question : … » / réponse, ou en citations en italique entre guillemets pour les phrases marquantes.
- Listes à puces pour les énumérations, tableaux wiki si l'intervenant présente des données comparées.
- N'écris pas de liens internes : ils sont ajoutés après publication par LinkTitles (étape 7).

**Titres** : commence au niveau 2 (`== Titre ==`), puis `===` pour les sous-parties. Casse française : majuscule au premier mot seulement (et aux noms propres) — `== Le fonctionnement redox des sols ==`, jamais `== Le Fonctionnement Redox Des Sols ==`. Si la vidéo a des chapitres, ils donnent le plan de premier niveau.

**Vidéos longues** (plus de ~30 minutes) : travaille chapitre par chapitre à partir de `transcription-chapitres.txt` (ou par tranches de ~4 000 mots de `transcription.txt`), en lisant le fichier par portions. Écris chaque section dans `tp-travail/youtube-<id>/corps.wiki` au fur et à mesure (ajout en fin de fichier), puis relis l'ensemble pour l'homogénéité. Ne raccourcis pas les dernières parties faute de place.

## 6. Assembler et faire valider

Écris le modèle dans `entete.wiki`, puis assemble la page sans retaper la transcription :

```bash
cd tp-travail/youtube-<id>
python3 -c "
import pathlib, re
t = pathlib.Path('transcription.txt').read_text(encoding='utf-8').strip()
t = re.sub(r'(\{\{|\}\}|\[\[|\]\])', r'<nowiki>\1</nowiki>', t).replace('|', '{{!}}')
page = pathlib.Path('entete.wiki').read_text(encoding='utf-8').strip()
page += '\n\n{{Transcription\n| transcription = ' + t + '\n}}\n\n'
page += pathlib.Path('corps.wiki').read_text(encoding='utf-8').strip() + '\n'
pathlib.Path('page.wiki').write_text(page, encoding='utf-8')
"
```

Puis prévisualise `page.wiki` avec `preview.py` (skill `conventions`) et montre à l'utilisateur : le modèle rempli, le plan de l'article (titres), le nombre de mots du corps, et le chemin du fichier complet. Signale les noms propres corrigés dont tu n'es pas sûr.

## 7. Publier (après accord explicite)

1. **Vignette.** Vérifie qu'elle n'existe pas : `mediawiki read https://wiki.tripleperformance.fr/wiki/Fichier:thumbnail_youtube_<id>.jpg` (si elle existe déjà, ne la téléverse pas). Rappelle la licence indiquée par `video.json` et demande à l'utilisateur s'il a le droit de la publier. Description du fichier (`vignette.wiki`), sur le modèle de l'existant :

   ```
   Image accompagnant la vidéo [[<Titre de la page>]].

   Source : https://www.youtube.com/watch?v=<id> (<nom de la chaîne>)
   ```

   ```bash
   mediawiki upload "https://wiki.tripleperformance.fr/wiki/Fichier:thumbnail_youtube_<id>.jpg" tp-travail/youtube-<id>/thumbnail_youtube_<id>.jpg --description tp-travail/youtube-<id>/vignette.wiki --summary "Vignette de la vidéo YouTube <id>"
   ```

2. **Page.**

   ```bash
   mediawiki write "https://wiki.tripleperformance.fr/wiki/<Titre>" tp-travail/youtube-<id>/page.wiki --summary "Import de la vidéo YouTube <id> : fiche, transcription et article"
   ```

3. **Liens internes.** Fais-les poser par LinkTitles, puis montre à l'utilisateur ceux qui ont été ajoutés (étape 9 des règles de publication de `conventions`) :

   ```bash
   mediawiki api "https://wiki.tripleperformance.fr/api.php?action=linktitles&page=<Titre_avec_underscores>"
   mediawiki read "https://wiki.tripleperformance.fr/wiki/<Titre_avec_underscores>" > tp-travail/youtube-<id>/apres-liens.wiki
   diff -u tp-travail/youtube-<id>/page.wiki tp-travail/youtube-<id>/apres-liens.wiki
   ```

4. Donne l'URL de la page.

## À enrichir

Consigne ici les conventions découvertes pour les pages Vidéo (champs ajoutés par l'équipe, formulations attendues, cas particuliers de chaînes).
