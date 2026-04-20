# Knowledge Base Plugin

Build and query a structured, evidence-backed knowledge base with Claude Code.

## Why

LLMs hallucinate. When answering questions about your product, company, or domain, you need answers grounded in documented facts, not general knowledge. This plugin creates a knowledge base where every answer must cite literal quotes from your KB files.

## Skills

| Skill | What it does |
|-------|-------------|
| `/setup-knowledge-base` | Interactive onboarding: define categories, scaffold the KB structure, create the index |
| `/kb-answer` | Answer questions with evidence-backed citations from your KB |
| `/kb-import` | Import knowledge from existing documents (Markdown, PDF, plain text) into structured KB entries |
| `/kb-refresh` | Add new sources (Notion, Slack, Confluence, local files) or re-scrape existing ones to pick up changes |

## Getting Started

1. Install the plugin via Claude Code marketplace or `./install.sh knowledge-base`
2. Run `/setup-knowledge-base` in your project
3. Add entries to `kb/` or import existing docs with `/kb-import`
4. Query with `/kb-answer What encryption do we use?`

## How It Works

### KB Entries

Markdown files with YAML frontmatter, organized by category:

```markdown
---
title: "Data Encryption"
description: "AES-256 at rest, TLS 1.2+ in transit"
category: security
tags: [encryption, aes, tls]
last_updated: "2026-04-10"
---

All data is encrypted at rest using AES-256-GCM.
Data in transit is protected with TLS 1.2 or higher.
```

### Evidence-Grounded Answers

When you ask `/kb-answer`, the skill:
1. Navigates the KB index to find relevant files
2. Reads the files and extracts supporting evidence
3. Formulates an answer citing literal quotes
4. Flags when information is missing from the KB

### Scopes

Optional context profiles that customize answers. For example, a "enterprise-customer" scope can emphasize security certifications while excluding self-serve pricing.

## Directory Structure

```
kb/
  .kb-config.yaml       # Category definitions
  index.md              # Central navigation index
  scopes/               # Context profiles
    _default.yaml
  security/             # Category directories
    data-encryption.md
    certifications.md
  technical/
    product-overview.md
  ...
scripts/
  kb-index.py           # Lists all KB files; --write regenerates index.md
  kb-verify.py          # Verifies answer citations (strict + normalized-match fallback)
  kb-validate.py        # Checks frontmatter, categories, and related-link resolution
```

## License

[MIT](../../LICENSE)
