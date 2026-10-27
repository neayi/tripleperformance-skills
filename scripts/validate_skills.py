#!/usr/bin/env python3
"""Valide la structure des skills du dépôt.

Vérifie pour chaque skills/<nom>/SKILL.md :
- la présence d'un frontmatter YAML avec `name` et `description` ;
- que `name` est en kebab-case et identique au nom du dossier ;
- la longueur de la description (1024 caractères max) ;
- la taille du corps (500 lignes max) ;
- que les liens relatifs pointent vers des fichiers existants.

Vérifie aussi que les manifestes du plugin sont du JSON valide.
Sortie non nulle en cas d'erreur.
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKILLS_DIR = ROOT / "skills"
NAME_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
LINK_RE = re.compile(r"\]\(([^)\s]+)\)")
MAX_DESCRIPTION = 1024
MAX_BODY_LINES = 500


def parse_frontmatter(text):
    """Retourne (champs, corps) ; champs vaut None si le frontmatter est absent."""
    if not text.startswith("---\n"):
        return None, text
    end = text.find("\n---\n", 4)
    if end == -1:
        return None, text
    fields = {}
    for line in text[4:end].splitlines():
        if ":" in line and not line.startswith((" ", "\t")):
            key, value = line.split(":", 1)
            fields[key.strip()] = value.strip().strip("\"'")
    return fields, text[end + 5:]


def validate_skill(skill_dir):
    errors = []
    skill_file = skill_dir / "SKILL.md"
    if not skill_file.is_file():
        return [f"{skill_dir.name}: SKILL.md manquant"]

    fields, body = parse_frontmatter(skill_file.read_text(encoding="utf-8"))
    if fields is None:
        return [f"{skill_dir.name}: frontmatter YAML absent ou mal fermé"]

    name = fields.get("name", "")
    if not name:
        errors.append(f"{skill_dir.name}: champ `name` manquant")
    elif not NAME_RE.match(name):
        errors.append(f"{skill_dir.name}: `name` doit être en kebab-case ({name!r})")
    elif name != skill_dir.name:
        errors.append(f"{skill_dir.name}: `name` ({name!r}) différent du nom du dossier")

    description = fields.get("description", "")
    if not description:
        errors.append(f"{skill_dir.name}: champ `description` manquant")
    elif len(description) > MAX_DESCRIPTION:
        errors.append(f"{skill_dir.name}: description trop longue ({len(description)} > {MAX_DESCRIPTION})")

    body_lines = body.count("\n")
    if body_lines > MAX_BODY_LINES:
        errors.append(f"{skill_dir.name}: SKILL.md trop long ({body_lines} lignes), déplacez des détails dans references/")

    for md_file in skill_dir.rglob("*.md"):
        for target in LINK_RE.findall(md_file.read_text(encoding="utf-8")):
            if re.match(r"^[a-z]+:", target) or target.startswith("#"):
                continue
            path = (md_file.parent / target.split("#", 1)[0]).resolve()
            if not path.exists():
                errors.append(f"{md_file.relative_to(ROOT)}: lien cassé vers {target}")

    return errors


def validate_manifests():
    errors = []
    for manifest in ("plugin.json", "marketplace.json"):
        path = ROOT / ".claude-plugin" / manifest
        try:
            json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            errors.append(f".claude-plugin/{manifest}: {exc}")
    return errors


def main():
    skill_dirs = sorted(p for p in SKILLS_DIR.iterdir() if p.is_dir())
    errors = validate_manifests()
    for skill_dir in skill_dirs:
        errors.extend(validate_skill(skill_dir))

    if errors:
        for error in errors:
            print(f"ERREUR  {error}")
        print(f"\n{len(errors)} erreur(s) sur {len(skill_dirs)} skill(s).")
        return 1
    print(f"{len(skill_dirs)} skill(s) valides.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
