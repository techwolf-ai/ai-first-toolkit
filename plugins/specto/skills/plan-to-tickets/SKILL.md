---
name: plan-to-tickets
description: Use after `.specto/plan.md` exists and the team is ready to commit work to the tracker. Triggers on "create the tickets", "plan to tickets", "create Jira tickets from the plan", "make tickets from the plan".
---

# plan-to-tickets

Translate `.specto/plan.md` into tracker tickets. Each ticket gets the engineering-spec section as a description prefix, the plan task's acceptance criteria as the body, and `Blocks` / `BlockedBy` edges from plan dependencies. Tickets are created under the linked epic (read from `<spec_folder>/.specto-meta.yml`), each is assigned and added to the active sprint, and the epic is transitioned to In Progress with a summary comment listing the new children.

**Invocation.** This skill is intentionally model-invocable (no `disable-model-invocation`) so it can follow `plan-from-spec` in a spec → plan → tickets flow. Its safety gate is **dry-run by default**: the first invocation lists the tickets it would create (summary table, zero Jira writes) and only creates them for real after the user confirms.

## Prerequisite check

- **Preflight:** run `scripts/doctor.sh` first — it fails loud on any missing CLI, auth, or required Jira config (`jira_project`, `jira_board_id`) so ticket creation never stops silently mid-flow. The specific checks below are what it verifies.
- `.specto/plan.md` exists in the repo root.
- A linked spec folder is identifiable (either the user names it, or the most-recently-edited `engineering-spec.md` in `docs/development/specs/`).
- `<spec_folder>/.specto-meta.yml` has a non-empty `epic:` value. If absent, abort with the fix snippet (don't just say "go fix it"):
  ```bash
  cat > <spec_folder>/.specto-meta.yml <<EOF
  epic: PROJ-1234
  EOF
  ```
- `.specto/config.yml` has a `jira_project_key:` value. If absent:
  ```bash
  mkdir -p .specto && printf 'jira_project_key: PROJ\n' > .specto/config.yml
  ```
- `acli` on PATH **and** authenticated (`acli jira auth status` → ✓). Abort with `acli jira auth login` if not.
- `python3` on PATH — the Jira helpers auto-convert Markdown bodies to ADF; without it, descriptions render as literal `**`/`#`/backticks in Jira.

## Inputs the user provides

- **Spec folder** (defaulted from pwd or recent edits, asked if ambiguous).
- **Dry-run flag.** Default to dry-run on the first invocation: list the tickets that would be created, summary table, no tracker calls. Confirm with the user before creating for real.

## Steps

1. **Resolve spec folder + epic key + classification** from `.specto-meta.yml`. Note: `.specto-meta.yml` is a scaffold-time snapshot, not source of truth — the agent re-fetches the live epic at create time and warns on drift (see `docs/contracts.md`).
2. **Read `.specto/plan.md`** (the plan from `plan-from-spec`).
3. **Read `<spec_folder>/engineering-spec.md`** (for §-anchor links and AC mapping).
4. **Dispatch the `plan-to-tickets` agent** via the Task tool with `subagent_type="specto:plan-to-tickets"`. Inputs in the prompt:
   - `plan_path`: absolute path to `.specto/plan.md`.
   - `spec_path`: absolute path to `engineering-spec.md`.
   - `clarifications_path`: absolute path to `<spec_folder>/context/compiled/clarifications.md` if it exists (resolved decisions the plan may predate).
   - `epic_key`: the epic key from `.specto-meta.yml`.
   - `meta_classification`: the `classification` value from `.specto-meta.yml` (may be empty) — the agent compares the live epic against it.
   - `dry_run`: `true` on first invocation; `false` after user confirms.
   - `jira_project_key`: from `.specto/config.yml`'s `jira_project_key` field.
5. **Aggregate the agent's output** — list of created (or would-be-created) ticket keys, summary table, the epic transition + comment status. **Recommended next step (after a real create): run `dod-check --mode=epic-creation`** to verify every DoD checklist item has a corresponding child ticket before implementation starts — this is the coverage gate that mode exists for. Then `implement-ticket <KEY>` per ticket.

## Hard rules

- **Task type only.** This flow creates `Task`-type work items — no Bug type, no priority/impact fields. Users who need a bug filed do it by hand.
- **Always dry-run first.** Don't create tracker tickets without showing the user what would be created.
- **MR-sized tickets, not one-per-plan-line.** Default one ticket per plan task, but **merge trivially-small same-theme tasks** into a single MR-sized ticket (each becomes its own AC line / `### <task>` sub-heading, so AC granularity is preserved) and merge the implement+test adjacent pair. Split a task only if it is too large for one MR. The dry-run lists every merge/bundle for explicit review and the author can veto any grouping before live creation — MR overhead, not ticket count, is the cost to minimise.
- **Tickets carry the final, iterated spec.** The agent reconciles each ticket's AC against the *current* `engineering-spec.md` + `clarifications.md`, not a stale plan, so implementation doesn't re-litigate settled decisions. If the spec changed **after** tickets already exist, re-run in dry-run: the agent matches existing tickets by their spec-section link and flags which AC drifted, then offers to update just those — the tracker never silently goes stale against the spec.
- **Spec-section link in description.** Each ticket's description starts with `> Spec section: <git-permalink>#<heading-anchor>` so reviewers can trace the AC back to its source.
- **No inline `acli`.** Ticket creation, linking, assignment, sprint placement, the epic transition, and the epic comment all go through helpers under `scripts/tracker/`. Sprint placement is best-effort: `add-to-sprint.sh` calls the Jira Agile REST API (`POST /rest/agile/1.0/sprint/<id>/issue`) and needs `JIRA_EMAIL` + `JIRA_API_TOKEN` (each may be a literal value or an `op://<vault>/<item>/<field>` 1Password reference); without them the helper warns and the ticket lands in the backlog.

## When this skill should NOT run

- No `.specto/plan.md`: invoke `plan-from-spec` first.
- The user wants to update existing tickets after spec edits: this skill creates new tickets, doesn't update; use `resolve-spec-comments` for impact-flagging.
