---
name: dod-check
description: Use to verify a branch (or open MR) meets Definition-of-Done before requesting review. Triggers on "check DoD", "is this ready", "verify done definition", "dod check".
---

# dod-check

Verify Definition-of-Done coverage in two modes:

- **`--mode=epic-creation`** — run once after `plan-to-tickets` has created the ticket stack. Verifies that every DoD checklist item has a corresponding child ticket on the epic. Catches gaps before implementation starts.
- **`--mode=ticket-level`** (default) — run before requesting MR review on each child ticket. Composes five DoD sources: epic Issue Checklist (the epic's canonical DoD), `default_dod_checklist` (per-team fallback in `.specto/config.yml`), per-ticket acceptance criteria, compliance-rigor controls when a configured compliance profile flags the change, and the nearest `AGENTS.md`/`CLAUDE.md` conventions for each changed path (a divergent mechanism with no §6 note is flagged).

## Prerequisite check

- A linked spec folder is identifiable (most-recent `engineering-spec.md` in `docs/development/specs/`, or the user supplies it).
- `<spec_folder>/.specto-meta.yml` has an epic key (for the Issue Checklist read and child-ticket lookup).
- `acli` is on PATH; warn but do not abort if missing — DoD partial-check (without epic checklist) still runs.
- `--mode=ticket-level` (default) additionally requires the current branch has commits ahead of main.

## Inputs the user provides

- **`--mode=<epic-creation|ticket-level>`** — defaults to `ticket-level`.
- **Spec folder** (defaulted; asked if ambiguous).
- **Ticket key** (`ticket-level` mode only; optional but encouraged — the agent will check the AC against the branch diff if a key is supplied).
- **`--with-test-critic`** (`ticket-level` mode only; off by default) — additionally dispatch the `specto:test-critic` agent for an edge-case coverage audit as a sixth signal. Opt-in because it's a heavier model pass than the haiku `dod` agent; the default dod-check stays cheap.

## Steps

### `--mode=epic-creation`

1. **Resolve the epic key** from `<spec_folder>/.specto-meta.yml`.
2. **Fetch all child tickets** via `"${CLAUDE_PLUGIN_ROOT}/scripts/tracker/list-children.sh" <epic-key>` — a normalized `[{key, summary, status, type}]` array.
3. **Dispatch the `dod` agent** with `subagent_type="specto:dod"` and `mode="epic-creation"`. Inputs:
   - `mode`: `"epic-creation"`.
   - `spec_path`: absolute path to `engineering-spec.md`.
   - `epic_key`: from `.specto-meta.yml`.
   - `ticket_keys`: list of child-ticket keys + their summary/description payloads.
   - `config_path`: `.specto/config.yml` if it exists.
4. **Print the agent's coverage report** to stdout. No MR comment — there's no MR yet.

### `--mode=ticket-level` (default)

1. **Run lint pre-pass on changed spec files.** If the diff includes `docs/development/specs/**/*.md`, invoke `<plugin-root>/scripts/lint/product-spec-lint.sh` against each. Lint failures block the model pass (mirrors `review-spec`).
2. **Dispatch the `dod` agent** with `subagent_type="specto:dod"` and `mode="ticket-level"`. Inputs:
   - `mode`: `"ticket-level"`.
   - `branch_diff`: output of `jj diff -r 'main..@'` (or `git diff <trunk>...HEAD` on a plain-git repo).
   - `spec_path`: absolute path to `engineering-spec.md`.
   - `ticket_key`: optional ticket key.
   - `epic_key`: from `.specto-meta.yml`.
   - `config_path`: `.specto/config.yml` if it exists.
   - `compliance_profile`: the parsed `compliance:` block from `.specto/config.yml` when present (questions with `id`, `flag`, `rigor`; shape in `<plugin-root>/references/compliance-profile.example.yml`). When the block is absent, say so explicitly in the dispatch — the agent then skips the compliance-rigor source with a one-line note instead of guessing.
   - `mr_iid`, `project_path`: optional forge MR identifiers if an MR is already open.
3. **Aggregate the agent's report.** Print pass/fail summary grouped by source (epic checklist / ticket AC / compliance rigor / team default / nearby conventions). When a ticket key is supplied, the report also includes a **State desyncs** section — e.g. a `To Do` ticket with an open implementation MR, or a `Done` ticket with no merged MR. These are findings, not gating failures, and are counted separately from the DoD totals.
4. **Only when `--with-test-critic` was supplied:** dispatch `specto:test-critic` (`subagent_type="specto:test-critic"`) on the same `branch_diff` + `spec_path` + `ticket_key`, and append its `Summary:` line plus any `✗` cases as a sixth group — **Edge-case coverage (test-critic)** — in its own section like the state-desync findings: surfaced alongside the DoD report but excluded from the pass/fail totals and never flipping the recommendation on its own.

## Hard rules

- **Reports, doesn't gate.** This skill never blocks a merge — gating is a CI concern (V0.7 ships the example wiring).
- **Source attribution per finding.** Every "missing item" finding cites which DoD source caught it (epic checklist? team default? AC?), so the user knows where to act.
- **Lint blocks model.** Same discipline as `review-spec`: mechanical fails before model. (Lint pre-pass runs in `ticket-level` mode only.)
- **Run `--mode=epic-creation` once after `plan-to-tickets` lands the ticket stack** so coverage gaps surface before implementation starts. Run `dod-check` (default `ticket-level`) before requesting MR review on each child ticket.

## When this skill should NOT run

- `--mode=ticket-level` with no commits ahead of main: nothing to check.
- The user wants a per-spec-section review of the spec itself: invoke `review-spec` instead.
