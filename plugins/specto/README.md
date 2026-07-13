# Specto — specs reviewed like code

In-repo product and engineering specs, approved through MR/PR review by an agent panel, then driven to shipped code through tickets with scope discipline and a Definition-of-Done gate.

Spec Kit gives you specs. Specto gives you spec review.

## What makes it different

- **Specs reviewed like code.** Every spec ships as an MR/PR with a named owner and a review record. An agent panel (product, scope, OKR-alignment, engineering, change-classification) reviews it in parallel, posting idempotent findings that converge instead of duplicating.
- **Real tracker integration.** Plan-to-tickets and ticket-to-code against Jira, Linear, or GitHub Issues — spec-section permalinks on every ticket, dependency edges, sprint placement, status transitions.
- **Independent validation.** The agent that grades the work is never the agent that did it: a separate DoD agent composes five Definition-of-Done sources (epic checklist, team defaults, ticket AC, compliance controls, nearest repo conventions) and reports gaps by source. An adversarial test-critic audits edge-case coverage.
- **Scope discipline.** Tickets carry acceptance criteria and spec anchors; the code review asks "did this MR do only what the ticket said?" and flags drift against the spec.
- **Lean, brownfield-first specs.** Skeletal templates, hard length caps, a "what does NOT belong" table, and lint that blocks bloat. Specs are short-loop, MR-reviewed deltas — feedback in minutes, not frozen phase gates.
- **Zero telemetry.** Specto never phones home — no analytics, no tracking, nothing to opt out of.
- **Your stack.** Forge: GitLab or GitHub (auto-detected from the remote). Tracker: Jira, Linear, or GitHub Issues. VCS: git by default, jj auto-detected. Compliance: bring-your-own change-classification profile, off by default.

## Requirements

| Concern | Tool | Notes |
|---|---|---|
| Shell | bash, jq, git, curl | ubuntu/macOS defaults; Windows via Git Bash or WSL |
| Forge | `glab` (GitLab) or `gh` (GitHub) | authenticated (`glab auth login` / `gh auth login`) |
| Tracker | `acli` (Jira), `LINEAR_API_KEY` (Linear), or `gh` (GitHub Issues) | pick one per repo |
| Prerequisite plugin | [superpowers](https://github.com/obra/superpowers) | Specto invokes its `brainstorming`, `writing-plans`, `test-driven-development`, `subagent-driven-development`, `using-git-worktrees`, `verification-before-completion`, and `dispatching-parallel-agents` skills |

## Install

```text
claude plugin marketplace add techwolf-ai/ai-first-toolkit
claude plugin install specto@techwolf-ai-first
```

## Spec convention in your repo

Specto reads and writes this layout:

```text
docs/development/specs/<YYYY-MM-DD-slug>/
├── product-spec.md
├── engineering-spec.md          (optional)
├── v2-candidates.md             (deferred V2 scope from resolve-spec-comments)
└── context/
    ├── raw/
    └── compiled/

.specto/
├── config.yml                   (tracker project key, default DoD checklist, OKR source, backend overrides, optional compliance profile)
├── tracker-jira.yml             (optional Jira tenant profile: site, field/option ids)
├── okrs.md                      (optional markdown OKR snapshot)
└── plan.md                      (transient, gitignored)
```

`new-spec` scaffolds `.specto/` with a `.gitignore` that keeps the transient files local.

## The flow

1. `new-spec` — scaffold + brainstorm + agent-drafted product/engineering spec.
2. `add-raw-context` / `synthesize-context` — pull sources in, compile them with citations.
3. `review-spec` — lint pre-pass, then the reviewer panel on the spec MR/PR.
4. `resolve-spec-comments` — cluster and triage review threads into a revision plan.
5. `plan-from-spec` / `plan-to-tickets` — plan, then a ticket stack under the epic.
6. `implement-ticket` — worktree isolation, TDD, draft MR/PR, pipeline watch, DoD gate.
7. `review-mr` / `resolve-mr-comments` — spec-anchored code review and thread resolution.
8. `dod-check` — Definition-of-Done verification, per ticket or across the epic.

Standalone helpers work outside the spec flow too: `create-mr`, `create-ticket`, `create-test-plan`, `mr-walkthrough`, `plugin-feedback`.

## Documentation

See `docs/walkthrough.md` for the end-to-end usage guide: setup, prerequisites, the 8-step spec-to-implementation flow, common variants, and the full skill/agent/hook reference. `docs/contracts.md` and `docs/adapter-contract.md` document the helper-script contracts and the backend adapter layer. CI lint-gate examples for GitLab CI and GitHub Actions live in `references/ci/`.
