# Ce qui ne se traduit pas dans une page

Règles issues de l'outil de traduction automatique de Triple Performance (`gpt_wiki_translator`), affinées par ses tests. `scripts/verifier.py` contrôle la plupart d'entre elles. Complète cette page quand tu découvres un nouveau cas.

## Modèles

- **Nom du modèle** : jamais traduit (`{{Pratique}}` reste `{{Pratique}}` sur tous les wikis). Même chose pour les parser functions (`{{#ask:}}`, `{{#echarts:}}`, `{{#if:}}`…).
- **Nom des paramètres** : jamais traduit, il reste en français sur tous les wikis (`|Type de production=Field crops`). Un nom de paramètre traduit est ignoré par le modèle et la donnée sémantique disparaît.
- **Ordre et nombre des paramètres** : inchangés. Ne supprime pas un paramètre vide, n'en ajoute pas.
- **Valeurs** : traduites, sauf celles de la liste ci-dessous.

## Paramètres dont la valeur reste identique

Noms comparés sans tenir compte de la casse, des accents ni des espaces autour :

| Paramètre | Contenu |
|---|---|
| `Glyph` | nom d'icône de la police du wiki |
| `Icone` | nom de fichier d'icône |
| `Bannière` | nom de fichier |
| `Photo de l'agriculteur` | nom de fichier |
| `Logo` | nom de fichier |
| `Logo organisme` | nom de fichier |
| `Photo d'illustration` | nom de fichier |
| `Image` | nom de fichier |
| `class` | classes CSS |
| `Type de page` | valeur technique utilisée par les modèles |
| `frame` | option d'affichage |
| `query` | requête sémantique |

Les **noms de fichiers**, où qu'ils soient (`[[Fichier:…]]`, `<gallery>`, paramètres), ne se traduisent jamais : seul le préfixe d'espace de noms change (`Fichier:` → `File:`), et la légende se traduit.

## Paramètre `json` (sous-pages de graphiques)

N'importe quel modèle peut avoir un paramètre `json=`, pas seulement `{{Graphique Triple Performance}}`. Sa valeur est le titre d'une sous-page JSON **propre à chaque wiki** :

1. lis la sous-page source (`mediawiki read "<base source>/wiki/<Page>/<Nom>.json"`) ;
2. choisis le chemin cible `<Titre traduit>/<Nom traduit>.json` (pas de `/` dans le nom) ;
3. traduis seulement les **valeurs texte** : titres, noms d'étapes et d'interventions, descriptions, `title_*`, légendes, axes, région. Ne touche ni aux **clés**, ni aux nombres, booléens, dates, couleurs, `id`, coordonnées, ni à la structure (même nombre d'éléments dans chaque liste). Le résultat doit rester du JSON strict ;
4. vérifie avec `verifier.py --json source.json cible.json`, puis avec `graphique.py verifie` (skill `graphiques`) ;
5. publie avec `--content-model=json` (voir la skill `graphiques`) ;
6. **après** la traduction du texte de la page, remplace la valeur `json=` par le chemin cible. Ne la fais pas traduire avec le reste du texte : l'outil automatique se trompait justement là, en traduisant le chemin une deuxième fois. Le chemin final doit être exactement le titre de la sous-page créée.

## Titre de la page

- Un `:` dans un titre ne marque un espace de noms que si le préfixe en est un vrai (`Catégorie:`, `Fichier:`…). Sinon il fait partie du titre et se traduit avec lui.
- Si la source a déjà un lien interlangue vers la langue cible, **réutilise exactement ce titre**, même pour retraduire : un autre titre créerait un doublon.

## Liens

- **Liens interlangues** : `[[en:Titre]]`, sans deux-points initial. `[[:en:Titre]]` est un lien dans le texte, pas un lien interlangue : l'outil automatique a fait l'erreur lors de ses premiers tests.
- Les préfixes `gr` et `po` existent dans la table interwiki mais ne sont pas des langues : utilise `el` (grec) et `pt` (portugais).
- **Liens internes** : remplacés par leur texte traduit, sans lien ; LinkTitles pose ensuite les liens du wiki cible (voir `SKILL.md`). Garder `[[Page française|texte]]` donne un lien rouge sur le wiki cible.
- **Catégories et espaces de noms dans le corps** : à traduire aussi (`[[:Catégorie:Trèfles|trèfles]]` → `[[:Category:Clovers|clovers]]`), en visant une catégorie qui existe sur le wiki cible. L'outil automatique ne les traduisait que dans le titre.
- **Espaces autour des liens** : vérifie qu'ils sont conservés (`The [[…]] are`, pas `The[[…]]are`).

## Erreurs observées lors des traductions automatiques

- Contenu inventé ajouté à la page (un modèle « Infobox person » et la biographie d'un « John Doe » sont apparus dans une traduction) : compare toujours le nombre de sections, de références et la longueur du texte.
- Paragraphes oubliés sur les longues pages : traduis section par section et vérifie que chaque titre `==` de la source a son équivalent.
