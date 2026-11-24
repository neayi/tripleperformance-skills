---
name: traduction
description: Traduit une page de Triple Performance d'une version linguistique du wiki vers une autre (par exemple de wiki.tripleperformance.fr vers en.tripleperformance.ag), ou vers toutes les langues, en gardant intacts modèles, paramètres, fichiers et sous-pages JSON, puis relie toutes les versions par des liens interlangues. À utiliser quand l'utilisateur veut traduire, porter ou publier une page dans une autre langue, retraduire ou mettre à jour une traduction, ou réparer les liens interlangues entre les versions d'une page.
---

# Traduire une page entre deux wikis

Applique les règles de la skill `conventions`. Ce qui ne se traduit pas (modèles, paramètres protégés, fichiers, sous-pages JSON, liens) est détaillé dans [references/parametres-proteges.md](references/parametres-proteges.md) : lis-la avant de traduire.

Langues des wikis : `ar de el en es fi fr hu it nl pl pt`. « Toutes les langues » veut dire toutes sauf la langue source.

## Déroulé

### 1. Identifier la source et la cible

Langue source, langue(s) cible(s), URL de la page source. Lis la source :

```bash
mediawiki read "https://wiki.tripleperformance.fr/wiki/<Titre>" > tp-travail/<sujet>/source.wiki
```

Si le titre est une redirection, travaille sur la page réelle.

### 2. Décider s'il faut traduire

Fais le point sur les versions existantes :

```bash
python3 ${CLAUDE_SKILL_DIR}/scripts/interlangues.py "<URL de la page source>"
```

Le script suit les liens interlangues de proche en proche sur tous les wikis (redirections comprises) et affiche chaque version existante. Puis, pour chaque langue cible :

1. **La source a déjà un lien vers la langue cible** : la page est déjà traduite. Arrête-toi pour cette langue, sauf si l'utilisateur demande une retraduction ou une mise à jour. Dans ce cas, **garde exactement le titre cible existant** (ne le retraduis pas, sinon tu crées un doublon), lis la page cible et prépare un `diff -u`.
2. **Pas de lien, mais la page existe déjà sur le wiki cible** sous le titre traduit ou une variante. Cherche-la avec `python3 ${CLAUDE_PLUGIN_ROOT}/skills/recherche/scripts/search.py --exists "<Titre traduit>" --lang <cible>`, puis avec `search.py "<mots du titre>" --lang <cible>`. Ne traduis pas : propose seulement de relier les pages (étape 8). Si son contenu est très en retard sur la source, signale-le et demande s'il faut la mettre à jour.
3. **Aucune version** : traduis (étapes 3 à 8).

Le script signale aussi les liens vers des pages absentes et les **conflits** (deux pages différentes pour une même langue). Montre-les à l'utilisateur et demande laquelle garder avant toute modification.

### 3. Inventorier ce qui ne se traduit pas mot à mot

- **Modèle de page et paramètres** : noms de modèles et de paramètres inchangés (en français sur tous les wikis), valeurs traduites sauf les paramètres protégés (`Image`, `Icone`, `Logo`, `Bannière`, `query`, `class`… liste complète dans la référence). Vérifie sur un article du wiki cible qui utilise le même modèle (`python3 ${CLAUDE_PLUGIN_ROOT}/skills/recherche/scripts/search.py --template <Nom> --lang <cible>` puis `mediawiki read`).
- **Valeurs sémantiques** (type de production, objectif…) : reprends les valeurs déjà employées sur le wiki cible.
- **Liens internes** : ne les transpose pas. Remplace chaque `[[Page]]` ou `[[Page|texte]]` par son texte traduit, sans lien, en gardant les espaces autour. LinkTitles posera les liens du wiki cible après publication (voir `conventions`). Seuls les liens structurels sont adaptés à la main : images, catégories, interlangues.
- **Espaces de noms**, y compris dans le corps du texte : `Catégorie:` → `Category:`, `Fichier:` → `File:`, etc. Les catégories visées doivent exister sur le wiki cible.
- **Fichiers** : noms inchangés, légendes traduites. Vérifie qu'ils sont disponibles sur le wiki cible ; sinon, liste-les pour téléversement (avec accord).
- **Sous-pages JSON** : repère chaque paramètre `json=`, quel que soit le modèle. Note le chemin source et choisis le chemin cible `<Titre traduit>/<Nom traduit>.json` (traitement à l'étape 5).
- **Liens interlangues de la source** : ne les recopie pas tels quels ; le bon bloc est calculé à l'étape 7.

### 4. Traduire

Dans `tp-travail/<sujet>/<lang>.wiki` :

- **Titre** : traduis-le selon les règles de titre du type de page (`conventions`, `references/titres.md`) : infinitif pour une fiche technique, nom d'action pour un retour d'expérience, nom au singulier pour un concept. Les noms de ferme et les titres de livres publiés ne se traduisent pas, sauf s'il existe une édition dans la langue cible. Un `:` dans le titre n'est un espace de noms que si le préfixe en est un vrai. Propose le titre à l'utilisateur.
- **Vocabulaire** agronomique précis et usuel dans la langue cible (« couvert végétal » → *cover crop*, « méteil » → *cereal-legume mixture* / *intercrop*). En cas de doute sur un terme technique, garde le terme d'origine entre parenthèses.
- **Chiffres, unités et références** : conservés ; adapte seulement le format des nombres (virgule ou point décimal).
- **Noms propres** (fermes, organismes, programmes) : non traduits.
- **Paragraphe introductif** (avant le premier titre) : il doit rester informatif dans ses 300 premiers caractères une fois traduit. Si la source n'en a pas, rédige-le et signale-le.
- **Page longue** : traduis section par section, sans en sauter ni en fusionner, et sans rien ajouter qui ne soit dans la source.
- Laisse la valeur `json=` d'origine pour l'instant ; elle est remplacée à l'étape 5.

### 5. Traduire les sous-pages JSON

Pour chaque `json=` relevé :

```bash
mediawiki read "<base source>/wiki/<Page>/<Nom>.json" > tp-travail/<sujet>/<nom>.source.json
# … traduction des seules valeurs texte dans tp-travail/<sujet>/<nom>.<lang>.json
python3 ${CLAUDE_SKILL_DIR}/scripts/verifier.py --json tp-travail/<sujet>/<nom>.source.json tp-travail/<sujet>/<nom>.<lang>.json
python3 ${CLAUDE_PLUGIN_ROOT}/skills/graphiques/scripts/graphique.py verifie tp-travail/<sujet>/<nom>.<lang>.json
```

Ne traduis que les valeurs texte : pas les clés, nombres, dates, couleurs ni `id` (détails dans la référence). Puis remplace, dans `<lang>.wiki`, la valeur `json=` par le chemin cible exact. Pour un `{{#echarts:}}` en ligne, traduis les textes du JSON sans toucher à la structure.

### 6. Vérifier la traduction

```bash
python3 ${CLAUDE_SKILL_DIR}/scripts/verifier.py tp-travail/<sujet>/source.wiki tp-travail/<sujet>/<lang>.wiki --lang <lang> --source-lang <source>
```

Le script compare la source et la traduction. Il vérifie que les modèles, les noms de paramètres et les valeurs protégées sont identiques, que les fichiers, références, tableaux, galeries et titres de section sont tous là, et que `{{ }}` et `[[ ]]` sont équilibrés. Il repère aussi les sous-pages JSON, les liens `[[:xx:…]]`, les espaces de noms restés en français, les liens internes restants, les espaces collés aux liens, et une longueur suspecte (texte oublié ou inventé). Il faut zéro erreur (code de sortie 1 sinon). Corrige les avertissements, ou explique à l'utilisateur pourquoi tu les laisses. Puis lance l'aperçu de `conventions` (`preview.py --lang <lang>`).

### 7. Rapport, validation et publication

Avant de publier, ajoute en fin de page le bloc interlangue complet. Pour une page pas encore publiée, le script le donne :

```bash
python3 ${CLAUDE_SKILL_DIR}/scripts/interlangues.py "<URL de la page source>" --ajoute <lang>:"<Titre traduit>"
```

Le bloc contient le lien vers la source **et** vers toutes les autres versions existantes (`[[de:…]]`, `[[es:…]]`…), jamais vers sa propre langue, toujours sous la forme `[[xx:Titre]]` (sans `:` initial).

Signale ensuite à l'utilisateur les images manquantes, les termes incertains, l'introduction rédigée et les sous-pages JSON à créer. Publie selon `conventions` : sous-pages JSON d'abord (`mediawiki write --content-model=json`), puis la page, puis LinkTitles. L'utilisateur doit être connecté au wiki cible : `mediawiki login https://<cible>.tripleperformance.ag`.

### 8. Relier toutes les versions

Une fois la traduction publiée (ou pour une page existante simplement à relier, cas 2 de l'étape 2), chaque version du groupe doit porter les liens vers toutes les autres :

```bash
python3 ${CLAUDE_SKILL_DIR}/scripts/interlangues.py "<URL de la page source>" --ajoute <lang>:"<Titre traduit>" --sortie tp-travail/<sujet>/interlangues
```

Pour chaque page à corriger (source, mais aussi les versions dans d'autres langues), le script écrit `<lang>.avant.wiki` et `<lang>.apres.wiki`. Il remplace un lien existant vers la même langue au lieu d'en ajouter un second, et retire les liens vers des pages absentes. Les titres visés sont les titres réels, pas les redirections. Montre les `diff -u` proposés et attends l'accord, puis publie chaque page avec un résumé du type « Ajout du lien interlangue vers la version anglaise » :

```bash
mediawiki write "<base de la langue>/wiki/<Titre>" tp-travail/<sujet>/interlangues/<lang>.apres.wiki --summary "..."
```

Ces pages n'ont pas de texte nouveau : ne relance pas LinkTitles. Le script ne fait que lire ; relance-le juste avant d'écrire si du temps a passé, puis une dernière fois à la fin : il doit afficher « Tous les liens interlangues sont à jour ».

Exemple existant : `Soil Tillage Intensity Rating (STIR)` (fr) porte `[[en:STIR]]`, et `STIR` (en) porte `[[fr:STIR]]`, qui est une redirection vers la page française. Le script propose de viser le titre réel.

## Traduire vers plusieurs langues

Traduis une langue après l'autre (étapes 2 à 7), chacune dans son fichier `tp-travail/<sujet>/<lang>.wiki`, en partant toujours de la source et non d'une autre traduction. Fais valider le titre de chaque langue. Fais ensuite l'étape 8 une seule fois pour tout le groupe, en passant un `--ajoute` par langue publiée : une seule modification par page au lieu d'une par langue.

## Tester sur le wiki de développement

Pour essayer sans toucher à la production, utilise les wikis `https://<lang>.dev.tripleperformance.ag` (français : `fr.dev.tripleperformance.ag`), aux certificats auto-signés, s'ils sont accessibles depuis ton poste (demande à l'utilisateur). `interlangues.py --dev` interroge ces wikis. N'écris jamais en production pour un test (voir `conventions`).

## À préciser

- Glossaire des termes agronomiques validés par langue : à créer dans `references/glossaire-<lang>.md` au fil des traductions.
