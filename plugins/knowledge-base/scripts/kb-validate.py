#!/usr/bin/env python3
"""Validate KB health.

Checks every .md entry under kb/ (skipping index.md and README.md) for:
  - YAML frontmatter present and parseable
  - Required fields: title, description, category, last_updated
  - category value is listed in .kb-config.yaml (supports nested paths like 'security/access')
  - last_updated parses as YYYY-MM-DD
  - related: paths resolve to existing files
  - optional: staleness (--max-age N warns when last_updated is older than N days)

Nested categories: if frontmatter reads `category: security/access`, the entry
must live under `kb/security/access/`. Top-level folders without a nested match
still warn as before.

Exits 1 if any error is found. Warnings (including staleness) do not fail the run.

Usage:
    python3 scripts/kb-validate.py                  # default kb/
    python3 scripts/kb-validate.py [kb_path]
    python3 scripts/kb-validate.py --max-age 90     # warn on entries older than 90 days
"""

import re
import sys
from datetime import date, datetime, timedelta
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


def parse_max_age(argv: list[str]) -> int | None:
    for i, a in enumerate(argv):
        if a == "--max-age" and i + 1 < len(argv):
            try:
                n = int(argv[i + 1])
                if n > 0:
                    return n
            except ValueError:
                print(f"Error: --max-age expects a positive integer, got {argv[i + 1]!r}", file=sys.stderr)
                sys.exit(2)
        if a.startswith("--max-age="):
            try:
                n = int(a.split("=", 1)[1])
                if n > 0:
                    return n
            except ValueError:
                print(f"Error: --max-age expects a positive integer", file=sys.stderr)
                sys.exit(2)
    return None


def main():
    argv = sys.argv[1:]
    max_age_days = parse_max_age(argv)

    positional = []
    skip_next = False
    for a in argv:
        if skip_next:
            skip_next = False
            continue
        if a == "--max-age":
            skip_next = True
            continue
        if a.startswith("--"):
            continue
        positional.append(a)

    kb_path = find_kb_path(positional)

    config_categories = parse_config_categories(kb_path)
    errors: list[str] = []
    warnings: list[str] = []
    checked = 0
    stale_cutoff = date.today() - timedelta(days=max_age_days) if max_age_days else None

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

        folder_path = str(rel.parent).replace("\\", "/") if rel.parent != Path(".") else ""
        if folder_path and category and folder_path != category:
            warnings.append(
                f"{rel}: folder '{folder_path}' does not match frontmatter category '{category}'"
            )

        today = date.today().isoformat()
        if last_updated and last_updated > today:
            warnings.append(f"{rel}: last_updated '{last_updated}' is in the future")

        if stale_cutoff and last_updated and DATE_RE.match(last_updated):
            try:
                parsed = datetime.strptime(last_updated, "%Y-%m-%d").date()
                if parsed < stale_cutoff:
                    age_days = (date.today() - parsed).days
                    warnings.append(
                        f"{rel}: stale — last_updated '{last_updated}' is {age_days} days old (--max-age {max_age_days})"
                    )
            except ValueError:
                pass

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
