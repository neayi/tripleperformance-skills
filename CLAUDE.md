# CLAUDE.md

Ce dépôt contient des skills Claude Code, distribuées sous forme de plugin, pour aider les contributeurs de Triple Performance (wiki MediaWiki sur l'agroécologie) à rédiger des articles. Le contenu (skills, docs, messages de commit) est rédigé en français.

## Organisation

```
.claude-plugin/plugin.json       Manifeste du plugin (nom, version)
.claude-plugin/marketplace.json  Permet `/plugin marketplace add neayi/tripleperformance-skills`
skills/<nom>/SKILL.md            Une skill par dossier ; le nom du dossier = champ `name`
skills/<nom>/scripts/            Scripts d'assistance propres à la skill
skills/<nom>/references/         Documentation chargée à la demande par la skill
skills/conventions/              Socle partagé : URLs, CLI mediawiki, règles de sécurité
scripts/install.sh, install.ps1  Installation des outils (Linux/macOS/WSL, Windows)
scripts/validate_skills.py       Vérification de la structure des skills (lancée en CI)
```

## Commandes

```bash
python3 scripts/validate_skills.py   # valide toutes les skills (frontmatter, liens, taille)
shellcheck scripts/install.sh         # lint du script d'installation
claude --plugin-dir .                 # lance Claude Code avec le plugin de ce dossier
./scripts/install.sh --check          # vérifie que les outils sont présents
```

## Règles pour écrire ou modifier une skill

- Le frontmatter de `SKILL.md` contient `name` (kebab-case, identique au nom du dossier) et `description`. La description dit **ce que fait la skill et quand l'utiliser**, avec les formulations qu'un contributeur emploierait ; c'est elle qui déclenche la skill.
- `SKILL.md` reste sous 500 lignes. Les détails (syntaxe ECharts, liste des modèles…) vont dans `references/` et sont liés depuis `SKILL.md` par un lien relatif.
- Les connaissances communes à plusieurs skills vont dans `skills/conventions/`, pas en copie dans chaque skill. Les autres skills y renvoient.
- Les scripts d'assistance sont en Python 3, bibliothèque standard uniquement, ou en bash portable. Seule exception documentée : `openpyxl` (installé par les scripts d'installation) pour les fichiers Excel. Ils doivent fonctionner sous Linux, macOS et Windows (Git Bash) : pas de chemins codés en dur, pas de dépendance `pip`.
- Toute skill qui écrit sur le wiki doit : écrire le wikitext dans un fichier local, montrer le résultat (ou un `diff -u` pour une page existante) et attendre l'accord explicite de l'utilisateur avant `mediawiki write` / `upload` / `rename` / `delete`.
- Quand une convention du wiki est découverte (nom de modèle, champ obligatoire, catégorie), consignez-la dans la référence adéquate pour que la skill s'améliore.
- Après une modification, relancez `python3 scripts/validate_skills.py`, et ajoutez une ligne dans `CHANGELOG.md` sous « Non publié ».

## Faits utiles sur le wiki

- Wiki français : `https://wiki.tripleperformance.fr` (`tripleperformance.fr` redirige). API : `https://wiki.tripleperformance.fr/api.php`.
- Autres langues : `https://<code>.tripleperformance.ag` (en, de, es, it, nl, pl, pt, ar, el, fi, hu…).
- MediaWiki 1.43 avec Semantic MediaWiki, Page Forms, ECharts (`{{#echarts: ...}}`), Scribunto, ParserFunctions, Cite.
- Les modèles d'articles sont dans `Catégorie:Modèles de catégories` ; le formulaire Page Forms associé (`Formulaire:<Nom>`, parfois une redirection) donne la liste des champs.
- La CLI `mediawiki` n'a pas de commande de recherche : la recherche passe par l'API (`skills/recherche/scripts/search.py`).
- Les versions linguistiques d'une page sont reliées par des liens interlangues réciproques en fin de page (`[[en:Titre]]`), lisibles via l'API `prop=langlinks` (`search.py --langlinks`).

## Ne pas faire

- Ne jamais lancer de commande d'écriture sur le wiki de production pour tester une skill : utiliser `mediawiki read` et des fichiers locaux, ou demander à l'utilisateur.
- Ne pas committer de fichiers de travail (`tp-travail/`), de PDF ou d'images de test volumineux.
