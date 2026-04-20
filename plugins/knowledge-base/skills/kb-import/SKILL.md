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

- **Preserve specifics**: Keep exact numbers, dates, names, versions
- **One topic per entry**: Don't create catch-all files
- **Quotable statements**: Write so that individual sentences can be cited as evidence
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
