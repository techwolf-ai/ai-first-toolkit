---
name: implement-milestone
description: Use to implement a whole milestone end-to-end, not just one ticket — the mid-granularity unit between implement-ticket and a full epic. Triggers on "implement M1", "build out milestone 2", "do the whole milestone", "implement-milestone". Works the milestone's tickets in dependency order on one increment, carries context ticket-to-ticket, reports progress on long runs, and closes by running verify-milestone and pausing at a human test gate before the next milestone.
---

# implement-milestone

The unit of autonomous work that is bigger than a ticket and smaller than an epic. It runs the milestone's tickets in dependency order, keeps what each ticket learned flowing to the next, and stops at a human-testable increment — so a long session stays visible and trustworthy instead of a silent multi-hour black box.

It composes existing skills: `implement-ticket` per ticket, `verify-milestone` at the end. It does not reimplement them.

## Inputs the skill resolves

- **Milestone id** `M<n>` — from the user, or the `specto:milestone-<n>` label shared by a set of the epic's tickets.
- **The milestone's tickets** — every open ticket carrying `specto:milestone-<n>`, with their `Blocks` / `BlockedBy` edges (read via `scripts/tracker/*`).
- **Spec + AC** — the milestone's `M<n>-AC*` / `M<n>-TAC*` in the linked specs (passed through to `verify-milestone`).

## Steps

1. **Preflight.** Run `scripts/doctor.sh` (fail loud on missing CLI/auth/config). Resolve the milestone's tickets and build their dependency order from `Blocks`/`BlockedBy` (topological; abort with the cycle if the graph has one).
2. **Announce the plan.** Print the ordered ticket list, the milestone AC, and the branch strategy (one milestone branch; each ticket is a commit or a stacked change on it). This is the "what I'm about to do" the author sees before a long run.
3. **Work each ticket in order.** For each ticket, invoke `implement-ticket <KEY>` — but **without** flipping to ready between tickets when they share the milestone branch; the milestone is the shippable unit, the tickets are its steps. Carry a running **milestone context note** (`.specto/milestone-<n>.md`, gitignored): decisions made, constraints discovered, helpers reused. Pass it into each subsequent `implement-ticket` so a discovery in ticket 1 reaches tickets 2..N — this is the fix for "later tickets lost the context of the first". When a ticket's implementation reshapes a spec decision, use `implement-ticket`'s step-7b findings→spec checkpoint (and flag downstream tickets).
4. **Report progress (long-run visibility, #49).** After each ticket (and periodically within a long one), print a one-line status: `current task / done N of M / remaining / roughly where`. Recommend `/compact` at ticket boundaries so the session stays affordable. The author can always see it's making progress, not stuck.
5. **Verify the milestone.** When all tickets are implemented, run `verify-milestone M<n>`. If `overall != pass`, route `uncovered_or_failed` AC back to the relevant ticket (step 3) — the milestone is not done until the verdict is `pass` or each gap is explicitly justified.
6. **Human test gate (#50).** With a green verdict, **stop** and hand off a testable increment: print how to run/exercise it, what changed, and the verify-milestone verdict. Do not start the next milestone. The author tests manually, then resumes (`run-epic` automates the between-milestone loop; on its own this skill ends here).

## Hard rules

- **Compose, don't reimplement.** Per-ticket work is `implement-ticket`; verification is `verify-milestone`; DoD is `dod-check`. This skill only orchestrates + carries context + gates.
- **Dependency order or stop.** Never work a ticket before its `BlockedBy` are done; a cycle is a hard stop, not a guess.
- **Milestone is the shippable unit.** One increment, one human test gate at the end — not a ready-flip per ticket (that would recreate the per-ticket-MR overhead the milestone unit exists to avoid).
- **Progress is visible.** Never run silently for long; emit the status line.

## When this skill should NOT run

- For a single ticket (`implement-ticket`).
- For a whole epic across milestones (`run-epic` — it loops this skill with the gate between each).
