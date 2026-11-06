# Wikitext sur Triple Performance

Aide-mémoire des éléments de mise en page utilisés sur le wiki. À enrichir au fil des découvertes.

## Titres et paragraphes

```
== Titre de section ==
=== Sous-section ===

Paragraphe. Une ligne vide sépare deux paragraphes.
'''gras''', ''italique''
```

## Listes

```
* puce
** sous-puce
# liste numérotée
```

## Liens

Les liens internes vers les articles ne s'écrivent pas à la main : LinkTitles les ajoute après publication (voir `conventions`, règles de publication). La syntaxe ci-dessous sert pour les liens structurels ou demandés par l'utilisateur.

```
[[Couverts végétaux]]                       lien interne
[[Couverts végétaux|couverts]]              lien interne avec texte
[[:Catégorie:Luzerne|Luzerne]]              lien vers une catégorie (sans l'y classer)
[https://exemple.org Texte du lien]         lien externe
```

## Images

```
[[File:Nom de l'image.jpg|thumbnail|Légende]]                     à droite, habillée par le texte
[[File:Nom de l'image.jpg|center|thumbnail|400px|Légende]]       centrée, avec cadre et légende
[[File:Nom de l'image.jpg|center|noframe|400px]]                 centrée, sans cadre ni légende
```

Galeries, choix de l'image d'illustration du modèle et préparation des fichiers : voir la skill `images`.

## Références

```
Une affirmation<ref>Auteur, ''Titre'', éditeur, année. [https://... lien]</ref>.

== Références ==
<references />
```

## Tableaux

```
{| class="wikitable"
|+ Légende du tableau
! En-tête 1 !! En-tête 2
|-
| cellule || cellule
|-
| colspan="2" | cellule fusionnée
|}
```

### Classes de mise en forme

Après `wikitable`, on peut ajouter dans `class="..."` des classes qui rendent le tableau plus lisible :

| Classe | Effet |
|---|---|
| `table` | aligne le contenu des cellules en haut |
| `table-striped` | alterne la couleur des lignes |
| `table-sm` | réduit les marges intérieures des cellules |
| `table-responsive` | ajoute une barre de défilement horizontale sur mobile |
| `small` | réduit la taille du texte |
| `sortable` | permet de trier en cliquant sur les en-têtes |

Par défaut, utilise seulement `class="wikitable table-responsive"`. Ajoute les autres classes selon le besoin du tableau :

- `table` quand des cellules ont des textes de longueurs très différentes (contenu aligné en haut plutôt qu'au milieu) ;
- `table-striped` pour un tableau de nombreuses lignes, où l'œil doit suivre une ligne ;
- `table-sm` et `small` pour un tableau dense (beaucoup de colonnes ou de chiffres) ;
- `sortable` quand trier les lignes a du sens.

Exemple combinant plusieurs classes :

```
{| class="wikitable table table-striped table-sm table-responsive small"
```

## Graphiques

```
{{Graphique Triple Performance| title=Assolement 2022 | type = Assolement | width=100% | height=400px | json = Ma page/Assolement 2022.json }}
```

Les données sont dans la sous-page JSON (modèle de contenu `json`) : options ECharts ou rotation TIKA. Les pages anciennes contiennent aussi des appels `{{#echarts: ... | option = {...} }}` en ligne. Détails dans la skill `graphiques`.

## Modèles utiles

- `{{Page en cours de rédaction}}` : signale une page incomplète.
- `{{Clear}}` : force le retour sous les éléments flottants (images, graphiques).
