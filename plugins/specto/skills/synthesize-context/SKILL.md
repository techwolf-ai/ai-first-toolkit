---
name: synthesize-context
description: Use when the user has accumulated raw source material in a spec folder's context/raw/ and wants it synthesised into per-topic compiled summaries. Triggers on "synthesize the context", "compile what we've gathered", "summarise the raw context", "build the compiled folder".
---

# synthesize-context

Read every file in a spec folder's `context/raw/`, identify the natural topic clusters, dispatch one worker subagent per topic in parallel, and produce one `context/compiled/<topic>.md` per cluster. Compiled files are the primary input the `product-spec-writer` and `engineering-spec-writer` agents read alongside the brainstorm artefact.

## Prerequisite check

- The current working directory must be inside (or be) a `docs/development/specs/<YYYY-MM-DD-slug>/` folder.
- `context/raw/` must contain at least 2 files. Below 2 files there's nothing to synthesise — tell the user to add more raw context first.
- `superpowers:dispatching-parallel-agents` must be available. If not, fall back to sequential dispatch with a warning.

## Steps

1. **List `context/raw/`** files and read the provenance headers (first 8 lines of each). Build a short summary of what's there.

2. **Identify topic clusters.** Look at filenames, provenance `topic:` fields, and content snippets. Cluster files that talk about the same concrete subject (e.g. all the matching-related raw files → `matching-context.md`; all customer-feedback raw files → `customer-feedback.md`). Aim for 2–6 clusters; merge under-populated ones.

   Confirm the proposed cluster split with the user before dispatching. Show the proposed `context/compiled/<topic>.md` filenames and which raw files feed each.

3. **Dispatch worker subagents in parallel.** Use `superpowers:dispatching-parallel-agents`. One Task tool call per cluster, all in the same assistant message. Each worker:
   - `subagent_type="general-purpose"` (no specialised agent needed; the work is reading + synthesis).
   - Inputs in the prompt: list of absolute paths to raw files in this cluster, target output path (`<spec-folder>/context/compiled/<topic>.md`), the topic slug.
   - Worker contract:
     - Reads every raw file fully.
     - Produces a structured markdown summary: section per source, then a "Cross-cutting themes" section that synthesises across sources.
     - Each claim cites its raw-file source by relative path.
     - Writes the output file.
     - Returns: word count, sources processed, any PII or sensitivity flags noticed.

4. **Aggregate.** Once all workers return, print a summary: which compiled files were produced, what each covers in one sentence, and what the recommended next step is (typically *"draft the spec — run new-spec"*).

## Hard rules

- **Compiled files cite raw files.** Never lose the trail back to the source. If a worker can't cite a claim, it gets dropped.
- **Never edit `context/raw/`.** Synthesis is read-only against raw.
- **One topic per compiled file.** No mega-files that mix topics. Better to have 4 small compileds than 1 large one.
- **Re-runs overwrite.** Synthesis is idempotent on a stable raw set; running this skill twice on the same raw produces (roughly) the same compiled output. The compiled folder is regenerable, not authored.

## When this skill should NOT run

- The user has fewer than 2 raw files: invoke `add-raw-context` first.
- The user wants to draft the spec body: invoke `new-spec` (which reads the compiled folder as input).
- The user wants to update a single raw file: invoke `add-raw-context` instead (re-fetch into a new file).
