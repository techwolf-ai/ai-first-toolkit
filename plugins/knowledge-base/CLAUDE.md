# Knowledge Base Plugin

Build and query a structured, evidence-backed knowledge base.

## Skills

| Command | What it does |
|---------|-------------|
| `/setup-knowledge-base` | Interactive onboarding, run this first |
| `/kb-answer` | Evidence-backed question answering |
| `/kb-import` | Import documents into KB entries |
| `/kb-refresh` | Add new sources or re-scrape existing ones |

## Key Files

- `scripts/kb-index.py`: lists all KB files with descriptions; `--write` regenerates `kb/index.md`'s "All Files by Category" section in place; supports nested category trees
- `scripts/kb-verify.py`: verifies that answer citations exist in KB files; supports single-line and multi-line `> "..."` blocks; normalized-match fallback tolerates markdown/whitespace drift, `--strict` disables it
- `scripts/kb-validate.py`: checks KB health (frontmatter, categories incl. nested, dates, related-link resolution); `--max-age N` warns on entries older than N days
- `scripts/kb-search.py`: keyword search across title/tags/description/body with category and tag filters; `--json` for machine-readable output
- `templates/`: starter files copied into user projects during setup

## Runtime Data

All KB content lives in the user's project (not in this plugin directory).
