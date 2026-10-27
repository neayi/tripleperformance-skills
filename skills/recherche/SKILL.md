---
name: recherche
description: Recherche des articles existants sur Triple Performance (tripleperformance.fr et versions dans d'autres langues) — par mots-clés, par début de titre, par catégorie ou par modèle utilisé. À utiliser quand l'utilisateur demande si un article existe déjà, cherche des pages sur un sujet agricole, veut éviter un doublon avant de créer une page, ou cherche des pages à lier.
---

# Rechercher sur Triple Performance

Applique les règles de la skill `conventions`.

## Outil

Le script `scripts/search.py` de cette skill (chemin relatif au dossier de la skill) interroge l'API MediaWiki :

```bash
python3 <dossier-de-la-skill>/scripts/search.py "couverts végétaux"             # plein texte
python3 <dossier-de-la-skill>/scripts/search.py "luzerne" --titles              # début de titre
python3 <dossier-de-la-skill>/scripts/search.py --category "Pratiques"          # membres d'une catégorie
python3 <dossier-de-la-skill>/scripts/search.py --template "Pratique"           # articles utilisant un modèle
python3 <dossier-de-la-skill>/scripts/search.py "cover crops" --lang en         # autre langue
python3 <dossier-de-la-skill>/scripts/search.py --exists "Charrue" "Houe rotative" "Fraise rotative"
python3 <dossier-de-la-skill>/scripts/search.py --langlinks "Soil Tillage Intensity Rating (STIR)"
```

Options : `--limit N` (défaut 10), `--namespace 0|14` (articles et catégories), `--json`.

- `--exists` vérifie en une seule requête l'existence d'une liste de titres (par lots de 50) et indique les redirections (`OK  Décompacteur → Sous-soleuse (redirection)`). À utiliser pour valider **tous** les liens internes d'un texte avant publication : un lien vers une page absente apparaît en rouge sur le wiki.
- `--langlinks` liste les liens interlangues (`[[en:...]]`) d'une ou plusieurs pages, c'est-à-dire leurs équivalents dans les autres langues.

## Déroulé

1. **Reformule la demande en plusieurs requêtes.** Le moteur de recherche est littéral : cherche le terme exact, ses synonymes et variantes agricoles (ex. « semis direct », « semis sans labour », « SD sous couvert », « agriculture de conservation »), au singulier et au pluriel.
2. **Lance les recherches** (plein texte, puis `--titles` pour les titres proches). Si le sujet relève d'un type de page (pratique, culture, bioagresseur, matériel…), liste aussi les articles du modèle correspondant avec `--template`.
3. **Ouvre les pages les plus pertinentes** avec `mediawiki read <url>` (ou seulement le début, `| head -60`) pour vérifier leur contenu réel : un titre proche ne garantit pas le même sujet.
4. **Restitue** à l'utilisateur :
   - les pages qui traitent déjà du sujet (titre, URL, une phrase sur leur contenu) ;
   - les pages voisines utiles pour des liens internes ;
   - une conclusion claire : le sujet est-il déjà couvert, partiellement couvert, ou absent ?
5. Si l'utilisateur veut ensuite créer ou compléter une page, enchaîne avec la skill `nouvel-article` ou `article-depuis-pdf`.

## Notes

- Le plein texte cherche aussi dans les paramètres des modèles : un résultat peut ne mentionner le terme que dans une liste de mots-clés.
- Les wikis des différentes langues sont indépendants : une recherche en français ne trouve pas les pages anglaises.
