---
name: graphiques
description: Crée, modifie ou corrige les graphiques des pages Triple Performance — histogrammes, assolements, radars, diagrammes ombrothermiques, camemberts, courbes, mais aussi rotations et itinéraires techniques (format TIKA, affichés en frise ou en donut avec leurs interventions). Le graphique est stocké en sous-page JSON (« Ma page/Mon graphique.json ») et appelé par le modèle Graphique Triple Performance. À utiliser quand l'utilisateur veut ajouter un graphique à un article, représenter une rotation, un assolement ou un itinéraire technique, mettre à jour les données d'un graphique existant, ajouter une intervention ou une culture à une rotation, ou comprendre pourquoi un graphique ne s'affiche pas.
---

# Graphiques Triple Performance

Applique les règles de la skill `conventions`. Pour reproduire un graphique à partir d'une image, commence par la skill `graphique-depuis-image` (lecture des valeurs), puis reviens ici pour le stockage et la publication.

## Principe

Un graphique est fait de deux pages :

1. **Une sous-page JSON**, de modèle de contenu `json`, sous la page qui l'affiche : `Ferme de Longueil/Assolement 2022 Chedru.json`.
2. **Un appel du modèle** dans l'article :

   ```
   {{Graphique Triple Performance| title=Assolement 2022 Chedru | type = Assolement | width=100% | height=400px | json = Ferme de Longueil/Assolement 2022 Chedru.json }}
   ```

Le modèle transmet à la parser function `{{#echarts:}}` de l'extension [mw-echarts](https://github.com/neayi/mw-echarts). Dans le navigateur, l'extension charge la sous-page (`?action=raw`), puis :

- si le JSON a une clé `series` à la racine → ce sont des **options ECharts**, rendues telles quelles ;
- sinon → c'est une **rotation ou un itinéraire technique au format TIKA** ([osfarm/itineraire-technique](https://github.com/osfarm/itineraire-technique)), rendu en frise ou en donut, avec la liste des étapes et des interventions.

Détails de chaque format : [references/echarts.md](references/echarts.md) (gabarits par type de graphique) et [references/tika.md](references/tika.md) (schéma des rotations et itinéraires).

### Paramètres du modèle `Graphique Triple Performance`

| Paramètre | Rôle |
|---|---|
| `title` | Titre du graphique (pour l'appel ; le titre affiché vient du JSON) |
| `type` | **Obligatoire.** `Assolement`, `Rotation`, `Bar chart par année`, `Radar`, `Ombrothermique` (aussi `Bar charts`). Classe la page dans `Catégorie:Pages avec un graph de type <type>` ; avec `Rotation`, pose en plus la propriété sémantique `A un JSON de système` (utilisée pour retrouver toutes les rotations du wiki). Utilise `Rotation` pour tout JSON TIKA, itinéraire d'une seule culture compris. |
| `width` | `100%` (défaut) ou `500px`… |
| `height` | `400px` par défaut. Ignorée pour TIKA, qui calcule sa hauteur. |
| `align` | `center` (défaut), `left` ou `right` : le texte coule à côté ; place `{{Clear}}` après le paragraphe voisin. |
| `json` | Titre complet de la sous-page JSON, sans lien ni underscores. |

### Nom de la sous-page

- `<Titre exact de la page>/<Nom explicite>.json` : `Rotation type`, `Assolement 2024`, `Itinéraire technique du pois`, `Marge brute par culture`.
- **Pas de `/`** dans le nom du graphique : il créerait une sous-sous-page (`Ferme de Longueil/Marge brute / ha.json` existe, c'est à éviter).
- Les sous-pages ne suivent pas un renommage de l'article : sur une page ancienne, le JSON peut être rangé sous l'ancien titre ou sous un autre article. Lis toujours le paramètre `json` de l'appel plutôt que de deviner.

## Déroulé

### 1. Faire l'état des lieux

Pour une page existante, liste ses graphiques et vérifie leurs sous-pages :

```bash
python3 <dossier-de-cette-skill>/scripts/graphique.py liste "Ferme de Longueil" [--lang en]
```

Le script indique pour chaque graphique le modèle ou la parser function utilisés, la sous-page JSON et son état (`json`, `absente`, ou un modèle de contenu inattendu). Un graphique dont la sous-page est absente n'apparaît pas pour les lecteurs (l'extension propose seulement aux contributeurs connectés de le créer).

### 2. Choisir la représentation

| Ce que l'utilisateur veut montrer | Graphique | `type` du modèle |
|---|---|---|
| Succession de cultures sur plusieurs années, avec couverts et interventions | Rotation TIKA, vue `horizontal` (frise) ou `donut` | `Rotation` |
| Itinéraire technique d'une culture (travail du sol, semis, désherbage, fertilisation, récolte) | TIKA, vue `horizontal` | `Rotation` |
| Répartition de la SAU à une date | Treemap ECharts (formateur `assolement`) | `Assolement` |
| Valeurs par année ou par modalité (rendements, marges, charges) | Barres ECharts | `Bar chart par année` |
| Performances sur plusieurs axes, comparaison à un groupe | Radar ECharts | `Radar` |
| Températures et précipitations mensuelles | Ombrothermique ECharts | `Ombrothermique` |
| Parts d'un tout (débouchés, décomposition des ventes) | Camembert / anneau ECharts | `Bar charts` faute de mieux, ou `{{#pie_chart:}}` (voir référence) |

Propose le choix à l'utilisateur quand plusieurs représentations conviennent. Une rotation qui comporte des interventions datées va en TIKA, pas en camembert.

### 3. Rassembler les données

- Pars des documents de l'utilisateur (tableur, PDF, notes, compte rendu d'entretien). Un fichier Excel se lit avec `openpyxl` (voir `conventions`).
- Pour une rotation ou un itinéraire : liste des étapes (culture ou couvert, dates de début et de fin, couleur), puis pour chaque étape les interventions (date, nom, catégorie haut/bas, détail : produit, dose, matériel). Fais valider ce tableau **avant** de produire le JSON : les erreurs de date se voient mieux ainsi.
- Ne complète pas une donnée manquante par une valeur plausible : demande-la, ou laisse le champ vide et signale-le.

### 4. Écrire le JSON

Dans `tp-travail/<sujet>/<nom>.json`, en partant du gabarit de la référence adéquate. Le JSON d'une sous-page est du **JSON strict** :

- pas de fonctions JavaScript (`formatter: function…`) : utilise les gabarits de chaînes d'ECharts (`"{b} : {c} ha"`) ou les formateurs nommés de l'extension (`"assolement"`, `"rotation"`) ;
- pas de commentaires ni de virgule finale ;
- textes dans la langue du wiki cible, unités dans les libellés.

Pour modifier un graphique existant, récupère d'abord la sous-page :

```bash
mediawiki read "https://wiki.tripleperformance.fr/wiki/Ferme_de_Longueil/Rotation_type_Chedru.json" > tp-travail/<sujet>/rotation.avant.json
```

et travaille sur une copie. Conserve les `id` existants des étapes et interventions TIKA (l'éditeur en ligne s'en sert).

### 5. Vérifier et prévisualiser

```bash
python3 <dossier-de-cette-skill>/scripts/graphique.py verifie tp-travail/<sujet>/rotation.json
python3 <dossier-de-cette-skill>/scripts/graphique.py apercu tp-travail/<sujet>/rotation.json -o tp-travail/<sujet>/apercu.html
```

- `verifie` détecte le format comme le fait l'extension, signale le JSON invalide et, pour TIKA, les dates illisibles ou inversées, les chevauchements d'étapes principales, les interventions mal typées, les données climatiques incomplètes, les rotations de plus de 20 ans (non affichées). Corrige les erreurs ; explique les avertissements que tu laisses.
- `apercu` produit une page HTML autonome qui charge ECharts et le moteur de rendu TIKA depuis un CDN, avec les mêmes formateurs que le wiki. Donne le chemin à l'utilisateur pour qu'il l'ouvre dans son navigateur.

### 6. Montrer et faire valider

- Graphique nouveau : montre un résumé lisible (étapes et interventions, ou séries et valeurs), le chemin du JSON et de l'aperçu, le titre de la sous-page et la ligne d'appel du modèle.
- Graphique existant : montre `diff -u rotation.avant.json rotation.json` (formate d'abord les deux fichiers avec `jq .` pour un diff lisible).
- Si l'appel du modèle doit être ajouté ou modifié dans l'article, prépare aussi le wikitext de l'article et son diff, et passe-le par `preview.py` de `conventions`.

Attends un accord explicite avant toute écriture.

### 7. Publier

La sous-page JSON se publie avec le modèle de contenu `json` (sans lui, elle serait enregistrée comme wikitext et le graphique ne s'afficherait pas) :

```bash
mediawiki write --content-model=json "https://wiki.tripleperformance.fr/wiki/<Page>/<Nom>.json" tp-travail/<sujet>/<nom>.json --summary "Rotation type de la ferme, d'après l'entretien de 2025"
```

Puis, si besoin, l'article avec l'appel du modèle (règles de publication de `conventions`, LinkTitles compris). Ensuite :

- vérifie le modèle de contenu : `python3 <dossier-de-cette-skill>/scripts/graphique.py liste "<Page>"` doit afficher `[json]` ;
- si l'article affiche encore l'ancienne version, le cache est en cause : purge la page (`mediawiki api "<base>/api.php?action=purge&titles=<Page>"`) ;
- donne l'URL de l'article, et pour une rotation TIKA le lien de l'éditeur visuel, où l'utilisateur peut retoucher le graphique à la souris : `https://wiki.tripleperformance.fr/extensions/ECharts/editor/editor.html?wiki=<Titre de la sous-page encodé>`.

## Cas particuliers

- **Bilan économique** (`{{#economic_charts:}}`), **camembert simple** (`{{#pie_chart:}}`), modèles `EChart Radar MSV`, `EChart Capacité d'autoproduction MSV`, `EChart Stratégie commerciale MSV`, `Fleur de l'Agroécologie` : graphiques à paramètres, sans JSON. Voir [references/echarts.md](references/echarts.md#graphiques-à-paramètres).
- **Traduction** : le modèle porte le même nom (`Graphique Triple Performance`) sur tous les wikis, mais la sous-page JSON est propre à chaque wiki. Pour traduire un article, crée la sous-page sur le wiki cible sous le titre traduit et traduis les textes (noms d'étapes et d'interventions, descriptions, `title_*`, légendes, axes) sans toucher aux dates, valeurs, couleurs ni `id`.

## Améliorer cette skill

Consigne dans les références les gabarits validés par l'utilisateur, les palettes de couleurs habituelles et les pièges rencontrés (format inattendu, graphique qui ne s'affiche pas).
