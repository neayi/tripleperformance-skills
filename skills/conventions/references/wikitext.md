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
[[Fichier:Nom de l'image.jpg|vignette|droite|300px|Légende de l'image]]
```

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

## Graphiques ECharts

```
{{#echarts:
  title=Titre du graphique
| width=100%
| height=400px
| option = { ... JSON d'options ECharts ... }
}}
```

Détails dans la skill `graphique-depuis-image`.

## Modèles utiles

- `{{Page en cours de rédaction}}` : signale une page incomplète.
- `{{Clear}}` : force le retour sous les éléments flottants (images, graphiques).
