---
name: plan-from-spec
description: Use after the engineering spec is approved and you're ready to break it into a transient implementation plan. Triggers on "plan from the spec", "make a plan", "write the implementation plan", "break this into tasks".
---

# plan-from-spec

Generate an implementation plan from an approved engineering spec. The output lives at `.specto/plan.md` and is transient (`.specto/` is gitignored). Re-run this skill after engineering-spec edits to regenerate; there is no spec-to-plan drift to manage.

## Prerequisite check

- An `engineering-spec.md` exists in a `docs/development/specs/<initiative>/` folder somewhere in the repo (or in pwd).
- `superpowers:writing-plans` is available.
- `.specto/` exists; if not, create it. Verify `.specto/plan.md` is in `.gitignore` (or that `.specto/` is); if not, warn the user.

## Inputs the user provides

- **Spec folder.** If pwd is inside a `docs/development/specs/<initiative>/`, default to that. Otherwise ask. The folder must contain `engineering-spec.md`.

## Steps

1. **Resolve the spec folder.** Default from pwd; ask if ambiguous.
2. **Verify `engineering-spec.md` exists** in the folder; abort if not, telling the user to draft it first via `new-spec --add-engineering`.
3. **Invoke `superpowers:writing-plans`** with the engineering spec as the input "spec or requirements" document. Pass the spec path explicitly so the writing-plans skill knows what it's planning from.
4. **Save to `.specto/plan.md`**, NOT to `docs/superpowers/plans/`. The plan is transient — gitignored, regenerable. Override the writing-plans default save location.
5. **Prepend a visual header** (per `references/visual-conventions.md`). At the top of `.specto/plan.md`, render:
   - a **dependency DAG** as a mermaid `flowchart TD` — one node per task (short id + title), one edge per Blocks/BlockedBy relationship the plan states (the same edges `plan-to-tickets` carries onto Jira). This makes the critical path and the parallelizable tasks visible before any ticket is cut. Skip it when the plan has a single task or no dependencies.
   - a **file map** as a fenced ` ```text ` tree of the paths the plan touches, when it touches ≥5 files.
   Derive both from the plan content only; do not invent edges or files. Validate the mermaid block parses before saving.
6. **Print a summary.** Number of tasks in the plan, whether a dependency DAG was rendered, file structure summary, recommended next step (typically *"run plan-to-tickets to translate this plan into Jira tickets"*).

## Hard rules

- **Plan is transient.** Never commit `.specto/plan.md`. The skill assumes the user's `.gitignore` excludes `.specto/`; warn if not.
- **Don't auto-sync.** If the engineering spec changes after the plan is generated, the user re-runs this skill — no automatic reconciliation.

## When this skill should NOT run

- Engineering spec doesn't exist yet: invoke `new-spec --add-engineering`.
- The user wants Jira tickets directly without a plan: skip this and invoke `plan-to-tickets` after manually drafting `.specto/plan.md`.
