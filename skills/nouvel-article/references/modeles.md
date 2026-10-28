# Modèles de pages

Chaque modèle de `Catégorie:Modèles de catégories` est documenté par un bloc TemplateData : paramètres, description, statut (obligatoire, suggéré, obsolète).

```bash
curl -s "https://wiki.tripleperformance.fr/api.php?action=templatedata&format=json&formatversion=2&lang=fr&titles=Modèle:<Nom>"
```

Le formulaire Page Forms d'un modèle (`Formulaire:<Nom>`) liste ses champs dans l'ordre de saisie. Tous les formulaires ajoutent aussi le modèle `Pages liées`. Une redirection entre parenthèses mène au même formulaire.

| Modèle | Formulaire | Pièges |
|---|---|---|
| Pratique | `Formulaire:Fiche technique` | `Objectif` et `Type de production` séparés par `@` |
| Exemple de mise en œuvre | `Formulaire:Retour d'expérience` | `Cultures`, `Cahier des charges`, `Autres caractéristiques`, `Objectif` séparés par `@` ; `Type de production` par `,` ; `Latitude`/`Longitude` absents du formulaire |
| Portrait de ferme | `Formulaire:Portrait de ferme` | mêmes paramètres que ci-dessus, plus `Sous-titre`, `Bannière`, `Logo`, `URL` |
| Culture | `Formulaire:Culture et production` | `Nom latin` plutôt que `Latin` |
| Bioagresseur | `Formulaire:Bioagresseur` | paramètre `type` en minuscule (Adventices, Ravageurs…) |
| Matériel | `Formulaire:Matériel et équipement` | `Type de matériel` absent du formulaire mais attendu |
| Livre | `Formulaire:Livre` | `Auteurs` séparés par `@` ; le PDF va dans `PDF` |
| Vidéo | `Formulaire:Vidéo` | voir la skill `video-youtube` ; `Programme` et `Résumé` absents du formulaire |
| Label | — | `Objectif`, `Type de production` séparés par `@` |
| Outil d'aide, Intrant, Auxiliaire, MFSC, Accident climatique et physiologique, Facteur environnemental, Arbre, Cépage, Grande thématique, Fonction service stratégie | — | `Nom` souvent ignoré (le titre de la page est utilisé) |
| Contributeur | — | sur les pages `Utilisateur:` |
| Présentation | — | sur les pages `Fichier:` des PDF |
| Formation | — | inutilisé ; `Mots clés` sans trait d'union |
| Expérimentation | `Formulaire:Expérimentation` (ajoute aussi le modèle `Terrain d'expérimentation`) | hors `Catégorie:Modèles de catégories` |
| Event | `Formulaire:Événement` | hors `Catégorie:Modèles de catégories` |

Règles communes : `Mots-clés` et `Programme` séparés par des virgules ; `Glyph` plutôt que `Icone` ; `Tag 0`, `Tag 1`… sont obsolètes (utiliser `Mots-clés`).
