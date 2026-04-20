# Knowledge Base Plugin

Build and query a structured, evidence-backed knowledge base. Every answer cites literal quotes from KB files.

## Skills

- `/setup-knowledge-base`: Interactive onboarding to create your KB structure
- `/kb-answer`: Answer questions with evidence-backed citations from your KB
- `/kb-import`: Import knowledge from existing documents into KB entries
- `/kb-refresh`: Add new sources or re-scrape existing ones to pick up changes

## Key Concepts

- **KB entries**: Markdown files with YAML frontmatter (title, description, category, tags)
- **Evidence grounding**: Answers must cite literal quotes from KB files
- **Scopes**: Optional context profiles that customize which KB content is relevant
- **Index**: Central navigation file for fast KB lookup

## Getting Started

Run `/setup-knowledge-base` to create your KB structure. The setup will ask what your KB is for, define categories, and scaffold the directory structure.
