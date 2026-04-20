---
name: setup-knowledge-base
description: |
  Interactive onboarding to create a structured knowledge base. Defines categories,
  scaffolds the directory structure, creates the index, and optionally imports initial content.
  Run this first before using /kb-answer or /kb-import.
---

# Knowledge Base Setup

Interactive setup that creates a structured, evidence-backed knowledge base in your project.

## When to Use

- Starting a new knowledge base from scratch
- Adding a KB to an existing project

## Step 1: Discover Purpose

Ask the user (one question at a time, use AskUserQuestion):

1. **What is this KB for?** (e.g., product documentation, security/compliance, company knowledge, sales enablement, internal policies)
2. **Who will query it?** (e.g., you personally, your team, AI agents answering questions)
3. **What categories make sense?** Suggest 3-5 based on the domain, let the user adjust.

Example category suggestions by domain:
- **Product docs**: technical, integrations, deployment, security, faq
- **Company knowledge**: general, policies, processes, teams, faq
- **Sales enablement**: product, competitive, customer-success, pricing, faq
- **Security/compliance**: security, compliance, technical, general, faq

## Step 2: Confirm Plan

Before creating anything, present the plan to the user:

```
I'll create this structure in your project:

kb/
  .kb-config.yaml
  index.md
  scopes/
    _default.yaml
    README.md
  {category1}/
  {category2}/
  {category3}/
scripts/
  kb-index.py
  kb-verify.py
  kb-validate.py
CLAUDE.md (or append to existing)

Ready to proceed?
```

Wait for user confirmation.

## Step 3: Scaffold the KB

Read the template files from this plugin and adapt them for the user's project:

1. **Read** `templates/kb/.kb-config.yaml` from this plugin. Create `kb/.kb-config.yaml` in the user's project, replacing the placeholder categories with the ones chosen in Step 1. Replace `{{today}}` with today's date.

2. **Read** `templates/kb/index.md` from this plugin. Create `kb/index.md`, adding seed keywords for each chosen category. For example, if the user chose "security" and "technical", add initial keyword entries:

   ```
   | encryption, certificates, access | security/ |
   | API, architecture, deployment | technical/ |
   ```

3. **Read** `templates/kb/scopes/_default.yaml` from this plugin. Copy to `kb/scopes/_default.yaml`.

4. **Read** `templates/kb/scopes/README.md` from this plugin. Copy to `kb/scopes/README.md`.

5. Create empty directories for each chosen category: `kb/{category1}/`, `kb/{category2}/`, etc.

6. **Read** `scripts/kb-index.py` from this plugin. Copy to `scripts/kb-index.py` in the user's project.

7. **Read** `scripts/kb-verify.py` from this plugin. Copy to `scripts/kb-verify.py` in the user's project.

8. **Read** `scripts/kb-validate.py` from this plugin. Copy to `scripts/kb-validate.py` in the user's project.

## Step 4: Create Project CLAUDE.md

**Read** `templates/CLAUDE.md` from this plugin. Create (or append to existing) `CLAUDE.md` in the user's project root. Replace `{{category}}` placeholders with the actual categories chosen in Step 1.

## Step 5: Populate from Sources

The KB structure is ready, but empty. Ask the user:

**"Do you have existing knowledge sources you'd like to import? (Notion pages, Slack channels, Confluence, local files)"**

- If **yes**: run `/kb-refresh` to populate the KB from those sources. It handles source discovery, scraping, and entry creation.
- If **no** or **skip**: create one example entry in the first category to demonstrate the format. **Read** `templates/kb/example/sample-entry.md` from this plugin for the format, but write an entry relevant to the user's domain rather than copying the sample.

## Step 6: Verify

Run the index script to confirm everything is wired up:

```bash
python3 scripts/kb-index.py
```

Regenerate the "All Files by Category" section of `kb/index.md` from the current entries:

```bash
python3 scripts/kb-index.py --write
```

Validate KB health (frontmatter, categories, related links):

```bash
python3 scripts/kb-validate.py
```

If `kb-index.py` lists the entries and `kb-validate.py` reports "All entries valid", setup is complete.

## Step 7: Summary

Tell the user:
- What was created and where
- How to add new entries (create .md files with YAML frontmatter in the right `kb/{category}/` folder)
- How to query the KB (`/kb-answer`)
- How to import documents (`/kb-import`)
- How to add more sources or refresh existing ones (`/kb-refresh`)
- How to list all entries (`python3 scripts/kb-index.py`)
