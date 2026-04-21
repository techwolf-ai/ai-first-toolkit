# Knowledge Base

## Directory Structure

- `kb/`: Knowledge base entries (git-tracked). Categories can be nested — e.g., `kb/security/access/mfa.md` with `category: security/access` in frontmatter.
- `kb/scopes/`: Context profiles for different audiences or customer segments
- `scripts/kb-index.py`: Lists all KB files with descriptions; `--write` regenerates `kb/index.md` (renders nested categories as a tree)
- `scripts/kb-verify.py`: Verifies that `/kb-answer` citations exist in KB files
- `scripts/kb-validate.py`: Checks KB health (frontmatter, categories incl. nested, related links)
- `scripts/kb-search.py`: Keyword search; `python3 scripts/kb-search.py "keyword" [--category X] [--tag Y]`

## KB Entry Format

All entries use markdown with YAML frontmatter:

```yaml
---
title: "Entry Title"
description: "One-liner for index lookup"
category: {{category}}
tags: [tag1, tag2]
sources: ["source-document.pdf"]
last_updated: "YYYY-MM-DD"
related:
  - category/related-entry.md
---
```

## Adding Knowledge

1. Create a `.md` file in the appropriate `kb/{category}/` folder
2. Add YAML frontmatter with at least title, description, category, and last_updated
3. Write content with clear, quotable statements
4. Run `python3 scripts/kb-index.py` to verify it appears in the index

## Scopes

Use scope files in `kb/scopes/` to customize answers for specific contexts. See `kb/scopes/README.md` for details.

## Querying

Use `/kb-answer` to ask questions. Answers will cite literal quotes from KB files.
