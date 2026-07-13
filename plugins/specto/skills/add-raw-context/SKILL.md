---
name: add-raw-context
description: Use when the user wants to pull raw source material (URL, paste, Notion page, Slack thread, Google Doc) into a spec folder's context/raw/ for later synthesis. Triggers on phrases like "add the Matching PRD as raw context", "pull this URL into context", "fetch the Slack thread on...", "add this Notion page to my spec context".
---

# add-raw-context

Pull external source material into a spec folder's `context/raw/` with a provenance header so the writer agent (and reviewers, and future you) can trace every claim back to its origin.

## Prerequisite check

The current working directory must be inside (or be) a `docs/development/specs/<YYYY-MM-DD-slug>/` folder. If not, ask the user which spec folder this context belongs to. Abort if no spec folder is named.

## Inputs the user provides

Ask one question at a time:

- **Source type.** URL, file paste, Notion page, Slack thread, Google Doc, or local file path.
- **Source identifier.** URL / page-id / channel+timestamp / file path / paste body.
- **Topic slug.** Kebab-case label that goes into the filename (e.g. `matching-prd`, `eng-handoff`, `customer-feedback`).

## Steps

1. **Resolve the source.** Use whichever path matches the source type the user named:

   | Source | Tool |
   |---|---|
   | URL | `WebFetch` |
   | Notion page | `mcp__notion__*` if the Notion MCP is configured; otherwise WebFetch the page URL |
   | Slack thread | `mcp__claude_ai_Slack__*` if the Slack MCP is configured; otherwise ask the user to paste the thread |
   | Google Doc | `mcp__claude_ai_Google_Drive__*` if the Drive MCP is configured; otherwise WebFetch (works for public docs) |
   | Local file | `Read` |
   | Paste body | use the body the user pasted directly |

   If the matching MCP is not configured, fall back to WebFetch or ask the user to paste. Never silently skip — always surface what's available and what isn't.

2. **PII pre-pass.** Run a regex sweep on the fetched content for: emails, phone numbers, US-style SSNs, full names appearing in employee-record contexts, API keys, private URLs (links containing `?token=` or `&key=`). Match permissively (false-positives are fine; users confirm). Print the matches to the user.

3. **Redaction confirmation.** Ask: *"Found N PII candidates. Redact them before writing? [y/n/edit]"* — `y` replaces each match with `[REDACTED:<category>]`; `n` writes as-is; `edit` opens the content for the user to manually adjust before write.

4. **Provenance header.** The first 8 lines of every written file are a YAML-frontmatter-style block:

   ```markdown
   ---
   source: <URL | file path | "paste" | "Notion: <page id>" | "Slack: <channel> <ts>">
   fetched_at: <ISO 8601 UTC>
   fetched_by: <git config user.email>
   sha256: <sha256 of the post-redaction body>
   redacted: <true | false>
   pii_categories_redacted: [<list>]
   topic: <kebab-case topic slug>
   ---

   ```

5. **Write the file.** Filename is `<spec-folder>/context/raw/<YYYY-MM-DD>-<topic-slug>.md`. If a file with that exact name already exists, append `-2`, `-3`, etc. Never overwrite.

6. **Print a summary.** Report: file written, byte count, PII matches found and redacted (or kept), and remind the user that `synthesize-context` is the next step once enough raw material is in place.

## Hard rules

- **Never write outside `context/raw/`.** No accidental writes to `context/compiled/` or to the spec body.
- **Never silently skip the PII pre-pass.** Even when the user is in a hurry, surface the matches and ask. The redaction prompt is mandatory.
- **One source per invocation.** Don't batch — each source gets its own file with its own provenance.
- **Provenance is immutable.** The header is written once; never edit a `context/raw/` file after creation. Re-fetch into a new file if the source changed.

## When this skill should NOT run

- The user is drafting the spec body itself: invoke `new-spec` instead.
- The user wants to *summarise* multiple raw files: invoke `synthesize-context`.
- The user is editing an existing `context/raw/` file: don't — re-fetch into a new file instead.
