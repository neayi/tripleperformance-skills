# Choisir le titre d'une page

Le titre dépend du type de page, donc du modèle utilisé. Dans tous les cas : majuscule au premier mot seulement (et aux noms propres, sigles), pas de caractères interdits (`# < > [ ] | { }`), et vérification que le titre est libre avec `search.py --exists` (skill `recherche`).

Les pages existantes ne respectent pas toujours ces règles (beaucoup de retours d'expérience commencent par un verbe) : applique les règles ci-dessous plutôt que d'imiter l'existant.

| Type de page | Modèle(s) | Forme du titre | Exemples |
|---|---|---|---|
| Retour d'expérience | `Exemple de mise en œuvre` | Nom d'action (nominalisation), spécifique | « Mise en place d'une serre en aquaponie de 1600 m² dans le Gers » |
| Portrait de ferme | `Portrait de ferme` | Nom de la ferme | « EARL Besnard », « GAEC BioTaupes » |
| Fiche technique | `Pratique` | Verbe à l'infinitif | « Mettre en place un distributeur automatique à la ferme », « Autoconstruire un semoir à dent » |
| Concept | `Culture`, `Arbre`, `Bioagresseur`, `Auxiliaire`, `Accident climatique et physiologique`, `Matériel`, `Outil d'aide`, `Intrant`, `Label`, `Fonction service stratégie`, `MFSC` | Nom le plus précis, au singulier, sans article | « Blé », « Bruche du pois », « Méthode MERCI » |
| Livre | `Livre` | Titre du livre, puis année de parution entre parenthèses | « Le pâturage tournant dynamique (2020) » |
| Vidéo | `Vidéo` | Voir la skill `video-youtube` | — |

## Retour d'expérience

- Transforme le verbe en nom : « Mise en place… » plutôt que « Mettre en place… », « Plantation de carottes… » plutôt que « Planter des carottes… ».
- Le titre doit refléter ce que ce retour d'expérience a d'original : taille, technique, lieu, contexte. « Mise en place d'une serre en aquaponie de 1600 m² dans le Gers » plutôt que « Mise en place d'une serre de fraises ».

## Portrait de ferme

- Le nom de la ferme tel qu'elle le porte, forme juridique comprise s'il en fait partie (« EARL Besnard », « GAEC BioTaupes »).
- À défaut de nom, « Ferme de <Prénom Nom> » comme sur les pages existantes, après accord de l'utilisateur.

## Fiche technique

- Commence par un verbe à l'infinitif qui dit ce que fait l'agriculteur : « Autoconstruire un semoir à dent ».
- Précise le contexte s'il est nécessaire pour comprendre (« … en vigne », « … en verger »).

## Concepts (cultures, ravageurs, auxiliaires, matériels, OAD, intrants, labels…)

- Le nom le plus précis du concept, au singulier, sans article : « Bruche du pois » plutôt que « Les ravageurs du pois ».
- En cas d'homonymie possible, ajoute le type de concept entre parenthèses : « Artaban (cépage) », « Couverts végétaux (OAD) ». Vérifie avec `search.py --exists` et une recherche sur le nom seul si l'homonyme existe déjà.

## Livre

- Le titre exact du livre, sans sous-titre s'il est long, suivi de l'année de parution entre parenthèses : « Le pâturage tournant dynamique (2020) ».
- Si l'année n'est pas connue, demande-la à l'utilisateur plutôt que de l'omettre.

## Autres modèles

Pour un modèle absent de cette page (`Projet étudiant`…), reprends la forme des titres existants du même modèle et propose d'ajouter la règle ici.
