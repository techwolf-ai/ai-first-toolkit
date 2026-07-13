---
name: run-epic
description: Use to work a whole epic autonomously in the right order — hand specto an epic and it walks its milestones in dependency order, implementing each and pausing for you to test between them. Triggers on "run the epic", "do the whole epic", "work through APP-1234's milestones", "run-epic". A thin loop over implement-milestone with a human test gate between milestones; it never merges or skips the gate.
---

# run-epic

The one-shot entry point for "resolve this epic". It orders the epic's milestones by dependency and runs `implement-milestone` for each, stopping at the human test gate between them. It adds no new implementation logic — it is the loop that saves you from hand-sequencing milestones.

## Inputs the skill resolves

- **Epic key** — from the user or `.specto-meta.yml`.
- **Milestones** — the distinct `specto:milestone-<n>` labels across the epic's tickets, and the cross-milestone dependency order (a milestone is ready when every milestone it depends on has a `pass` verdict).
- **Track success criteria (#53)** — optional whole-track acceptance the author supplies up front (or `.specto/track-criteria.md`); checked at the end against the finished whole, since per-milestone `pass` can still miss the track's intent.

## Steps

1. **Preflight + map.** Run `scripts/doctor.sh`. List the epic's milestones, their tickets, and the milestone dependency order. Print the plan and the (optional) track success criteria. Abort on a dependency cycle.
2. **Loop milestones in order.** For each milestone: run `implement-milestone M<n>`. It ends at its own human test gate with a `verify-milestone` verdict.
3. **Gate between milestones.** After each milestone, **stop** and surface the increment + verdict for manual testing. Only continue to the next milestone on the author's go-ahead (or an explicit `--no-gate` the author sets to run unattended, at their own risk). This is the deliberate human checkpoint — autonomy at milestone granularity, not a merge bot.
4. **Track-level verification (#53).** When the last milestone passes, verify the finished whole against the track success criteria (if supplied): each criterion met + evidence. Report any the assembled milestones missed — the gap per-milestone DoD cannot catch.
5. **Summarise.** Milestones completed, each verdict, the track-criteria result, and what remains (unmerged MRs, deferred follow-ups). Merging stays a human action — this skill never merges.

## Hard rules

- **Thin loop.** No implementation or verification logic of its own — `implement-milestone` and `verify-milestone` do the work; this orders and gates.
- **Human gate by default.** Stop between milestones unless the author explicitly opts out. Never merge.
- **Dependency order or stop.** Cycles and unmet cross-milestone dependencies are hard stops.

## When this skill should NOT run

- For a single milestone (`implement-milestone`) or ticket (`implement-ticket`).
- When the epic's milestones aren't labelled yet — run `plan-to-tickets` first so tickets carry `specto:milestone-<n>`.
