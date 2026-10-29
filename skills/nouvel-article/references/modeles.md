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
| Portrait de ferme | `Formulaire:Portrait de ferme` | mêmes paramètres que ci-dessus, plus `Sous-titre`, `Bannière`, `Logo`, `URL` ; `Organisme` = titre d'une page de l'espace `Structure:` (n° 3000), sans préfixe, sinon lien rouge (ex. `Chambre régionale d'agriculture des Pays de la Loire`, `Chambre d'agriculture Pays de la Loire - Vendée`) : liste via `list=allpages&apnamespace=3000` ; `pH` attend `Sol acide`, `Sol peu acide`, `Sol neutre` ou `Sol basique` ; `Nom de l'agriculteur` crée un lien vers `Utilisateur:<Nom>` |
| Culture | `Formulaire:Culture et production` | `Nom latin` plutôt que `Latin` |
| Bioagresseur | `Formulaire:Bioagresseur` | paramètre `type` en minuscule (Adventices, Ravageurs…) |
| Matériel | `Formulaire:Matériel et équipement` | `Type de matériel` absent du formulaire mais attendu |
| Livre | `Formulaire:Livre` | `Auteurs` séparés par `@` ; le PDF va dans `PDF` |
| Vidéo | `Formulaire:Vidéo` | voir la skill `video-youtube` ; `Programme` et `Résumé` absents du formulaire |
| ITK | — | itinéraire technique d'une culture dans une ferme ; `Culture` obligatoire (sinon erreur sémantique), titres exacts des pages de culture au singulier (`Tomate`, pas `Tomates`) ; sans `Image`, la photo de la page de culture n'est reprise que s'il n'y a **qu'une** culture : avec plusieurs, renseigne `Image` ; `Production` est sans effet actuellement (renseigne-le quand même, comme les pages existantes) ; `Ferme` = titre exact de la page de la ferme, à omettre pour un ITK de cahier des charges ; `Rendement` avec unité (`4,5 kg/m²`, `t/ha`, `q/ha`) ; listes séparées par `,` ; `Organisme = MSV Normandie` ajoute le bandeau MSV. Pour la frise des interventions, ajouter un graphique TIKA (skill `graphiques`) |
| Label | — | `Objectif`, `Type de production` séparés par `@` |
| Outil d'aide, Intrant, Auxiliaire, MFSC, Accident climatique et physiologique, Facteur environnemental, Arbre, Cépage, Grande thématique, Fonction service stratégie | — | `Nom` souvent ignoré (le titre de la page est utilisé) |
| Contributeur | — | sur les pages `Utilisateur:` |
| Présentation | — | sur les pages `Fichier:` des PDF |
| Formation | — | inutilisé ; `Mots clés` sans trait d'union |
| Expérimentation | `Formulaire:Expérimentation` (ajoute aussi le modèle `Terrain d'expérimentation`) | hors `Catégorie:Modèles de catégories` |
| Event | `Formulaire:Événement` | hors `Catégorie:Modèles de catégories` |

Règles communes : `Mots-clés` et `Programme` séparés par des virgules ; `Glyph` plutôt que `Icone` ; `Tag 0`, `Tag 1`… sont obsolètes (utiliser `Mots-clés`).
