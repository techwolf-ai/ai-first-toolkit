---
name: kb-import
description: |
  Import knowledge from existing documents into structured KB entries.
  Reads source documents (Markdown, PDF, DOCX, plain text), extracts key information,
  and creates properly formatted KB entries with YAML frontmatter.
---

# KB Import Workflow

Import knowledge from existing documents into your knowledge base.

## When to Use

- Adding knowledge from existing documentation
- Converting unstructured docs into structured KB entries
- Bulk-importing content into a new KB

## Modes

- **Single-document mode** (default): one source document is split into one or more KB entries. Use Steps 1 to 6 below.
- **Bulk mode**: many source documents are ingested at once from a directory or a list of files. Use when the user points at a folder or provides a list longer than ~3 files. See [Bulk Mode](#bulk-mode) at the bottom.

## Step 1: Understand the KB Structure

Read the KB config to understand available categories:
```
kb/.kb-config.yaml
```

Read the index to see what already exists:
```
kb/index.md
```

## Step 2: Read the Source Document

Read the source file provided by the user. Supported formats:
- Markdown (.md)
- PDF (.pdf, use the Read tool with page ranges for large files)
- Plain text (.txt)

## Step 3: Plan the Extraction

Analyze the document and propose a plan to the user:

1. How many KB entries should be created?
2. What categories do they belong to?
3. Suggested titles for each entry

Present this as a table:
```
| # | Title | Category | Source Section |
|---|-------|----------|---------------|
| 1 | ... | ... | ... |
```

Wait for user confirmation before proceeding.

## Step 4: Create KB Entries

For each planned entry, create a markdown file with YAML frontmatter:

```markdown
---
title: "Entry Title"
description: "Brief one-liner for index lookup"
category: {category}
tags: [{tag1}, {tag2}]
sources: ["{source_filename}"]
last_updated: "{today's date}"
related:
  - {category}/{related-file}.md
---

## Section Title

Content here. Write clear, quotable statements.
Each fact should be a self-contained sentence that can be cited as evidence.
```

### Content Guidelines

- **Preserve specifics**: Keep exact numbers, dates, names, versions. Keep concrete customer/product examples by name (e.g., "T-Mobile", "Atlas Copco") — they make abstract concepts tangible and shouldn't be stripped "for neutrality".
- **One topic per entry**: Don't create catch-all files
- **Quotable statements**: Write so that individual sentences can be cited as evidence
- **Capture the easily-missed content types** when the source covers them: stakeholders (one entry per key person with role + ownership + contact pattern), projects (goal/owner/status), repositories (purpose/ownership). These are the most commonly skipped in first-pass imports.
- **No opinions or speculation**: Only include facts from the source document
- **Use markdown structure**: Headers, bullet points, tables for structured data

### File Naming

- Use lowercase with hyphens: `data-encryption.md`, `product-overview.md`
- Name should reflect the topic, not the source document

## Step 5: Update the Index and Validate

After creating entries, regenerate the index and validate:
```bash
python3 scripts/kb-index.py --write   # rewrite kb/index.md's "All Files by Category"
python3 scripts/kb-validate.py        # check frontmatter, categories, related links
```

Review the stdout output to verify all new entries appear correctly. Resolve any validate errors before continuing.

## Step 6: Summary

Report to the user:
- How many entries were created
- Which categories they were placed in
- Any information from the source document that was skipped (and why)
- Suggestion to review entries and add `related:` links between them

## Bulk Mode

Use this when the user wants to ingest many documents in one go (e.g., "import everything in `~/docs/policies/`", or a list of 5+ files).

### Bulk Step 1: Enumerate the source set

- If the user provided a directory, list supported files in it recursively (`.md`, `.pdf`, `.txt`, `.docx`). Skip obvious noise (`.DS_Store`, `node_modules`, hidden files).
- If the user provided a list of paths, use exactly those.
- Present the file count and a sample (first 10) to the user. Confirm before reading anything heavy.

### Bulk Step 2: Plan across the whole batch

Read the frontmatter / first page of each file to get a title guess. Produce a single combined plan:

```
| # | Source file | Proposed KB entry | Category |
|---|-------------|-------------------|----------|
| 1 | policies/acceptable-use.pdf | security/acceptable-use.md | security |
| 2 | policies/retention.pdf      | security/data-retention.md | security |
| ...
```

Rules:
- One KB entry per source file by default. Split a source into multiple entries only when it clearly covers multiple distinct topics.
- Prefer nested categories (e.g., `security/access`) when the batch is large enough that a flat category would become unwieldy (> ~10 entries in one category).
- Flag duplicates up front: if a planned entry already exists in the KB, mark it "UPDATE" instead of "CREATE".

Wait for user confirmation on the full plan before proceeding.

### Bulk Step 3: Process in parallel

- For ≤ 5 files, process sequentially (easier to follow, fewer context switches).
- For > 5 files, dispatch a subagent per file (or per small group of related files) with the import instructions, the target path from the plan, and the existing KB index as context. Collect results.
- If any subagent fails, keep the successful entries and report the failures so the user can retry a smaller batch.

### Bulk Step 4: Finalize

After all files are processed:
```bash
python3 scripts/kb-index.py --write
python3 scripts/kb-validate.py
python3 scripts/kb-search.py "sanity-check-term"   # spot-check a term that should appear
```

Report: X created, Y updated, Z skipped (with reason per skip). Flag any validate warnings or errors.
