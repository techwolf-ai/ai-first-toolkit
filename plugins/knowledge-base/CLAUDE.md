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

- `scripts/kb-index.py`: lists all KB files with descriptions; with `--write` regenerates `kb/index.md`'s "All Files by Category" section in place
- `scripts/kb-verify.py`: verifies that answer citations exist in KB files; normalized-match fallback tolerates markdown/whitespace drift, `--strict` disables it
- `scripts/kb-validate.py`: checks KB health (frontmatter, categories, dates, related-link resolution)
- `templates/`: starter files copied into user projects during setup

## Runtime Data

All KB content lives in the user's project (not in this plugin directory).
