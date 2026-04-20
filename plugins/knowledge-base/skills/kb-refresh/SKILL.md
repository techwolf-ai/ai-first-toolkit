---
name: kb-refresh
description: |
  Add new sources to your knowledge base or re-scrape existing ones to pick up changes.
  Supports Notion, Slack, Confluence, and local files. Can be run anytime after /setup-knowledge-base.
---

# KB Refresh

Add content from new sources or update existing KB entries from their original sources.

## When to Use

- Adding a new knowledge source (Notion page, Slack channel, etc.) after initial setup
- Re-scraping sources to pick up recent changes
- Importing additional documents into the KB

## Prerequisites

Check that `kb/` and `kb/.kb-config.yaml` exist. If not, tell the user to run `/setup-knowledge-base` first.

## Step 1: Understand Current KB

Read the KB config and index to understand what's already there:

```
kb/.kb-config.yaml
kb/index.md
```

Run the index script to see the current state:
```bash
python3 scripts/kb-index.py
```

## Step 2: Discover Sources

Ask the user (use AskUserQuestion with multiSelect):

**"What sources do you want to add or refresh?"**
- Notion pages
- Slack channels
- Confluence pages
- Local files or folders
- Other

### Collect Entry Points

For each selected source, ask the user for the entry point:

| Source | What to ask | MCP tool |
|--------|-------------|----------|
| Notion | Page URL (will scrape the page and all subpages recursively) | `notion-fetch` with the page URL, then `notion-search` or `notion-get-page-descendants` for child pages |
| Slack | Channel name(s) to extract knowledge from | `slack_read_channel` to read recent messages |
| Confluence | Space key or page URL | `getConfluencePage` + `getConfluencePageDescendants` for recursive scraping |
| Local files | Directory path or file paths | Read tool directly |

## Step 3: Choose Processing Mode

Ask the user (use AskUserQuestion):

**"Process one at a time or all in parallel?"**
- One at a time (review each before continuing)
- All in parallel (faster, review at the end)

## Step 4: Scrape and Extract

For each source, launch a subagent (or process sequentially, per the user's choice):

```
You are populating a knowledge base from an external source.

SOURCE: {source_type}: {url_or_path}

KB CATEGORIES (place entries in the most relevant one):
{list of categories from .kb-config.yaml}

EXISTING ENTRIES (avoid duplicating these):
{output from kb-index.py}

INSTRUCTIONS:
1. Read/scrape the source content using the appropriate tool
2. For Notion/Confluence: follow all child pages and subpages recursively
3. For Slack: focus on pinned messages, bookmarks, and high-signal threads (not casual chat)
4. Split the content into distinct topics. Create one .md file per topic, not one giant file.
5. If an existing entry covers the same topic, UPDATE it rather than creating a duplicate.
   Read the existing file first, merge the new information, and update last_updated.
6. For new entries, create a file in kb/{category}/ with this format:

---
title: "Topic Title"
description: "Brief one-liner for index lookup"
category: {category}
tags: [{relevant}, {tags}]
sources: ["{source_url_or_path}"]
last_updated: "{today's date}"
---

## Content

Write clear, quotable statements. Each fact should be independently citable.

7. Use lowercase-with-hyphens for filenames: product-overview.md, data-encryption.md
8. Preserve specifics: exact numbers, dates, names, versions
9. No opinions or speculation, only facts from the source
10. Skip content that is outdated, trivial, or not worth preserving

REPORT: When done, list all files created or updated with their category and a one-line description.
```

## Step 5: Review

After all sources are processed:
1. Run `python3 scripts/kb-index.py --write` to regenerate `kb/index.md`'s "All Files by Category" section from the current KB.
2. Run `python3 scripts/kb-validate.py` to catch missing frontmatter, bad categories, or broken `related:` links.
3. Present a summary: X entries created, Y entries updated, from Z sources. Flag any warnings or errors from `kb-validate.py`.
4. Ask the user if they want to add more sources or are done.
