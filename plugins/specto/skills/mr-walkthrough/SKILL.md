---
name: mr-walkthrough
description: Use when the user wants a visual walkthrough of what a merge request (MR) / pull request (PR) changes — "walk me through this MR", "walk me through this PR", "visualize MR !123 / PR #123", "diagram this change", "explain the MR with diagrams", "add a change walkthrough". Generates spec-anchored mermaid diagrams (runtime sequence, dependency, service-interaction, state machine) over the diff and maintains them as a "## Change walkthrough" section in the MR description. For findings/review use review-mr; for DoD pass/fail use dod-check; this skill explains the change, it does not judge it.
---

# mr-walkthrough

Produce a **visual change walkthrough** for a code MR: a small set of mermaid
diagrams over the diff that show how the change works, anchored to the spec section
the ticket names. The diagrams are maintained as a single idempotent
`## Change walkthrough` section in the **MR description**, so they render in the
forge (GitLab/GitHub) MR view and in the Markdown Reviewer PWA.

This is the diagram *complement* to `review-mr`: `review-mr` posts findings (is the
change correct?), `mr-walkthrough` explains the change (what does it do?). They
compose; neither replaces the other.

Diagram forms, the dark-mode palette, and the validate-before-write rule live in
`references/visual-conventions.md` — read it before drafting.

## Prerequisite check

- The forge CLI (`glab`/`gh`) on PATH and authenticated.
- The MR (or current branch) has commits ahead of trunk.

## Inputs the skill resolves

- **MR target** — an IID, branch name, or URL (same resolution as `review-mr`).
  Resolve via `"${CLAUDE_PLUGIN_ROOT}/scripts/forge/mr-fetch.sh" info [--iid <N>|--branch <name>]`;
  record `MR_IID`. No open MR is fine — the skill can walk a local branch and print
  the section to chat (see Sink).
- **Spec section (optional but preferred)** — from the ticket's `Spec section:` link
  (the `plan-to-tickets` convention) or the MR title's `[<KEY>]` prefix. Read the
  named section so the diagrams use the spec's vocabulary and reflect its decisions.

## Steps

1. **Pull the diff.** `"${CLAUDE_PLUGIN_ROOT}/scripts/forge/mr-fetch.sh" diff [--iid <N>|--branch <name>]`
   — a JSON array of per-file `{old_path, new_path, diff}`. Skip lockfiles, generated
   output, vendored trees, and binaries; cap total diff bytes (~50 KB), preferring the
   smaller files. `Read` full file content under the repo when you need surrounding
   context to make a diagram accurate.
2. **Decide which diagrams to draw** (per the `visual-conventions.md` catalog; draw
   zero or more, never fabricate):
   - **`sequenceDiagram`** — when the change touches a request handler / endpoint / job
     entry point. Show the runtime flow *on the changed path*, not the whole file.
   - **dependency `flowchart`** — when imports/modules cross boundaries (more than one
     module changed and they reference each other).
   - **service-interaction `flowchart`** — when a file matching `*api*`, `*client*`,
     `*.proto`, an OpenAPI spec, `*/services/*`, or an HTTP/queue boundary changed.
     Services are nodes; show the new edges.
   - **`stateDiagram-v2`** — only if a recognizable status/state enum was added or changed.
   - **annotated diff** — a fenced ` ```diff ` excerpt of the single key hunk with a
     one-line caption, when one hunk carries the change.
   - **file map** — a fenced ` ```text ` tree when the change touches ≥5 files.
3. **Compose the section.** A `## Change walkthrough` heading, one short
   plain-English sentence of context (cite the spec section if resolved), then the
   diagrams. Keep each diagram small and on one concern. Validate every mermaid block
   is syntactically correct before writing. Apply the dark-mode palette rules.
4. **Sink — maintain the MR description section (idempotent).** Pipe the composed
   markdown to:

   ```text
   "${CLAUDE_PLUGIN_ROOT}/scripts/forge/mr-describe.sh" - [--iid <N>|--branch <name>]
   ```

   It splices the section between `<!-- specto:walkthrough:start -->` / `:end -->`
   markers, replacing any prior walkthrough in place rather than appending a duplicate,
   and leaves the rest of the description (and the title) untouched. Re-running after a
   new push refreshes the diagrams.

   **Fallback (no open MR):** print the section to chat so the user can paste it, or,
   when the repo is writable on disk and the user prefers the PWA, write it to a file
   under the repo for review. Never inline the forge CLI (`glab`/`gh`).
5. **Summarise.** List which diagrams were generated (one line each), the MR the
   section landed in, and the `source` branch/ref so the user can confirm the right
   diff was walked. Do not paste the mermaid source back into chat — the MR renders it.

## Hard rules

- **Explain, don't judge.** Findings are `review-mr`'s lane; do not emit review
  comments here. If you notice a defect while drawing, mention it once in the summary
  and point at `review-mr`; do not bury it in the walkthrough.
- **Don't fabricate.** Every node and edge traces to the diff or to file content you
  read. An invented edge is worse than a smaller diagram.
- **Validate before writing.** Run `"${CLAUDE_PLUGIN_ROOT}/scripts/lint/validate-mermaid.sh" <file>`
  (or paste the composed section into a temp file and validate that) so a broken fence
  never reaches the MR as an error box. Fix any reported syntax error before the sink step.
- **Idempotent sink.** All description writes go through `mr-describe.sh`; never inline
  the forge CLI (`glab`/`gh`). Re-runs update the section in place.
- **Small and split.** When the change spans multiple callers, prefer one structural
  diagram plus per-caller sequence diagrams over one omnibus tangle
  (`visual-conventions.md`).

## When this skill should NOT run

- The user wants findings / a correctness review → `review-mr`.
- DoD verification before flipping ready → `dod-check`.
- The MR changes spec documents, not code → `review-spec`.
