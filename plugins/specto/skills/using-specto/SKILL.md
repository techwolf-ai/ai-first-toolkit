---
name: using-specto
description: Use when starting work on an in-repo product or engineering spec, when invoking Specto's skills (new-spec, review-spec, plan-from-spec, etc.), or when the user mentions "specto", "spec sheet", "product spec", "engineering spec" in the context of an in-repo spec workflow. Establishes how Specto's skills compose with superpower skills.
---

# Using Specto

Specto is the spec-to-implementation workflow plugin. It treats the repository as the single source of truth for planning context and orchestrates writing, reviewing, planning, ticketing, and implementing through a fixed sequence of skills.

Not configured yet? Run `/specto:setup` first — it doctor-checks dependencies, picks your forge and tracker, and writes `.specto/config.yml`.

## Terminology

**MR** is Specto's generic term for a change-request; the forge renders it natively — a merge request (`!42`) on GitLab, a pull request (`#42`) on GitHub. **The forge** is the code-hosting backend (GitLab or GitHub), and **the tracker** is the work-item backend (Jira, Linear, or GitHub Issues). Both are selected per repo by config or autodetect (see `docs/contracts.md`). Skill prose says "MR", "the forge", and "the tracker"; the vetted helpers under `scripts/forge/` and `scripts/tracker/` dispatch to whichever backend is configured.

## Prerequisite

Specto requires the superpowers plugin. If not installed, ask the user to install it before invoking any Specto skill that delegates to a superpower (most do).

## Composing with superpowers

Specto orchestrates; superpowers do the disciplined work. When intent, scope, or requirements are unclear at any step — not only at `new-spec` — stop and run `superpowers:brainstorming` to align with the user before drafting, editing, or planning. Don't guess your way through an ambiguous spec.

## Spec convention Specto reads and writes

```text
docs/development/specs/<YYYY-MM-DD-slug>/
├── product-spec.md              (mandatory)
├── engineering-spec.md          (optional, gated on product-spec approval)
├── .specto-meta.yml             (linked epic + classification, written by new-spec)
├── v2-candidates.md             (deferred V2 scope from resolve-spec-comments)
└── context/
    ├── raw/                     (PRDs, Slack dumps, prior art)
    └── compiled/                (synthesised analyses)

.specto/
├── config.yml                   (notion_okr_page_id, jira_project_key, default_dod_checklist)
├── okrs.md                       (Notion-fallback OKR snapshot)
├── plugin-feedback.md           (local plugin-friction scratch from plugin-feedback; gitignored)
└── plan.md                      (transient, gitignored)
```

The slug uses today's date prefix to avoid merge conflicts on monotonic numbering. Examples: `2026-04-23-contact-dedup/`, `2026-05-12-org-redesign/`.

## The 8-step flow

1. **Gather** raw sources into `context/raw/` via `add-raw-context`.
2. **Synthesize** them into `context/compiled/` via `synthesize-context`.
3. **Product spec.** Draft `product-spec.md` via `new-spec`.
4. **Engineering spec.** Draft `engineering-spec.md` via `new-spec --add-engineering` once the product spec is approved. Required before planning — `plan-from-spec` reads it and aborts without it.
5. **Plan.** Generate `.specto/plan.md` from `engineering-spec.md` via `plan-from-spec`. The plan is transient; never commit it.
6. **Split.** Translate the plan into tracker tickets via `plan-to-tickets`. Each ticket links back to its spec section.
7. **Code.** Implement a single ticket via `implement-ticket`.
8. **Review.** Gate the MR before a human sees it: `review-mr` for the agent review panel, `dod-check` for the Definition-of-Done verdict.

Stakeholder feedback during steps 3 and 4 is handled by `resolve-spec-comments`.

## Skills inventory

| Skill | Purpose |
|---|---|
| `using-specto` | This skill. Entry point. |
| `setup` | Interactive onboarding: doctor-check dependencies, pick forge + tracker, write config. |
| `new-spec` | Brainstorm intent, scaffold spec folder, draft product-spec.md. |
| `new-spec --add-engineering` | Draft engineering-spec.md gated on product-spec approval. |
| `review-spec` | Lint pre-pass + parallel reviewer agents on product- or engineering-spec. |
| `add-raw-context` | Pull URL/Notion/Slack/Drive into `context/raw/`. |
| `synthesize-context` | Worker subagents produce `context/compiled/`. |
| `plan-from-spec` | `superpowers:writing-plans` against engineering-spec.md. |
| `plan-to-tickets` | Plan to tracker tickets with spec-section links. |
| `implement-ticket` | Implement a single ticket, scope-anchored to acceptance criteria. |
| `implement-milestone` | Implement a whole milestone: its tickets in dependency order, shared context, human test gate. |
| `verify-milestone` | Run the suite + verify every milestone AC is met and covered; emit a verdict. |
| `run-epic` | Loop `implement-milestone` across an epic's milestones with a gate between each. |
| `review-mr` | Parallel review agents on a code MR: scope vs ticket, spec drift, code quality. |
| `mr-walkthrough` | Reviewer-oriented walkthrough comment on an MR: what changed, why, where to look. |
| `dod-check` | Branch vs DoD checklist + ticket acceptance criteria. |
| `resolve-spec-comments` | Cluster, classify, and produce a revision plan for unresolved spec MR threads. |
| `reconcile-spec` | Diff a shipped spec against merged code and propose a rewrite to reality (advisory). |
| `create-mr` | Idempotent draft MR from current changes; links to a tracker ticket (existing or new). |
| `create-ticket` | Single Task/Bug/Story with sprint placement + optional epic; bug Impact + Priority. |
| `create-test-plan` | Paired Test Plan ticket linked to a non-standard implementation ticket via `Relates` (tenant profiles can override the link type). |
| `resolve-mr-comments` | Code-MR sibling of `resolve-spec-comments`: plans + implements fixes, replies + resolves. |
| `plugin-feedback` | Capture plugin-skill friction to `.specto/plugin-feedback.md`; drain it into forge work items. |

The lint pre-pass library lives at `<plugin-root>/scripts/lint/` and runs deterministic checks (em-dashes, emoji codes, metadata rows, metric count) before any model-driven review.

## Every authoring skill has an independent quality reviewer (#52)

Specto never lets a skill grade its own homework — each thing you *author* has a separate agent whose only job is to check it:

| You author with | An independent reviewer checks it |
|---|---|
| `new-spec` (product/eng spec) | `review-spec` → `product-review` / `eng-review` / `scope-review` / `okr-alignment-review` / `change-classification-review` |
| `implement-ticket` (code) | `review-mr` → `code-mr-review`, plus the `test-critic` edge-case audit at the Verify step |
| `implement-ticket` (tests) | `test-critic` (adversarial coverage audit — green suite ≠ right tests) |
| a branch vs Definition-of-Done | `dod-check` → `dod` |

If you add a new authoring skill, it must come with its reviewer — and the review must be *visible* (a report, not a silent pass). The lint pre-pass gates structure deterministically before any of these model reviewers run.

## Plugin feedback loop

While using any `specto:*` skill, watch for friction — a skill not prompting for an obvious follow-up, misclassifying, hitting a missing case, or stopping short of what the workflow needs. When you notice it, surface it and offer to capture it: `plugin-feedback --capture "<one-liner>"` appends a dated entry to `.specto/plugin-feedback.md` without breaking your flow. At a natural break (or when the user asks), `plugin-feedback --drain` walks the pending entries and files the chosen ones as forge work items on the plugin repo. The `plugin-feedback` skill owns the capture-file format and the filing path — this loop lives in the plugin, not in personal memory.

## References

- `docs/contracts.md`: cross-cutting contracts Specto agents follow. Notably the meta-vs-live contract — `.specto-meta.yml` is a scaffold-time snapshot, not a source of truth, so any agent reasoning about live tracker/forge state must re-fetch and may warn on drift.
- `references/product-spec-guidelines.md`: rubric for product-spec writing and review.
- `references/engineering-spec-guidelines.md`: rubric for engineering-spec writing and review.
- `references/exemplars/duplicate-detection/product-spec.md`: a high-quality reference spec to imitate.
- `templates/product-spec.md`: starter template for `docs/development/specs/<slug>/product-spec.md`.
- `templates/engineering-spec.md`: starter template for engineering-spec.
