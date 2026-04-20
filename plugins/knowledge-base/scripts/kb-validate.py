#!/usr/bin/env python3
"""Validate KB health.

Checks every .md entry under kb/ (skipping index.md and README.md) for:
  - YAML frontmatter present and parseable
  - Required fields: title, description, category, last_updated
  - category value is listed in .kb-config.yaml
  - last_updated parses as YYYY-MM-DD
  - related: paths resolve to existing files

Exits 1 if any error is found. Warnings do not fail the run.

Usage:
    python3 scripts/kb-validate.py          # default kb/
    python3 scripts/kb-validate.py [kb_path]
"""

import re
import sys
from datetime import date
from pathlib import Path


REQUIRED_FIELDS = ("title", "description", "category", "last_updated")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def find_kb_path(args: list[str]) -> Path:
    if args:
        p = Path(args[0])
        if p.is_dir():
            return p
        print(f"Error: {p} is not a directory", file=sys.stderr)
        sys.exit(1)
    cwd_kb = Path.cwd() / "kb"
    if cwd_kb.is_dir():
        return cwd_kb
    print("Error: no kb/ directory found.", file=sys.stderr)
    sys.exit(1)


def parse_config_categories(kb_path: Path) -> list[str]:
    config = kb_path / ".kb-config.yaml"
    if not config.exists():
        return []
    categories = []
    in_list = False
    for line in config.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if stripped.startswith("categories:"):
            in_list = True
            continue
        if in_list:
            if stripped.startswith("- "):
                categories.append(stripped[2:].strip().strip('"').strip("'"))
            elif stripped and not line.startswith(" "):
                break
    return categories


def parse_frontmatter(filepath: Path) -> tuple[dict, list[str]]:
    """Return (fields, related_paths)."""
    content = filepath.read_text(encoding="utf-8")
    if not content.startswith("---"):
        return {}, []
    end = content.find("---", 3)
    if end == -1:
        return {}, []
    block = content[3:end].strip()

    fields = {}
    related = []
    in_related = False
    for line in block.split("\n"):
        stripped = line.strip()
        if in_related:
            if stripped.startswith("- "):
                related.append(stripped[2:].strip().strip('"').strip("'"))
                continue
            if line and not line.startswith(" "):
                in_related = False
            else:
                continue
        if stripped.startswith("related:"):
            in_related = True
            continue
        if ":" in stripped and not stripped.startswith("-"):
            key, _, value = stripped.partition(":")
            key = key.strip()
            value = value.strip().strip('"').strip("'")
            if value:
                fields[key] = value
    return fields, related


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    kb_path = find_kb_path(args)

    config_categories = parse_config_categories(kb_path)
    errors: list[str] = []
    warnings: list[str] = []
    checked = 0

    for md_file in sorted(kb_path.rglob("*.md")):
        if md_file.name in ("index.md", "README.md"):
            continue
        checked += 1
        rel = md_file.relative_to(kb_path)
        fields, related = parse_frontmatter(md_file)

        if not fields:
            errors.append(f"{rel}: missing or unparseable YAML frontmatter")
            continue

        for required in REQUIRED_FIELDS:
            if required not in fields:
                errors.append(f"{rel}: missing required frontmatter field '{required}'")

        last_updated = fields.get("last_updated", "")
        if last_updated and not DATE_RE.match(last_updated):
            errors.append(f"{rel}: last_updated '{last_updated}' is not YYYY-MM-DD")

        category = fields.get("category", "")
        if category and config_categories and category not in config_categories:
            errors.append(
                f"{rel}: category '{category}' not in .kb-config.yaml "
                f"(allowed: {', '.join(config_categories)})"
            )

        folder_category = rel.parts[0] if len(rel.parts) > 1 else None
        if folder_category and category and folder_category != category:
            warnings.append(
                f"{rel}: folder '{folder_category}' does not match frontmatter category '{category}'"
            )

        today = date.today().isoformat()
        if last_updated and last_updated > today:
            warnings.append(f"{rel}: last_updated '{last_updated}' is in the future")

        for r in related:
            target = kb_path / r
            if not target.exists():
                errors.append(f"{rel}: related link '{r}' does not resolve")

    print(f"Checked {checked} entries under {kb_path}")
    if warnings:
        print(f"\nWarnings ({len(warnings)}):")
        for w in warnings:
            print(f"  - {w}")
    if errors:
        print(f"\nErrors ({len(errors)}):")
        for e in errors:
            print(f"  - {e}")
        sys.exit(1)
    print("\nAll entries valid.")


if __name__ == "__main__":
    main()
