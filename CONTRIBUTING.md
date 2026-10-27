# Contribuer

Merci d'aider à améliorer ces skills ! Elles sont pensées pour évoluer avec l'usage : chaque fois qu'une skill se trompe sur une convention du wiki ou fait un détour inutile, c'est une occasion de la corriger.

## Tester en local

```bash
git clone https://github.com/neayi/tripleperformance-skills.git
cd tripleperformance-skills
./scripts/install.sh --check
claude --plugin-dir .
```

`claude --plugin-dir .` charge le plugin depuis votre copie de travail : vos modifications sont prises en compte au prochain lancement, sans passer par la marketplace.

Pour tester une skill sans risque, travaillez sur des fichiers locaux et refusez l'étape de publication proposée par la skill. Si vous devez tester une écriture, faites-le sur une page de brouillon de votre espace utilisateur (`Utilisateur:VotreNom/Brouillon`).

## Améliorer une skill existante

1. Reproduisez le problème et notez ce que la skill aurait dû faire.
2. Corrigez `SKILL.md`, une référence ou un script. Préférez une règle courte et précise (« le champ `Titre court` est obligatoire pour les Pratiques ») à une longue explication.
3. Si la connaissance sert à plusieurs skills, mettez-la dans `skills/conventions/`.
4. Lancez `python3 scripts/validate_skills.py`.
5. Ajoutez une ligne dans `CHANGELOG.md` sous « Non publié ».

## Créer une nouvelle skill

1. Créez `skills/<nom-en-kebab-case>/SKILL.md` :

   ```markdown
   ---
   name: nom-en-kebab-case
   description: Ce que fait la skill, et quand l'utiliser. Citez les mots qu'un contributeur emploierait (« convertir », « tableau », « PDF »…).
   ---

   # Titre

   Avant de commencer, applique les règles de la skill `conventions`.

   ## Étapes
   1. ...
   ```

2. Mettez les scripts dans `scripts/` et la documentation longue dans `references/`, liés depuis `SKILL.md`.
3. Ajoutez la skill au tableau du `README.md`.
4. Validez, testez avec `claude --plugin-dir .`, puis ouvrez une pull request.

La skill `skill-creator` de Claude Code peut vous aider à rédiger la description et à tester le déclenchement.

## Bonnes pratiques de rédaction

- **La description est le déclencheur.** Claude ne lit le corps de la skill qu'après l'avoir choisie sur sa description : elle doit être précise et contenir les mots-clés réels.
- **Des étapes, pas un essai.** Numérotez le déroulé, indiquez les commandes exactes et les points où il faut demander l'avis de l'utilisateur.
- **Divulgation progressive.** `SKILL.md` contient l'essentiel ; les détails sont dans `references/` et ne sont chargés que si nécessaire.
- **Scripts déterministes.** Ce qui peut être fait par un script (appel API, conversion) doit l'être, plutôt que d'être réécrit à chaque fois par Claude.
- **Validation humaine avant publication.** Aucune skill ne publie sans accord explicite.

## Publier une version

1. Mettez à jour `version` dans `.claude-plugin/plugin.json` (versionnage sémantique).
2. Transformez la section « Non publié » du `CHANGELOG.md` en numéro de version daté.
3. Committez, taguez (`git tag v0.2.0`) et poussez. Les utilisateurs récupèrent la mise à jour avec `/plugin marketplace update triple-performance`.
