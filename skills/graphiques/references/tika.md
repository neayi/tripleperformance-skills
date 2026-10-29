# Rotations et itinéraires techniques (format TIKA)

Moteur de rendu : `RotationRenderer` de [osfarm/itineraire-technique](https://github.com/osfarm/itineraire-technique) (paquet npm `@osfarm/itineraire-technique`), embarqué dans l'extension ECharts du wiki (`modules/ext.tika/chart-render.js`). Démonstration : <https://osfarm.github.io/itineraire-technique/visualisateur.html>. Exemple de référence : [`test/test.json`](https://github.com/osfarm/itineraire-technique/blob/main/test/test.json).

L'extension reconnaît ce format à l'**absence** de clé `series` à la racine. Le lecteur peut basculer entre frise et donut, afficher ou masquer la liste des étapes, et cliquer sur une étape ou une intervention pour voir son détail.

## Schéma

```json
{
  "title": "Rotation type de la ferme",
  "options": {
    "view": "horizontal",
    "show_transcript": true,
    "title_top_interventions": "Contrôle adventices",
    "title_steps": "Rotation",
    "title_bottom_interventions": "Autres interventions",
    "show_climate_diagram": false,
    "climate_data": {
      "temperatures": [4.5, 4.7, 7.5, 10.5, 14.6, 19, 21.5, 21.4, 17.6, 13.9, 8.9, 5.5],
      "precipitations": [73, 67, 70, 96, 82, 63, 39, 44, 91, 128, 143, 86]
    }
  },
  "address": { "raw": "Rouen, France", "town": "Rouen", "region": "Normandie",
               "department": "Seine-Maritime", "country": "France",
               "gpsLocation": { "lat": 49.44, "lng": 1.09 } },
  "steps": [
    {
      "id": "643172d1-dc20-4289-b346-3c68daa3ace0",
      "name": "Orge + Lupin",
      "color": "#d2b48c",
      "startDate": "2026-03-01T00:00:00.000Z",
      "endDate": "2026-07-20T00:00:00.000Z",
      "secondary_crop": false,
      "description": "Densité : lupin 350 kg/ha + orge 50 kg/ha\nRendement orge : 14,25 q/ha\n\nPas de désherbage en dehors du labour.",
      "interventions": [
        { "id": "a19ccf22-4478-44f0-b81b-da6df534875f", "day": -5, "name": "Labour",
          "type": "intervention_top", "description": "" },
        { "id": "d500f562-5e3f-4713-95fd-97a5d4800e77", "day": 141, "name": "Fauche, andainage puis récolte",
          "type": "intervention_bottom", "description": "Pailles laissées au sol." }
      ]
    }
  ]
}
```

### Racine

| Clé | Rôle |
|---|---|
| `title` | Titre affiché au-dessus du graphique. |
| `options` | Réglages d'affichage (ci-dessous). Peut être absent : vue `horizontal` par défaut. |
| `address` | Lieu (rempli par l'éditeur via géocodage). Facultatif, sans effet sur le rendu. Les anciens fichiers ont `region`, `address`, `latitude`, `longitude` dans `options` : ne pas les déplacer sans raison. |
| `steps` | Étapes, dans l'ordre chronologique. |

Les clés inconnues (`soilType`, `displayedColumns`, `values`, `specifications`… produites par d'autres outils) sont ignorées par le rendu : conserve-les quand tu modifies un fichier existant.

### `options`

| Clé | Valeurs |
|---|---|
| `view` | `"horizontal"` : frise chronologique (défaut). `"donut"` : anneaux (étapes, mois, années). Les anciens fichiers portent `"vertical"`, qui s'affiche en donut. |
| `show_transcript` | `true` : liste textuelle des étapes et interventions à côté (ou sous) le graphique. Recommandé pour les itinéraires détaillés. |
| `title_top_interventions` | Libellé de la bande d'interventions au-dessus de la frise (souvent « Contrôle adventices » ou « Cultures principales »). |
| `title_steps` | Libellé de la bande des étapes (« Rotation », « Étapes de la rotation dans la parcelle »). |
| `title_bottom_interventions` | Libellé de la bande du dessous (« Autres interventions », « Fertilisation », « Couverts »). |
| `show_climate_diagram` | `true` : superpose températures et précipitations mensuelles à la frise. |
| `climate_data` | `temperatures` et `precipitations` : **12 valeurs** chacune (janvier → décembre), °C et mm. |

### Étapes (`steps[]`)

| Clé | Rôle |
|---|---|
| `name` | Culture ou couvert : « Blé tendre », « Couvert : avoine + vesce + phacélie ». Court : c'est le libellé dans la frise. |
| `startDate`, `endDate` | Dates ISO (`2025-10-10` ou `2025-10-10T00:00:00.000Z`). `endDate` > `startDate`, sinon l'étape est ramenée à 30 jours. Les années sont fictives pour une rotation type : commence à l'année en cours et enchaîne. |
| `color` | `#rrggbb`. Reprends les couleurs habituelles (tableau ci-dessous) pour rester cohérent entre pages. |
| `description` | Texte libre, retours à la ligne `\n`. Une ligne `Libellé : valeur` est rendue avec le libellé en gras : écris `Variété : Chevignon`, `Densité : 164 kg/ha`, `Rendement : 75 q/ha`, `Précédent : colza`. Pas de wikitext ni de Markdown. |
| `secondary_crop` | `true` pour une culture superposée à l'étape principale (couvert semé sous la culture, plante compagne, culture associée) : dessinée en bandeau fin sous l'étape principale. Les étapes principales ne doivent pas se chevaucher ; une étape secondaire peut chevaucher. |
| `interventions` | Liste des interventions (ci-dessous), éventuellement vide. |
| `id` | UUID. Généré par l'éditeur ; facultatif pour le rendu. Pour un nouveau fichier, génère-les (`python3 -c "import uuid; print(uuid.uuid4())"`) ; pour un fichier existant, ne les change pas. |
| `duration` | Calculée par le rendu (en mois) : inutile de la renseigner. |
| `useDefaultColor`, `useDefaultStartDate`, `useDefaultEndDate` | Drapeaux de l'éditeur. Mets `false` dans un fichier écrit à la main. |
| `attributes` | **Obsolète** : liste `{name, value}` que le rendu ajoute à la fin de `description`. Dans un nouveau fichier, écris ces lignes directement dans `description`. |

Un intervalle entre deux étapes principales apparaît vide (blanc dans le donut) : c'est voulu pour une jachère nue ou un sol nu, sinon raccorde les dates.

### Interventions (`steps[].interventions[]`)

| Clé | Rôle |
|---|---|
| `day` | Nombre de jours **depuis le `startDate` de l'étape** (entier, peut être négatif : un labour 5 jours avant le semis = `-5`). Calcule-le à partir de la date réelle : `(date intervention − startDate)` en jours. |
| `name` | Libellé court affiché dans la frise : « Désherbage », « Semis direct - Primera », « Azote 50 U ». |
| `type` | `"intervention_top"` (bande du haut) ou `"intervention_bottom"` (bande du bas). Toute autre valeur est rangée en bas. Le sens de chaque bande est donné par `title_top_interventions` / `title_bottom_interventions` : choisis une répartition et tiens-la dans tout le fichier. |
| `description` | Détail (produits et doses, matériel, conditions), `\n` pour les retours à la ligne. Une intervention par passage : pas de liste d'interventions dans une seule. |
| `id` | UUID, comme pour les étapes. |

## Rotation type ou itinéraire d'une culture

- **Rotation type** (plusieurs années) : une étape par culture et par couvert d'interculture, interventions limitées aux opérations structurantes (travail du sol, semis, destruction du couvert, récolte). `view` : `horizontal` ou `donut` selon la préférence de l'utilisateur (le donut montre bien le retour cyclique).
- **Itinéraire technique** d'une culture ou d'une parcelle : une étape principale (la culture) et éventuellement l'interculture qui précède, toutes les interventions datées avec produits et doses, `show_transcript: true`, vue `horizontal`.
- Une page peut porter plusieurs graphiques TIKA (une rotation, puis l'itinéraire de chaque culture), chacun dans sa sous-page.

## Couleurs habituelles

Relevées sur les rotations existantes ; à compléter.

| Culture ou étape | Couleur |
|---|---|
| Blé tendre, céréales d'hiver | `#f5c842`, `#ffe599` |
| Blé dur | `#fff2cc` |
| Colza | `#ffd966` |
| Orge, mélange céréales-protéagineux | `#d2b48c` |
| Luzerne, prairie, trèfle | `#2d9f6e`, `#afd095` |
| Couvert d'interculture | `#7ec850`, `#d9ead3` |
| Betterave | `#ff96b0` |
| Jachère | `#efefef` |

## Éditeur visuel

Chaque graphique TIKA du wiki porte, pour un contributeur connecté, un lien « modifier le graphique » vers l'éditeur : `https://wiki.tripleperformance.fr/extensions/ECharts/editor/editor.html?wiki=<titre de la sous-page encodé>`. Il enregistre directement dans la sous-page (modèle `json`). Propose-le à l'utilisateur pour les retouches de mise en page (glisser des étapes, ajuster des dates) ; réserve le JSON écrit par la skill à la création et aux modifications en masse.
