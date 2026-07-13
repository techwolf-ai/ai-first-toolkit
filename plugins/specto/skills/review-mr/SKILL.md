---
name: review-mr
description: Use when the user wants a spec-anchored review of a code merge request (MR) / pull request (PR) — "review this MR against the spec", "review MR !123 / PR #123", "does this MR match the ticket/spec", "spec-anchored code review". Reviews the diff on four axes (spec adherence, AC coverage, best practices, security) anchored in the linked spec + ticket AC. For spec-document MRs use review-spec; for DoD pass/fail use dod-check; for responding to existing comments use resolve-mr-comments.
---

# review-mr

Spec-anchored review of a **code MR**: dispatch the `code-mr-review` agent on the branch diff with the linked spec section(s) and ticket AC as the rubric. Findings land in markdown-reviewer's local-comment sidecar by default — the author triages privately and pushes only the survivors — keeping the MR readable for human reviewers.

This sits between `dod-check` (checklist pass/fail) and the spec-blind built-in `/code-review`.

## Prerequisite check

- The forge CLI (`glab`/`gh`) on PATH and authenticated; `acli` for the AC read (warn and continue without AC if missing — but see the refusal rule below).
- The MR (or current branch) has commits ahead of trunk.

## Inputs the skill resolves

- **MR target** — an IID, branch name, or URL (same resolution table as `resolve-mr-comments` Phase 1); default is the current branch's MR. Resolve via `"${CLAUDE_PLUGIN_ROOT}/scripts/forge/mr-fetch.sh" info [--iid <N>|--branch <name>]`; record `MR_IID`. No open MR is fine too — the skill can review a local branch pre-MR (local sink only).
- **Ticket key** — from the MR title's `[<KEY>]` prefix (the `implement-ticket` convention), or ask. Pull the AC via `scripts/tracker/get-ticket-description.sh <KEY>`.
- **Spec section** — the ticket description's `Spec section: <link>` (the `plan-to-tickets` convention); resolve to the spec file + heading anchor(s) on disk. No spec link → ask which spec the work belongs to.
- **Sink** — default is **local comments** (`.md-review/comments.json` via the mdreview helpers) when the repo is writable on disk; `--post` posts directly to the MR instead (line-anchored, idempotent).

**Refuse politely when there is neither a spec link nor an AC list** — there is nothing to anchor the review; point the user at the built-in `/code-review` for a spec-blind pass (mirrors `implement-ticket`'s gate).

## Steps

1. **Gather the rubric.** Branch diff (`jj diff -r 'main..@'` / `git diff <trunk>...HEAD`), the spec section(s) the ticket names, the AC list.
2. **Dispatch the reviewer.** `subagent_type="specto:code-mr-review"` with `branch_diff`, `spec_path` (+ anchors), `ticket_key`, and — **only with `--post`** — `mr_iid` + `project_path`. In the default collect mode the agent returns findings grouped by axis.
3. **Route the findings (default sink — local comments).** For each collect-format finding:

   ```text
   "${CLAUDE_PLUGIN_ROOT}/scripts/mdreview/add-local-comment.sh" <repo-root> <file> <line> code-mr-review <section> <finding-type> -
   ```

   with the body on stdin (idempotent — re-runs fold onto the same comments). Tell the user to triage in markdown-reviewer; to push the survivors later, replay `list-local-comments.sh <repo-root> --specto-only --unresolved` through `post-mr-comment.sh` (the *Push triaged survivors* recipe in `review-spec`). When the repo isn't writable on disk, fall back to presenting the findings inline and offering `post-mr-comment.sh` per finding — review-spec's collect flow.
4. **Summarise.** Per-axis finding count, where they landed (sidecar / inline / posted), and the suggested next step ("triage in markdown-reviewer, push survivors" or "all four axes clean").

4b. **Offer a review report on the MR (#43) — the human-reviewer's default view.** Reviewing is the bottleneck, and the local sidecar is invisible to a human skimming the MR. Offer to post **one** concise report as a general MR note (via `post-mr-comment.sh` with no line anchor) so a reviewer sees *that* specto reviewed and what it concluded, without N inline threads. The report is a short table: one row per axis (spec-adherence, ticket-AC coverage, edge-case/test-critic audit, diff-scoped security) with a ✓/⚠ verdict and a one-line note, plus a count of findings fixed in-session vs pushed for the reviewer. It complements — does not duplicate — the `mr-walkthrough` HTML artifact (architecture/behaviour/design). Default-offer, not auto-post; the author confirms.

## Hard rules

- **The spec + AC are the rubric.** Findings cite their anchor; implementer's-choice harnesses are verified against their criteria, never re-litigated.
- **Local-first by default.** Nothing reaches the MR until the author triages (or `--post` was explicitly passed) — the comment-volume lesson from #17.
- **All MR writes go through `post-mr-comment.sh`; all sidecar writes through the mdreview helpers.** Never inline the forge CLI (`glab`/`gh`).

## When this skill should NOT run

- DoD verification before flipping ready → `dod-check`.
- The MR changes spec documents → `review-spec`.
- Responding to existing reviewer comments → `resolve-mr-comments`.
- No spec link and no AC → refuse; suggest the built-in `/code-review`.
