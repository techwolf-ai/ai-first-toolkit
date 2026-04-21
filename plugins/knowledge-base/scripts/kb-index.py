#!/usr/bin/env python3
"""List all KB files with their descriptions, grouped by category.

Usage:
    python3 scripts/kb-index.py              # print to stdout
    python3 scripts/kb-index.py --write      # also rewrite kb/index.md in place
    python3 scripts/kb-index.py [kb_path]    # point at a different kb/ directory

Supports nested categories: an entry at kb/security/access/mfa.md is grouped
under category "security/access" if its frontmatter category matches, or
under the folder path otherwise. Nested groups render as an indented tree.

With --write, the "All Files by Category" section of kb/index.md is regenerated
between the markers:

    <!-- kb-index:start -->
    ...generated content...
    <!-- kb-index:end -->

If the markers are missing, they are appended at the end of the file.
"""

import sys
from pathlib import Path


START_MARKER = "<!-- kb-index:start -->"
END_MARKER = "<!-- kb-index:end -->"


def find_kb_path(args: list[str]) -> Path:
    positional = [a for a in args if not a.startswith("--")]
    if positional:
        p = Path(positional[0])
        if p.is_dir():
            return p
        print(f"Error: {p} is not a directory", file=sys.stderr)
        sys.exit(1)
    cwd_kb = Path.cwd() / "kb"
    if cwd_kb.is_dir():
        return cwd_kb
    print("Error: no kb/ directory found in current directory.", file=sys.stderr)
    print("Usage: python3 scripts/kb-index.py [--write] [kb_path]", file=sys.stderr)
    sys.exit(1)


def extract_frontmatter(filepath: Path) -> dict:
    content = filepath.read_text(encoding="utf-8")
    if not content.startswith("---"):
        return {}
    end = content.find("---", 3)
    if end == -1:
        return {}
    result = {}
    for line in content[3:end].strip().split("\n"):
        if ":" in line:
            key, _, value = line.partition(":")
            key = key.strip()
            value = value.strip().strip('"').strip("'")
            if key in ("title", "description", "category"):
                result[key] = value
    return result


def folder_category(rel_path: Path) -> str:
    if rel_path.parent == Path("."):
        return "root"
    return str(rel_path.parent).replace("\\", "/")


def collect_entries(kb_path: Path) -> list[dict]:
    files = []
    for md_file in sorted(kb_path.rglob("*.md")):
        if md_file.name in ("index.md", "README.md"):
            continue
        rel_path = md_file.relative_to(kb_path)
        meta = extract_frontmatter(md_file)
        category = meta.get("category") or folder_category(rel_path)
        files.append({
            "path": str(rel_path).replace("\\", "/"),
            "category": category,
            "title": meta.get("title", md_file.stem),
            "description": meta.get("description", "No description"),
        })
    return files


def group_by_category(files: list[dict]) -> dict[str, list[dict]]:
    by_category: dict[str, list[dict]] = {}
    for f in files:
        by_category.setdefault(f["category"], []).append(f)
    for cat in by_category:
        by_category[cat].sort(key=lambda x: x["path"])
    return by_category


def format_stdout(by_category: dict) -> str:
    lines = []
    for category in sorted(by_category):
        depth = category.count("/")
        pad = "  " * depth
        lines.append(f"\n{pad}## {category}/")
        for f in by_category[category]:
            lines.append(f"{pad}  {f['path']}")
            lines.append(f"{pad}    {f['description']}")
    return "\n".join(lines).lstrip("\n")


def format_markdown(by_category: dict) -> str:
    lines = [START_MARKER, "", "## All Files by Category", ""]
    for category in sorted(by_category):
        depth = category.count("/")
        header_level = "###" + ("#" * min(depth, 3))
        lines.append(f"{header_level} {category}/")
        for f in by_category[category]:
            lines.append(f"- `{f['path']}` — {f['description']}")
        lines.append("")
    lines.append(END_MARKER)
    return "\n".join(lines)


def write_index(kb_path: Path, rendered: str) -> Path:
    index_path = kb_path / "index.md"
    if not index_path.exists():
        index_path.write_text(rendered + "\n", encoding="utf-8")
        return index_path
    existing = index_path.read_text(encoding="utf-8")
    if START_MARKER in existing and END_MARKER in existing:
        before = existing.split(START_MARKER)[0].rstrip() + "\n\n"
        after = existing.split(END_MARKER, 1)[1].lstrip("\n")
        new = before + rendered + ("\n\n" + after if after else "\n")
    else:
        new = existing.rstrip() + "\n\n" + rendered + "\n"
    index_path.write_text(new, encoding="utf-8")
    return index_path


def main():
    args = sys.argv[1:]
    write = "--write" in args

    kb_path = find_kb_path(args)
    files = collect_entries(kb_path)

    if not files:
        print("No KB entries found. Add .md files with YAML frontmatter to kb/.")
        return

    by_category = group_by_category(files)
    print(format_stdout(by_category))

    if write:
        rendered = format_markdown(by_category)
        index_path = write_index(kb_path, rendered)
        print()
        print(f"Wrote index to {index_path}")


if __name__ == "__main__":
    main()
