---
name: images
description: Prépare et place les images d'un article Triple Performance — nommage explicite des fichiers, conversion des photos en JPEG et redimensionnement (PNG conservé pour schémas, tableaux et logos), choix de l'image d'illustration du modèle (Image, Bannière, Logo… utilisée pour le partage OpenGraph), insertion dans le corps (vignette à droite, image centrée, galerie) et téléversement. À utiliser dès qu'un article comporte des images, photos, logos, captures ou schémas, ou quand l'utilisateur veut ajouter, renommer, optimiser ou téléverser une image.
---

# Gérer les images d'un article

Applique les règles de la skill `conventions` (dossier `tp-travail/<sujet>/`, validation avant tout téléversement). Ne modifie jamais les images d'origine de l'utilisateur : écris les versions préparées dans `tp-travail/<sujet>/images/`.

## 1. Inventaire et analyse

Regarde chaque image (tu peux les lire directement) et lance l'analyse :

```bash
python3 <dossier-de-cette-skill>/scripts/analyse_images.py <image1> <image2> ...
```

Le script donne format, dimensions, orientation, poids, nombre de couleurs, transparence, et une suggestion de traitement. C'est un indice : c'est ce que montre l'image qui décide. Classe chaque image :

| Type | Exemples | Traitement |
|---|---|---|
| Photo | parcelle, matériel, animaux, portrait | JPEG, 1000 px de large au plus |
| Schéma, tableau, graphique, capture d'écran | itinéraire technique, plan de ferme, résultats d'essai | PNG conservé, **pas** de redimensionnement (lisibilité) |
| Logo, pictogramme | logo d'organisme, icône | PNG conservé (transparence), pas de redimensionnement |

**Tableau ou graphique en image** : propose à l'utilisateur de le convertir en tableau wiki (skill `tableau-depuis-image`) ou en graphique ECharts (skill `graphique-depuis-image`), qui seront lisibles, traduisibles et indexés. Préviens-le qu'il devra vérifier soigneusement chaque valeur reprise de l'image (risque d'erreur de lecture). S'il refuse, garde l'image en PNG.

## 2. Nommage

Le nom du fichier doit dire ce qu'on voit dans l'image, en lien avec la page :

- en français, avec espaces, majuscule initiale, extension en minuscules : `Semoir à dent autoconstruit vu de profil.jpg`, `Plan de la ferme EARL Besnard.png`, `Logo Chambre d'agriculture de la Charente-Maritime.png` ;
- assez précis pour être unique sur tout le wiki : ajoute le sujet de la page, le lieu ou la ferme (`Couvert de féverole en sortie d'hiver - EARL Besnard.jpg` plutôt que `Couvert.jpg`) ;
- jamais de nom générique (`IMG_1234.jpg`, `image1.png`, `photo.jpeg`, `capture d'écran 2024-…png`) ;
- pas de caractères interdits (`# < > [ ] | { } / :`) ;
- exception : les vignettes de vidéos gardent le nom `thumbnail_youtube_<id>.jpg` (skill `video-youtube`).

Vérifie que les noms sont libres, en une fois :

```bash
python3 <dossier-skill-recherche>/scripts/search.py --exists "Fichier:Nom 1.jpg" "Fichier:Nom 2.png"
```

Si un fichier du même nom existe, regarde s'il s'agit de la même image (alors réutilise-la) ; sinon, choisis un autre nom.

## 3. Conversion

Avec ImageMagick (`magick`, ou `convert` en version 6 — voir `conventions`) :

```bash
# Photo (PNG, HEIC, JPEG trop lourd…) → JPEG, 1000 px de large au plus, métadonnées retirées
magick source.png -auto-orient -strip -resize '1000x>' -quality 85 "tp-travail/<sujet>/images/Nom explicite.jpg"

# Schéma, tableau, logo → PNG conservé à sa taille, métadonnées retirées
magick source.png -strip "tp-travail/<sujet>/images/Nom explicite.png"
```

- `'1000x>'` ne réduit que les images de plus de 1000 px de large et n'agrandit jamais.
- `-strip` retire les données EXIF, dont la géolocalisation des photos.
- Une photo avec transparence (détourage) reste en PNG ; réduis-la tout de même à 1000 px de large.
- Indique à l'utilisateur le gain obtenu (poids avant et après).
- `-auto-orient -strip` est indispensable pour les photos de téléphone : le wiki pivote les miniatures mais y laisse la balise EXIF `Orientation`, et le navigateur les pivote une seconde fois. Une image déjà en ligne qui s'affiche couchée ou déformée (API `prop=imageinfo&iiprop=metadata` : `Orientation` ≠ 1) se corrige en téléversant une nouvelle version traitée ainsi, sous le même nom (`--ignore-warnings`), puis en purgeant la page (`action=purge`).

## 4. Image d'illustration du modèle

Choisis l'image qui représente le mieux l'article et place-la dans le modèle de page, pas dans le corps. C'est elle qui est affichée en tête de page et reprise comme image de partage (OpenGraph) : préfère une photo **horizontale ou carrée**, nette, représentative du sujet (pas un logo ni un schéma, sauf s'il n'y a rien d'autre). Ne la répète pas dans le corps du texte.

Les paramètres varient selon le modèle (valeur : le nom du fichier seul, sans `Fichier:`) :

| Modèle | Paramètres d'image |
|---|---|
| `Pratique`, `Culture`, `Bioagresseur`, `Label`, `Projet étudiant` | `Image` + `ImageCaption` (légende) ; `Icone` pour un pictogramme |
| `Arbre`, `Auxiliaire`, `Accident climatique et physiologique`, `Outil d'aide`, `MFSC` | `Image` + `ImageCaption` |
| `Matériel`, `Intrant` | `Photo d'illustration` (ou `Image`) + `ImageCaption` |
| `Exemple de mise en œuvre` | `Image` + `ImageCaption`, `Photo d'illustration`, `Photo de l'agriculteur` |
| `ITK` | `Image` + `ImageCaption` ; sans `Image`, photo de la page de culture, seulement si `Culture` n'en contient qu'une |
| `Portrait de ferme` | `Photo d'illustration`, `Photo de l'agriculteur`, `Logo` (de la ferme), `Bannière` |
| `Programme` | `Logo` (du programme), `Logo organisme` (organisme porteur), `Bannière` (photo horizontale, image de partage) |
| `Structure` | `Logo`, `Bannière` |
| `Livre` | `Jaquette` (couverture) |
| `Vidéo` | `Vignette` (skill `video-youtube`) |

Pour un modèle absent du tableau, ou en cas de doute, lis son formulaire (`mediawiki read https://wiki.tripleperformance.fr/wiki/Formulaire:<Modèle>`) et complète ce tableau.

`ImageCaption` est facultatif : mets une légende courte quand elle apporte une information (lieu, date, ce que montre la photo).

## 5. Images dans le corps du texte

Trois façons de placer une image (le wiki accepte `File:` comme `Fichier:`) :

```
[[File:Interface du logiciel MERCI.jpg|thumbnail|Aperçu du logiciel MERCI]]
```
À droite, habillée par le texte, avec cadre et légende : pour une photo qui illustre un paragraphe.

```
[[File:Interface du logiciel MERCI.jpg|center|thumbnail|400px|Aperçu du logiciel MERCI]]
```
Au centre, sans habillage, avec cadre et légende : pour un schéma ou une image qu'on doit regarder en détail. Ajuste la largeur (`400px`, `600px`…) à la lisibilité.

```
[[File:Interface du logiciel MERCI.jpg|center|noframe|400px]]
```
Au centre, sans habillage et sans cadre, quand il n'y a pas de légende.

Plusieurs images à la suite : utilise une galerie plutôt qu'une série d'images.

```
<gallery mode="slideshow" showthumbnails>
File:Nom image 1.jpg|Légende de la première image
File:Nom image 2.jpg|Légende de la deuxième image
File:Nom image 3.png|Légende de la troisième image
</gallery>
```

Rappels : pas d'image avant le paragraphe introductif (voir `conventions`) ; une légende décrit ce qu'on voit, elle ne répète pas le titre de la section.

## 6. Téléversement

Après accord explicite de l'utilisateur, et seulement s'il a le droit de publier les images (demande-lui la source, l'auteur et la licence) :

1. Montre la liste : nom final, type, traitement appliqué, emplacement prévu (modèle ou corps), légende.
2. Écris une description par fichier, par exemple `tp-travail/<sujet>/images/Nom explicite.desc.wiki` :

   ```
   Photo illustrant la page [[<Titre de la page>]].

   Auteur : <auteur> — Source : <source> — Licence : <licence>
   ```

3. Téléverse chaque image :

   ```bash
   mediawiki upload "https://wiki.tripleperformance.fr/wiki/Fichier:<Nom explicite>.jpg" "tp-travail/<sujet>/images/<Nom explicite>.jpg" --description "tp-travail/<sujet>/images/<Nom explicite>.desc.wiki" --summary "Image pour la page <Titre>"
   ```

4. Téléverse les images **avant** la page qui les utilise, puis vérifie avec `preview.py` (skill `conventions`) qu'aucun fichier n'apparaît en lien rouge.

## À enrichir

Consigne ici les paramètres d'image des modèles non encore listés et les cas particuliers rencontrés.
