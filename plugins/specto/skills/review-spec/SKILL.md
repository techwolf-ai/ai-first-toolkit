---
name: review-spec
description: Use when the user wants reviewer feedback on an in-repo spec, asks "review this spec", "lint my product spec", or has just finished editing a product-spec.md and wants the reviewer agents to run. Runs a lint pre-pass, then dispatches the relevant reviewer agents in parallel (roster varies by spec type).
---

# review-spec

Run the deterministic lint pre-pass first, then the model-driven reviewer agents in parallel. By default findings are **gathered and presented inline in Claude Code** for the author to read, answer, and triage; posting them as line-anchored MR comments is an explicit opt-in after the inline pass. For non-interactive use (CI, unattended), `--post` restores direct auto-posting.

## Prerequisite check

If `superpowers:dispatching-parallel-agents` is not available, fall back to sequential dispatch but warn the user that parallel dispatch is preferred.

## Inputs the skill resolves

- **Spec file.** If the user is in a `docs/development/specs/<initiative>/` working directory, default to `<cwd>/product-spec.md`. Otherwise ask which spec file.
- **Mode.** Default is **collect mode** — gather reviewer findings and present them inline for triage, post nothing until the user opts in. `--post` is **auto-post mode** — reviewer agents post directly to the MR as they run (today's non-interactive behaviour; this is the CI / unattended path).
- **MR context.** Run `"${CLAUDE_PLUGIN_ROOT}/scripts/forge/mr-fetch.sh" info` in the repo (the single vetted MR-read path). Exit 0 returns the MR object for the current branch — capture `iid`, the head SHA (`.diff_refs.head_sha`), and derive `project_path` from `.web_url`; exit 3 means no open MR. If an MR exists and touches the spec file, in collect mode these are **held for the opt-in post step**, not handed to the agents; in `--post` mode they are passed to the agents. With no open MR (exit 3), only collect mode is available (there is nowhere to post).
- **Plugin root.** Resolve so the lint scripts and references can be located.

## Steps

1. **Run the lint pre-pass.** Execute `<plugin-root>/scripts/lint/product-spec-lint.sh "<spec_file>"`.

   - Exit code 0: lint passed; proceed to model review.
   - Exit code 1: lint failed; print the lint findings, do NOT proceed to model review, exit. Tell the user to fix the mechanical issues first.
   - Exit code 2: bad usage; print the usage error and exit.

2. **Resolve the OKR source and the linked epic (at the top level), then gate the roster.** Dispatched subagents do **not** inherit this session's MCP tools, so resolve these here and pass the results as plain text — and use what you resolve to **skip any reviewer whose only input is absent** (a reviewer dispatched with no input just spawns to self-abort and post a canned advisory — a full agent's worth of tokens for nothing).

   **OKR source** — the Notion lookup must happen here, where the user's Notion MCP is reachable:
   - If `.specto/config.yml` defines `notion_okr_page_id` **and** a Notion MCP tool (`mcp__notion__notion_get_page` / `notion-fetch`) is available, fetch that page and parse the OKR table → `has_okr_source = true`.
   - Else if `.specto/okrs.md` exists → `has_okr_source = true` (pass its path).
   - Else → `has_okr_source = false`.

   Capture the parsed KRs as a compact plain-text list (one `O#.KR# — <text>` per line) plus the source label (`Notion:<page-id>` or `.specto/okrs.md`).

   **Linked epic** — read `<spec-folder>/.specto-meta.yml` `epic:`; if empty/absent, scan the product-spec header table's `Epic link in Jira` row for a ticket key (`[A-Z][A-Z0-9_]+-[0-9]+`). `has_epic = true` iff a key resolves. (This is the same metadata `change-classification-review` would read to decide whether to run — reading it here lets the skill skip the dispatch entirely when there's no epic.)

   **Compliance profile** — read `.specto/config.yml` and parse its `compliance:` block (guide, epic_label, and the questions list; shape in `<plugin-root>/references/compliance-profile.example.yml`). `has_compliance = true` iff the block exists and declares at least one question. Classification review is opt-in: without a profile the classification reviewer has nothing to check.

3. **Dispatch the applicable reviewers in parallel.** Use `superpowers:dispatching-parallel-agents` to fan out one Task call per applicable reviewer in a single assistant message. **Pass `mr_iid` / `project_path` only in `--post` mode** — in collect mode (the default) omit them so the agents return findings in the collect format instead of posting.

   **Always dispatch:**
   - `subagent_type="specto:product-review"` with inputs: `spec_path`, `guidelines_path` (repo-local override or plugin default); `mr_iid` / `project_path` only in `--post` mode.
   - `subagent_type="specto:scope-review"` with inputs: `spec_path`; `mr_iid` / `project_path` only in `--post` mode.

   **Dispatch only when its input resolved in step 2 (skip the agent otherwise — do not spawn it just to self-abort):**
   - `subagent_type="specto:okr-alignment-review"` — **only when `has_okr_source`.** Inputs: `spec_path`, plus `okr_data` (parsed KR text) + `okr_source` (label) when Notion resolved, or `okrs_md_path` (`.specto/okrs.md`) for the markdown fallback; `mr_iid` / `project_path` only in `--post` mode. **When `has_okr_source` is false, do NOT dispatch** — emit the advisory inline yourself: `[specto:okr-alignment-review] no OKR source available; set notion_okr_page_id in .specto/config.yml or add .specto/okrs.md` (in `--post` mode, post it once as a §1.3 general note).
   - `subagent_type="specto:change-classification-review"` — **only when `has_compliance` AND `has_epic`.** Inputs: `spec_path`, `compliance_profile` (the parsed `compliance:` block from step 2); `mr_iid` / `project_path` only in `--post` mode. **When `has_compliance` is false, do NOT dispatch** — note `(no compliance profile; classification review skipped)` in the summary. **When `has_epic` is false, do NOT dispatch** — note inline: `[specto:change-classification-review] no epic linked; classification skipped`.

4. **Collect mode (default): present inline, then offer to post.** Once all reviewers return, aggregate their collect-format findings and present them **inline grouped by spec section** (agent, section, line, finding-type, the one-line issue + fix). Let the user triage — answer questions, dismiss false positives, accept the rest, per-finding or in bulk. Then, **only if an MR exists, offer to post the surviving findings.** On a yes, post each survivor yourself via the same idempotent helper the agents use:

   ```text
   "${CLAUDE_PLUGIN_ROOT}/scripts/forge/post-mr-comment.sh" <agent-name> <spec-path-relative-to-repo> <line> <section> <finding-type> -
   ```

   piping the finding body on stdin. `<agent-name>` is the reviewer that produced it (`product-review`, `scope-review`, …) so the marker matches what a later `--post` run or re-run would write — survivors collapse onto the same threads, never duplicate. Do not post anything the user dismissed.

   **Alternative sink — stage into markdown-reviewer (offer it alongside posting):** instead of (or before) posting, write the findings into markdown-reviewer's local-comment sidecar so the author triages them in that UI rather than in chat:

   ```text
   "${CLAUDE_PLUGIN_ROOT}/scripts/mdreview/add-local-comment.sh" <repo-root> <spec-path-relative-to-repo> <line> <agent-name> <section> <finding-type> -
   ```

   piping the finding body on stdin. The helper is idempotent on the same `(agent, file, section, finding-type)` key, so re-runs fold onto the same local comment. The author then opens markdown-reviewer, edits/resolves/deletes findings there, and pushes the survivors later — see *Push triaged survivors* below.

   **`--post` mode:** the agents already posted directly as they ran; skip the inline-triage step.

   Either way, finish with a summary: lint status (passed), per-agent finding count, what was posted (with the MR link) vs held inline, and the suggested next step ("address findings, re-run review-spec when ready" or "all clean, open the MR for stakeholder review").

## Engineering-spec mode

When `<spec_file>` is `engineering-spec.md`, eng-spec mode runs its own lint pre-pass first, then the model reviewers:

1. **Run the engineering-spec lint pre-pass.** Execute `<plugin-root>/scripts/lint/engineering-spec-lint.sh "<spec_file>"` — same gate behaviour as product mode's `product-spec-lint.sh`:

   - Exit code 0: lint passed; proceed to model review.
   - Exit code 1: lint failed; print the lint findings, do NOT proceed to model review, exit. Tell the user to fix the mechanical issues first.
   - Exit code 2: bad usage; print the usage error and exit.

   The eng-lint checks: §3.2 contains a fenced code block; §4.3 reversibility section present and non-trivial; if a stakeholder/reviewer table exists it must include a data-platform/platform-team row. (The stakeholder-table check only fires when a table exists, so the skill needn't branch on the epic's compliance-flag answers — just run the lint. A future refinement could skip the stakeholder check when the profile's data-flagged question is answered "No" on the epic.)

2. **Dispatch the applicable reviewers in parallel** (same mode rule as product mode — pass `mr_iid` / `project_path` only in `--post` mode; omit them in collect mode). Resolve `has_epic` first (as in product-mode step 2: `<spec-folder>/.specto-meta.yml` `epic:`, else the header-table `Epic link in Jira` row), and `has_compliance` (the `compliance:` block of `.specto/config.yml`, parsed as in product-mode step 2).

   **Always dispatch:**
   - `subagent_type="specto:eng-review"` with inputs: `spec_path`, `guidelines_path` (`.specto/engineering-spec-guidelines.md` if it exists, else `<plugin-root>/references/engineering-spec-guidelines.md`); `mr_iid` / `project_path` only in `--post` mode.
   - `subagent_type="specto:scope-review"` with inputs: `spec_path`; `mr_iid` / `project_path` only in `--post` mode.

   **Only when `has_compliance` AND `has_epic`:**
   - `subagent_type="specto:change-classification-review"` with inputs: `spec_path`, `compliance_profile` (the parsed `compliance:` block); `mr_iid` / `project_path` only in `--post` mode. When `has_compliance` is false, do NOT dispatch — note `(no compliance profile; classification review skipped)` in the summary. When `has_epic` is false, do NOT dispatch — note inline: `[specto:change-classification-review] no epic linked; classification skipped`.

   No `okr-alignment-review` (OKR anchoring is a product-spec concern). No `product-review` (product-spec content lives in the linked product-spec.md, not here).

3. **Aggregate.** Run step 4 from product mode (collect-mode inline triage + opt-in post, or the `--post` summary).

## Idempotent re-runs

Reviewer agents post via `<plugin-root>/scripts/forge/post-mr-comment.sh`, which embeds a stable marker `[specto:<agent-name>#<sha8>]` in each comment body, where `<sha8>` = first 8 hex of `sha1("<agent>\0<spec-path>\0<normalized-section>\0<normalized-finding-type>")`. The (section, finding-type) pair is normalized (lowercase, punctuation collapsed) so the key is reproducible across runs regardless of how the agent words the finding — which is what stops re-runs from orphaning old threads. Before posting, the helper fetches the MR's discussions (via `mr-fetch.sh`, which `--paginate`s) and scans every note for that marker — if found it PUT-edits that note in place, otherwise it creates a new discussion. So re-invoking `review-spec` after the author fixes things updates the existing findings in place instead of duplicating them — that's how Specto delivers "persistent review" cheaply, without a dedicated state file. The position is computed from the MR diff so comments line-anchor on modified files (unchanged lines send both `old_line` and `new_line`); a finding on a file the MR did not change posts as a clearly-flagged general note.

## Push triaged survivors (from markdown-reviewer)

When findings were staged into the local-comment sidecar, the still-unresolved specto comments after the author's triage are the survivors. To push them to the MR later:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/mdreview/list-local-comments.sh" <repo-root> --specto-only --unresolved
```

emits one JSON object per finding with `agent`, `section`, `finding_type`, `file`, `source_line`, and `body_clean` (the marker line stripped) parsed back out of the stored comment. Replay each through `post-mr-comment.sh <agent> <file> <source_line> <section> <finding_type> -` with `body_clean` on stdin — the sha8 derivation matches on both surfaces, so a finding that was ever posted before folds onto its existing MR thread instead of duplicating.

## Hard rules

- **Lint failures block model review.** Save tokens; mechanical issues belong to the lint library. Product-spec mode runs `product-spec-lint.sh`; engineering-spec mode runs `engineering-spec-lint.sh`. Either failing blocks the model pass.
- **Posting to the MR is opt-in.** Collect mode is the default: gather findings, present them inline, and post nothing until the user approves the survivors (or `--post` was passed for non-interactive auto-post). This keeps triage private — false positives and questions the author can answer in-session never hit the MR before the author chooses to surface them.
- **All MR writes go through `post-mr-comment.sh`.** Whether the agent posts (`--post` mode) or the skill posts the opt-in survivors (collect mode), it is the same helper and the same idempotent `[specto:<agent>#<sha8>]` marker — never ad-hoc forge CLI (`glab`/`gh`) calls. Reviewer agents never edit the spec and never resolve threads.

## When this skill should NOT run

- The user wants to draft a new spec: invoke `new-spec` instead.
- The user wants to address MR comments already posted: invoke `resolve-spec-comments` (V0.6).
