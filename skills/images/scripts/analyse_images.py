#!/usr/bin/env python3
"""Analyse des images avant téléversement sur Triple Performance.

Pour chaque image : format, dimensions, poids, orientation, transparence,
nombre de couleurs, et une suggestion de traitement (photo → JPEG 1000 px de
large ; schéma, tableau, logo → PNG sans redimensionnement). La suggestion
n'est qu'un indice : regarde l'image pour trancher.

Usage : analyse_images.py image1.png image2.jpg ... [--json]
"""

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

PHOTO_WIDTH = 1000
# Au-delà de ce nombre de couleurs, une image ressemble plutôt à une photo
PHOTO_COLORS = 20000


def identify_tool():
    magick = shutil.which("magick")
    if magick:
        return [magick, "identify"]
    # Sous Windows, « identify » seul n'existe qu'avec ImageMagick 6, rare
    identify = shutil.which("identify")
    if identify:
        return [identify]
    sys.exit("ImageMagick est introuvable : relancez le script d'installation du dépôt des skills.")


def analyse(tool, path):
    # [0] : première image seulement (GIF animés, TIFF multipages)
    fmt = "%m|%w|%h|%k|%A|%[opaque]"
    result = subprocess.run([*tool, "-format", fmt, f"{path}[0]"], capture_output=True, text=True)
    if result.returncode != 0:
        return {"fichier": str(path), "erreur": result.stderr.strip()}
    kind, width, height, colors, alpha, opaque = result.stdout.strip().split("|")
    width, height, colors = int(width), int(height), int(colors)
    # Une couche alpha entièrement opaque ne compte pas comme transparence
    has_alpha = alpha.lower() not in ("undefined", "false", "") and opaque.lower() != "true"

    if width > height * 1.1:
        orientation = "horizontale"
    elif height > width * 1.1:
        orientation = "verticale"
    else:
        orientation = "carrée"

    looks_like_photo = colors >= PHOTO_COLORS and not has_alpha
    if looks_like_photo:
        target = "JPEG" if kind not in ("JPEG", "JPG") else "JPEG (déjà)"
        resize = f"réduire à {PHOTO_WIDTH} px de large" if width > PHOTO_WIDTH else "taille conservée"
        suggestion = f"photo probable : {target}, {resize}"
    elif has_alpha:
        suggestion = "transparence (logo, pictogramme) : garder en PNG, ne pas redimensionner"
    else:
        suggestion = "peu de couleurs (schéma, tableau, capture) : garder en PNG, ne pas redimensionner"

    return {
        "fichier": str(path),
        "format": kind,
        "largeur": width,
        "hauteur": height,
        "orientation": orientation,
        "poids_ko": round(path.stat().st_size / 1024),
        "couleurs": colors,
        "transparence": has_alpha,
        "suggestion": suggestion,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("images", nargs="+", type=Path)
    parser.add_argument("--json", action="store_true", help="sortie JSON")
    args = parser.parse_args()

    tool = identify_tool()
    results = [analyse(tool, p) for p in args.images]
    if args.json:
        print(json.dumps(results, ensure_ascii=False, indent=2))
        return
    for r in results:
        if "erreur" in r:
            print(f"{r['fichier']} : erreur — {r['erreur']}")
            continue
        print(f"{r['fichier']} : {r['format']} {r['largeur']}×{r['hauteur']} ({r['orientation']}), "
              f"{r['poids_ko']} Ko, {r['couleurs']} couleurs{', transparence' if r['transparence'] else ''}")
        print(f"  → {r['suggestion']}")


if __name__ == "__main__":
    main()
