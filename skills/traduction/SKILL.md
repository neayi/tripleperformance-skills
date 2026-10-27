---
name: traduction
description: Traduit une page de Triple Performance d'une version linguistique du wiki vers une autre (par exemple de wiki.tripleperformance.fr vers en.tripleperformance.ag), en adaptant les modèles, liens internes, catégories et noms de fichiers. À utiliser quand l'utilisateur veut traduire, porter ou publier une page dans une autre langue.
---

# Traduire une page entre deux wikis

Applique les règles de la skill `conventions`.

## Déroulé

1. **Identifie la source et la cible.** Langue source, langue cible, URL de la page source. Lis la source dans `tp-travail/<sujet>/source.wiki` :

   ```bash
   mediawiki read "https://wiki.tripleperformance.fr/wiki/<Titre>" > tp-travail/<sujet>/source.wiki
   ```

2. **Vérifie que la page n'existe pas déjà dans la langue cible.** Regarde d'abord ses liens interlangues : `search.py --langlinks "<Titre>"` (ou la ligne `[[<cible>:...]]` en fin de wikitext). Sinon, recherche le titre traduit et ses variantes avec `search.py --lang <cible>`. Si la page existe, demande s'il faut la mettre à jour (et montre un diff).

3. **Inventorie ce qui ne se traduit pas mot à mot :**
   - **Modèle de page et noms de paramètres** : sur les wikis non francophones, les **noms de paramètres restent en français** et seules les valeurs sont traduites (ex. sur en.tripleperformance.ag : `|Type de production=Field crops`, `|Mots-clés=Cover crops, ...`). Vérifie toujours sur un article exemple du wiki cible (`search.py --template <Nom> --lang <cible>` puis `mediawiki read`).
   - **Valeurs de paramètres sémantiques** (type de production, objectif…) : utilise les valeurs existantes sur le wiki cible.
   - **Liens internes** : pour chaque `[[Page]]`, cherche la page équivalente sur le wiki cible. Les liens interlangues des pages liées donnent souvent la réponse directement (`search.py --langlinks "Page 1" "Page 2" ...` sur le wiki source) ; vérifie ensuite tous les titres retenus avec `search.py --exists --lang <cible> ...`. Si une page n'a pas d'équivalent, garde le texte sans lien ou signale-le à l'utilisateur.
   - **Liens interlangues existants** : retire de la traduction la ligne `[[<cible>:...]]` de la source (une page ne pointe pas vers sa propre langue) ; les autres (`[[de:...]]`…) peuvent être conservées.
   - **Fichiers** : les images sont-elles disponibles sur le wiki cible ? Sinon, liste-les pour téléversement (avec accord).
   - **Espaces de noms** : `Catégorie:` → `Category:`, `Fichier:` → `File:`, etc.
   - **Graphiques ECharts** : traduis les textes (`title`, `name`, libellés d'axes, légendes) dans le JSON sans toucher à la structure.

4. **Traduis** dans `tp-travail/<sujet>/<lang>.wiki` :
   - vocabulaire agronomique précis et usuel dans la langue cible (ex. « couvert végétal » → *cover crop*, « méteil » → *cereal-legume mixture* / *intercrop*) ; en cas de doute sur un terme technique, garde le terme d'origine entre parenthèses ;
   - conserve chiffres, unités et références ; adapte seulement le format des nombres (virgule/point décimal) ;
   - noms propres (fermes, organismes, programmes) non traduits.

5. **Rapport à l'utilisateur** : liens sans équivalent, images manquantes, termes incertains.

6. **Validation et publication** sur le wiki cible selon `conventions` (l'utilisateur doit être connecté à ce wiki : `mediawiki login https://<cible>.tripleperformance.ag`).

7. **Relie les deux versions** par des liens interlangues réciproques, placés en fin de page :
   - dans la traduction, avant publication : `[[<langue source>:<Titre source>]]` (ex. `[[fr:Soil Tillage Intensity Rating (STIR)]]`) ;
   - sur la page source, après publication de la traduction : ajoute `[[<cible>:<Titre traduit>]]` en fin de page, s'il n'y est pas déjà. C'est une modification de la page source : relis-la juste avant, montre le diff et publie après accord, avec un résumé du type « Ajout du lien interlangue vers la version anglaise ».
   - Vérifie le résultat avec `search.py --langlinks` sur les deux wikis.

   Exemple existant : `Soil Tillage Intensity Rating (STIR)` (fr) porte `[[en:STIR]]`, et `STIR` (en) porte `[[fr:STIR]]`, qui est une redirection vers la page française. Les liens vers une redirection fonctionnent, mais vise de préférence le titre réel.

## À préciser

- Glossaire des termes agronomiques validés par langue : à créer dans `references/glossaire-<lang>.md` au fil des traductions.
