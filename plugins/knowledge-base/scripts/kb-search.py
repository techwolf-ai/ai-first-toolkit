#!/usr/bin/env python3
"""Search the knowledge base by keyword.

Ranks entries by where the keyword hits:
  - title          (weight 5)
  - tags           (weight 4)
  - description    (weight 3)
  - category/path  (weight 2)
  - body           (weight 1, capped)

Usage:
    python3 scripts/kb-search.py "keyword"
    python3 scripts/kb-search.py "keyword" --category security
    python3 scripts/kb-search.py "keyword" --tag mfa
    python3 scripts/kb-search.py "keyword" --limit 5
    python3 scripts/kb-search.py "keyword" kb/         # custom kb path
    python3 scripts/kb-search.py "keyword" --json      # machine-readable output
"""

import argparse
import json
import re
import sys
from pathlib import Path


WEIGHTS = {"title": 5, "tags": 4, "description": 3, "path": 2, "body": 1}
BODY_HIT_CAP = 5
SNIPPET_CHARS = 140


def find_kb_path(explicit: str | None) -> Path:
    if explicit:
        p = Path(explicit)
        if p.is_dir():
            return p
        print(f"Error: {p} is not a directory", file=sys.stderr)
        sys.exit(1)
    cwd_kb = Path.cwd() / "kb"
    if cwd_kb.is_dir():
        return cwd_kb
    print("Error: no kb/ directory found. Pass a path or cd into the project.", file=sys.stderr)
    sys.exit(1)


def parse_frontmatter(text: str) -> tuple[dict, list[str], str]:
    """Return (fields, tags, body)."""
    if not text.startswith("---"):
        return {}, [], text
    end = text.find("---", 3)
    if end == -1:
        return {}, [], text
    block = text[3:end].strip()
    body = text[end + 3:].lstrip("\n")

    fields: dict = {}
    tags: list[str] = []
    for line in block.split("\n"):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if ":" not in stripped:
            continue
        key, _, value = stripped.partition(":")
        key = key.strip()
        value = value.strip()
        if key == "tags":
            if value.startswith("[") and value.endswith("]"):
                tags = [t.strip().strip('"').strip("'") for t in value[1:-1].split(",") if t.strip()]
        elif key in ("title", "description", "category", "last_updated"):
            fields[key] = value.strip('"').strip("'")
    return fields, tags, body


def score_entry(query_terms: list[str], fields: dict, tags: list[str], path: str, body: str) -> tuple[int, dict]:
    score = 0
    hits: dict[str, list[str]] = {"title": [], "tags": [], "description": [], "path": [], "body": []}

    title = fields.get("title", "").lower()
    description = fields.get("description", "").lower()
    category = fields.get("category", "").lower()
    path_l = path.lower()
    body_l = body.lower()
    tags_l = [t.lower() for t in tags]

    for term in query_terms:
        t = term.lower()
        if t in title:
            score += WEIGHTS["title"]
            hits["title"].append(term)
        if any(t in tag for tag in tags_l):
            score += WEIGHTS["tags"]
            hits["tags"].append(term)
        if t in description:
            score += WEIGHTS["description"]
            hits["description"].append(term)
        if t in category or t in path_l:
            score += WEIGHTS["path"]
            hits["path"].append(term)
        body_count = min(body_l.count(t), BODY_HIT_CAP)
        if body_count:
            score += WEIGHTS["body"] * body_count
            hits["body"].append(term)

    return score, hits


def snippet_for(body: str, query_terms: list[str]) -> str:
    lower = body.lower()
    for term in query_terms:
        idx = lower.find(term.lower())
        if idx == -1:
            continue
        start = max(0, idx - SNIPPET_CHARS // 2)
        end = min(len(body), idx + SNIPPET_CHARS // 2)
        snippet = body[start:end].strip()
        snippet = re.sub(r"\s+", " ", snippet)
        prefix = "..." if start > 0 else ""
        suffix = "..." if end < len(body) else ""
        return f"{prefix}{snippet}{suffix}"
    return ""


def collect(kb_path: Path) -> list[dict]:
    entries = []
    for md in sorted(kb_path.rglob("*.md")):
        if md.name in ("index.md", "README.md"):
            continue
        rel = md.relative_to(kb_path)
        text = md.read_text(encoding="utf-8")
        fields, tags, body = parse_frontmatter(text)
        entries.append({
            "path": str(rel),
            "title": fields.get("title", md.stem),
            "description": fields.get("description", ""),
            "category": fields.get("category", str(rel.parent) if rel.parent != Path(".") else "root"),
            "tags": tags,
            "body": body,
        })
    return entries


def main():
    parser = argparse.ArgumentParser(description="Search the knowledge base by keyword.")
    parser.add_argument("query", help="Keyword(s) to search for; space-separated terms are ANDed for ranking")
    parser.add_argument("kb_path", nargs="?", default=None, help="Path to kb/ directory (defaults to ./kb)")
    parser.add_argument("--category", help="Restrict to this category (matches exact or nested, e.g. 'security' matches 'security/access')")
    parser.add_argument("--tag", action="append", default=[], help="Restrict to entries tagged with this tag (repeatable)")
    parser.add_argument("--limit", type=int, default=10, help="Max results (default 10)")
    parser.add_argument("--json", action="store_true", help="Output JSON instead of formatted text")
    args = parser.parse_args()

    kb_path = find_kb_path(args.kb_path)
    query_terms = [t for t in args.query.split() if t]
    if not query_terms:
        print("Error: empty query", file=sys.stderr)
        sys.exit(1)

    entries = collect(kb_path)

    if args.category:
        cat = args.category.lower().rstrip("/")
        entries = [e for e in entries if e["category"].lower() == cat or e["category"].lower().startswith(cat + "/")]
    if args.tag:
        wanted = {t.lower() for t in args.tag}
        entries = [e for e in entries if wanted.issubset({t.lower() for t in e["tags"]})]

    scored = []
    for e in entries:
        score, hits = score_entry(query_terms, {"title": e["title"], "description": e["description"], "category": e["category"]}, e["tags"], e["path"], e["body"])
        if score > 0:
            scored.append({**e, "score": score, "hits": hits, "snippet": snippet_for(e["body"], query_terms)})

    scored.sort(key=lambda x: (-x["score"], x["path"]))
    scored = scored[: args.limit]

    if args.json:
        out = [{k: v for k, v in s.items() if k != "body"} for s in scored]
        print(json.dumps(out, indent=2))
        return

    if not scored:
        print(f"No results for: {args.query}")
        if args.category or args.tag:
            print("(filters active; drop --category / --tag to widen)")
        return

    print(f"Found {len(scored)} result(s) for: {args.query}\n")
    for i, e in enumerate(scored, 1):
        hit_fields = [f for f, terms in e["hits"].items() if terms]
        print(f"[{i}] {e['title']}  ({e['score']} pts, matched: {', '.join(hit_fields)})")
        print(f"    kb/{e['path']}  [{e['category']}]")
        if e["description"]:
            print(f"    {e['description']}")
        if e["snippet"]:
            print(f"    > {e['snippet']}")
        print()


if __name__ == "__main__":
    main()
