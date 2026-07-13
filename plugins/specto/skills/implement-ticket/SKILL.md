---
name: implement-ticket
description: Use when implementing a single tracker ticket end-to-end. Triggers on "implement APP-1234", "tackle this ticket", "build out [TICKET-KEY]". For a one-off "I have changes, ship them" MR with no ticket, use create-mr instead.
---

# implement-ticket

Implement one tracker ticket as a **spec-traceable** change: the linked spec section is the rubric, the ticket AC is the checklist. The shape is **explore → plan → implement**: fan out read-only subagents to understand the code, turn that into a TDD plan, then execute it through delegated subagents. Open a **draft** MR, fix the pipeline if it breaks, and flip to ready only once it's green **and** passes the Definition-of-Done check.

All tracker/forge side effects go through the vetted helpers under `${CLAUDE_PLUGIN_ROOT}/scripts/{tracker,forge}/` — never inline the tracker/forge CLIs (`acli`/`glab`/`gh`). Helper exit codes: `0` ok · `1` data missing · `2` bad usage · `3` external-command failure; warnings land on stderr.

VCS is up to you: the branch/worktree/commit/push steps below work whether the repo is jj or plain git — translate to whichever the repo uses. The skill never restructures the repo.

**Invocation.** This skill is intentionally model-invocable (no `disable-model-invocation`) so a spec → plan → tickets → implement flow can hand off to it automatically. Its safety gate is structural rather than a confirmation prompt: all work happens in an isolated `.worktrees/<key>/` worktree off trunk (never the user's tree), the MR opens as a **draft**, and the pipeline-fix loop is bounded (~3 attempts) before it stops and surfaces to a human.

## Prerequisites

- `acli` and the forge CLI (`glab`/`gh`) on PATH (`command -v`); abort with an auth reminder if either is missing.
- The repo is a git or jj repo. If neither, **stop** — this skill never initializes one.
- These superpowers skills available: `writing-plans`, `subagent-driven-development`, `dispatching-parallel-agents`, `test-driven-development`, `verification-before-completion`.

## Input

- **Ticket key** (e.g. `APP-3175`). Required; ask if not supplied.
- **`--resolve-comments`** (optional flag). Off by default — the skill ends at MR-ready (step 11) and stops for human review. When supplied, it arms the post-ready review-feedback watch (step 12): once the MR is ready, a `/loop` watch checks for new reviewer threads and hands them to `resolve-mr-comments`, exiting when the MR is merged, closed, or flipped back to draft. Use it for a longer autonomous flow where you want the skill to keep handling reviewer comments past MR-ready.

## Steps

0. **Resume check.** Before touching VCS, look for prior work on this ticket: a `.worktrees/<key>/` dir (key lowercased), a local `f-<slug>` branch, an existing MR (`scripts/forge/mr-fetch.sh info --branch f-<slug>`), or a `.specto/impl-<key>.md` plan. If any exist, **resume** from where the last run stopped — re-enter the worktree, reuse the plan, skip setup, don't re-commit committed work. Otherwise continue.

1. **Read the ticket.** `scripts/tracker/get-ticket-description.sh <KEY>` → description as Markdown. Pull the body, the acceptance-criteria list, and the spec link (the `plan-to-tickets` convention writes `Spec section: <link>`). No spec link → ask which spec the ticket belongs to. **Read that spec section — it's the source of truth.**

2. **Isolate the work.** First `git fetch origin <trunk>` (or `jj git fetch -b <trunk>` for jj) so the new worktree starts from **the freshest remote tip**, not a stale local trunk. Then create a new branch `f-<kebab-slug>` off `origin/<trunk>` (don't hardcode `main` — detect the trunk) and an isolated worktree at `.worktrees/<key>/` (key lowercased), so a parallel run can't collide with the user's tree. Slug ≤ ~20 chars, from the ticket title, **no ticket key** — e.g. "Add storage-model migration" → `f-storage-migration`. Never commit on trunk.

3. **Ticket → In Progress.** `scripts/tracker/assign-ticket.sh <KEY> @me` then `scripts/tracker/transition-ticket.sh <KEY> "In Progress"`. A transition that finds no matching status **warns and continues** — never fail the skill over it.

4. **Explore (parallel, read-only).** Dispatch `Explore` subagents — concurrently, in one message — to map the code this ticket touches: which modules/files own the behaviour, the patterns and tests to imitate, the seams to change. For each directory the ticket will touch, also run `"${CLAUDE_PLUGIN_ROOT}/scripts/conventions/nearest-agents-md.sh" <dir>` and read **every** file it lists (cumulative; nearest wins on conflict) — these conventions are binding on the implementation. Pure reads, so fan-out is always safe; size the count to the ticket (one probe per distinct subsystem). Also surface existing **reuse points** for the planner — test-data generators, shared management commands (e.g. `refresh_governed_task_profiles`), and shared helpers — so the implementer reaches for them before writing new code. **Scale to the ticket: a trivial one-file change skips explore + plan and goes straight to step 6's TDD.** Collect the findings — conventions and reuse points included — for the planner.

5. **Plan.** Invoke `superpowers:writing-plans` against the spec section + AC + exploration findings to produce bite-sized TDD tasks with a file map. **Save the plan to `.specto/impl-<key>.md`** (key lowercased) — this is a *local, gitignored* artifact like `plan-from-spec`'s `.specto/plan.md`; it never goes in the commit or the MR. This is a *per-ticket* implementation plan, finer-grained than `plan-from-spec`'s epic plan. Carry the discovered `AGENTS.md`/`CLAUDE.md` conventions — and step 6's code-comment discipline — into the plan so delegated subagents inherit them. **When the ticket adds or changes an API endpoint, the plan MUST include an e2e test task exercising that endpoint end-to-end** — carried into delegated subagents the same way (dod-check flags its absence). In the plan, **mark which task groups are independent** (touch disjoint files, no shared state) — step 6 uses that.

6. **Implement.** Each task is TDD: a failing test first, then the code that passes it; stay scoped to the AC (out-of-scope changes → follow-up ticket). The implementation — and any subagent you delegate it to — **follows the nearest `AGENTS.md`/`CLAUDE.md` conventions** discovered in step 4, unless the linked spec's §6 documents a deliberate divergence (then the spec wins).

   **Code-comment discipline** — binding on this session and every delegated subagent: write a comment only where the code can't show a constraint (a non-obvious invariant, an external quirk, a deliberate divergence), and match the surrounding file's comment density — most code needs no comment at all. No `WHY:`/`HOW:`-style label prefixes; rationale reads as plain prose. **Never reference the spec sheet, spec sections, or the ticket in code comments** — spec traceability lives in the commit body (step 8) and the MR description, where the link actually resolves; a code comment must stand alone for a reader who doesn't have the MR.
   - **Trivial ticket (explore + plan skipped):** there's no plan to delegate — do the TDD inline in this session with `superpowers:test-driven-development`. No subagents.
   - **Default — `superpowers:subagent-driven-development`:** fresh subagent per task, two-stage review (spec compliance, then code quality) after each, continuous execution. Tasks within one ticket usually share files, so this serial path is the norm.
   - **Only if step 5 flagged genuinely independent groups — `superpowers:dispatching-parallel-agents`:** give each group its own worktree (per `superpowers:using-git-worktrees`, or jj workspaces on jj repos) so concurrent edits can't collide, run each group's tasks, then merge the groups back into the ticket branch. If groups aren't cleanly disjoint, don't force it — stay serial.

7. **Verify.** Invoke `superpowers:verification-before-completion` on the whole change: test suite, repo linters, type checker if applicable. Don't proceed until clean. Then dispatch the `specto:test-critic` agent on the result — pass `branch_diff`, `spec_path`, `ticket_key` (and `test_paths` if known) — for an adversarial edge-case coverage audit: a green suite proves the tests pass, not that the right tests exist. Route its findings: an in-scope `✗` (the AC implies the case) → back to step 6, add the failing test first; an out-of-scope `✗` → follow-up ticket per the scope rule; `?` → surface to the user. The MR stays draft until the in-scope `✗` list is empty or each is explicitly justified in the MR description. Skip the dispatch for docs/config-only diffs — there's no behaviour to audit.

7b. **Reconcile discoveries into the spec + ticket (checkpoint, not automation).** Implementation often surfaces something the spec didn't foresee — a design decision that turned out wrong, a new constraint, an approach that diverged from §2. Before committing, ask yourself: *did anything I learned invalidate a spec decision or the ticket's AC?* If yes, decide with the user — **amend the implementation** (bring it back in line with the spec) **or amend the spec** (the discovery is right, the spec was wrong). When amending the spec: update the relevant `engineering-spec.md` (or `product-spec.md`) section now so it doesn't silently go stale, update the ticket's AC to match, and **investigate downstream impact** — other tickets whose AC depends on the changed decision (match by their `> Spec section:` link; flag them for a `plan-to-tickets` dry-run re-sync). For a broad after-the-fact drift pass across a whole shipped epic, use the `reconcile-spec` skill instead — this checkpoint is the per-ticket, in-the-moment version. Skip when the ticket introduced no such discovery.

8. **Commit.** Subject: `implement: <KEY> — <ticket title>` (literal em-dash). Body:
   - **Why** — one line tying the change to the spec section.
   - **Scope** — what's in, what's deliberately out.
   - **Spec link** — heading anchor (see rule below).
   - trailer: `Co-Authored-By: Claude <noreply@anthropic.com>`

9. **Push, open the draft MR.** Push the branch, then render `${CLAUDE_PLUGIN_ROOT}/references/mr-description-template.md` (substitute `{{ticket_key}}`, `{{ticket_title}}`, `{{ticket_url}}`, `{{summary}}`, `{{test_plan}}`, `{{spec_anchor_url}}`, `{{acceptance_criteria}}`) and pass it to `scripts/forge/create-mr.sh "[<KEY>] <ticket title>" <rendered-file|->`. It's `--draft` internally and idempotent (updates the branch's MR, never duplicates). Title is exactly `[<KEY>] <ticket title>` — no `[WIP]`. **Reviewers:** `--reviewer @me` by default, or each entry of `.specto/config.yml`'s `reviewers:` list if present. **Assignee:** the helper defaults `--assignee @me` when no `--assignee` flag is passed, so the implementer owns the MR — pass `--assignee <user>` explicitly to override. Then `scripts/tracker/transition-ticket.sh <KEY> "In Review"` (warn-and-continue).

10. **Pipeline loop.** Poll `scripts/forge/pipeline-status.sh` (parse **line by line**, not JSON — first line is `running`/`success`/`failed`/`none`):
    - `running` → wait, re-poll.
    - `success` / `none` → step 11.
    - `failed` → for each failed job id (lines after `---`), `scripts/forge/job-trace.sh <job-id>` for the tail, diagnose, fix, commit, push, re-poll.
    - **Bounded: ~3 fix attempts.** Still failing → step 12.

11. **Flip to ready.** Once the pipeline is green, consider `/compact` (or a fresh session) before the DoD + MR phases — the explore/implement transcript is rarely needed downstream. When the pipeline is green **and** DoD passes — invoke `dod-check` in `ticket-level` mode (epic checklist + non-standard-change controls, distinct from step 6's per-task review) — run `scripts/forge/mr-ready.sh`. DoD flags something fixable here → fix it (back to step 6); out of scope → step 13.

12. **Arm review-feedback watch — only when `--resolve-comments` was supplied.** Default (no flag): skip this; the skill is done at step 11 and stops for human review, preserving the human gate. With the flag, consider starting fresh (`/compact`) before this long-running comment loop. Now that the MR is ready, invoke the `loop` skill (Claude Code's `/loop`) with a self-paced prompt that checks the MR for new unresolved reviewer threads, hands any new ones to `resolve-mr-comments`, and exits when the MR is merged, closed, or flipped back to draft. The loop arms a Monitor in the background and wakes on new threads or merge, so the implementer needn't manually re-trigger comment checks. Skip this step on the step 13 escape-hatch path (a draft MR doesn't draw drive-by review; revisit once it's ready).

13. **Escape hatch.** If pre-flight or the pipeline-fix loop keeps failing past the bound, **don't spin**: leave the MR draft, update its description (re-run `create-mr.sh` with an amended body) noting what failed and what was tried, and **stop** for a human.

## Rules easy to get wrong

- **Explore + plan scale to the ticket** — don't fan out four explorers and write a plan for a 3-line fix; go straight to TDD.
- **The per-ticket plan stays local** (`.specto/impl-<key>.md`, gitignored) — never commit it or put it in the MR.
- **Follow the nearest `AGENTS.md`/`CLAUDE.md` before writing code.** Run `"${CLAUDE_PLUGIN_ROOT}/scripts/conventions/nearest-agents-md.sh"` on each directory you change, read every file it lists, and conform (e.g. per-tenant config goes in `feature_flags` JSON as `FeatureFlag(...)`, not a new DB column) — and propagate them to delegated subagents — unless the linked spec's §6 documents the divergence.
- **Parallelize implementation only on disjoint task groups, each in its own worktree.** Shared files → stay serial. When in doubt, serial.
- **Branch `f-<slug>`, ≤ ~20 chars, no ticket key** — the MR title carries `[<KEY>]`. No `[WIP]`.
- **Spec links are heading anchors** (`…/engineering-spec.md#23-storage-model`), **never** line anchors (`#L115`) — line anchors rot on every spec edit.
- **MR stays draft until pipeline green AND DoD passes**, then `mr-ready.sh`.
- **Scope to the AC.** Out-of-scope changes → follow-up ticket.

This skill is **rigid**: violating the letter of these rules is violating their spirit. "Out of scope" means a follow-up ticket, not a quiet extra commit; "draft until green" means draft, not "ready — I'll fix the pipeline after". Use TodoWrite to track the numbered steps above (one todo per step) so none is silently skipped.

### Red flags — stop if you catch yourself thinking:

| Rationalization | Reality |
|---|---|
| "This change is tiny, I'll skip the failing test." | Every AC line gets a failing test first. No exceptions. |
| "I'll just commit on trunk this once." | Always branch + worktree — trunk commits collide with the user's tree. |
| "The pipeline's almost green, I'll flip to ready now." | Draft until pipeline green **and** DoD passes. |
| "This adjacent fix is basically in scope." | Out-of-scope → follow-up ticket, not this MR. |
| "It's failed a few times but the next fix will land." | Bounded ~3 attempts, then leave draft + explain + stop. |
| "Tests are green so coverage is fine." | Green proves the tests pass, not that the right tests exist — step 7's test-critic audit must come back clean (or each gap justified) before ready. |
| "The endpoint's covered, the unit tests are green." | A changed endpoint needs an e2e test exercising it end-to-end; a green unit suite isn't endpoint coverage (dod-check flags its absence). |
| "A WHY: comment tying this line to spec §2.3 helps the reviewer." | In code that's a dead reference — no spec link resolves there. Spec traceability goes in the commit/MR; comment only what the code can't say, no label prefixes. |
| "MR is ready — I'll keep watching for comments." | Only if `--resolve-comments` was passed (step 12 arms the `/loop` watch). Otherwise stop at ready; the human drives review. |
| "The local trunk is probably fresh enough." | Step 2 starts with `git fetch origin <trunk>`. Worktree off `origin/<trunk>`, not stale local trunk. |
| "I'll keep the full transcript, it's fine." | Cache-read re-bills the whole transcript every turn — `/compact` at phase boundaries. |

## When NOT to run

- A multi-ticket sweep — one ticket per invocation; loop manually.
- A ticket with no AC and no spec link — have the user populate them first.
- **Post-merge cleanup** (transition `<KEY>` → `Done`, remove `.worktrees/<key>/`, delete `.specto/impl-<key>.md`) — out of scope; no post-merge hook exists yet. Frame it as a manual follow-up.
