---
name: create-ticket
description: Use when the user wants a single standalone tracker ticket created. Triggers on "create ticket", "create Jira ticket", "make a ticket", "log a bug", "create a task", "file a bug", "new ticket", "open a ticket", "create an issue", or when another skill (e.g. `create-mr`, `resolve-mr-comments`) needs a tracker ticket as part of its workflow. Supports Task / Bug / Story, optional epic, sprint placement, and bug-specific Impact + Priority fields via the vetted `scripts/tracker/create-ticket.sh` helper. For bulk ticket creation from a plan, use `plan-to-tickets` instead.
argument-hint: "<short description of the work>"
allowed-tools: Bash, Read, AskUserQuestion
---

# create-ticket

Create a single tracker ticket from a short description. Shells out to `${CLAUDE_PLUGIN_ROOT}/scripts/tracker/create-ticket.sh`, `${CLAUDE_PLUGIN_ROOT}/scripts/tracker/active-sprint.sh`, `${CLAUDE_PLUGIN_ROOT}/scripts/tracker/add-to-sprint.sh`, `${CLAUDE_PLUGIN_ROOT}/scripts/tracker/get-ticket-type.sh`, and `${CLAUDE_PLUGIN_ROOT}/scripts/tracker/link-tickets.sh`; reads/writes user defaults via `${CLAUDE_PLUGIN_ROOT}/scripts/plugin-config.sh`. Never inline `acli`. Exit codes propagated from the helpers: `0` ok · `2` bad usage · `3` external-command failure.

## Rendering pitfall: build ADF, not markdown

Some `acli` versions DO NOT render markdown in the ticket body when passed via `--description-file` — `### Heading`, `- bullet`, and `- [ ] checkbox` lines appear as **literal text** in Jira Cloud. To avoid that, this skill builds the description as an ADF document up front via `${CLAUDE_PLUGIN_ROOT}/references/ticket-description-adf-template.jq` and posts it via `--description-adf-file`. The same template-encoded invariant applies: every `taskItem.content` array holds inline runs directly, never wrapped in `paragraph` (acli rejects with `INVALID_INPUT`).

## Prerequisite check

- `acli` is on PATH and authenticated (`acli jira workitem view <known-key> --json` succeeds).
- The user has at minimum given a one-line "what should this ticket be about" — if not, ask before doing anything else.

## Inputs the user provides

- **Description of the work** (argument or first prompt). What kind of change is this, why, what's the goal.
- **Issue type** — Task (default), Bug, or Story. Ask if not obvious from the description.
- **Bug fields** (only if type = Bug): Impact and Priority. Default both to Low if unspecified.
- **Epic** (optional). Ask whether to link to an epic; if yes, take the epic key.
- **Sprint** placement happens automatically when `jira_board_id` is configured.

## Steps

### 1. Resolve persistent defaults

Use the plugin-config helper to avoid asking the user repeatedly:

```bash
JIRA_PROJECT="$("${CLAUDE_PLUGIN_ROOT}/scripts/plugin-config.sh" get jira_project 2>/dev/null || true)"
JIRA_BOARD_ID="$("${CLAUDE_PLUGIN_ROOT}/scripts/plugin-config.sh" get jira_board_id 2>/dev/null || true)"
```

- If `JIRA_PROJECT` is empty, ask the user which Jira project to use (`APP`, `PROJ`, etc.). After the user answers, store it:
  ```bash
  "${CLAUDE_PLUGIN_ROOT}/scripts/plugin-config.sh" set jira_project "<PROJECT>"
  ```
- If `JIRA_BOARD_ID` is empty, ask once for the Jira board id (numeric). Store it the same way. Skip sprint placement if the user can't supply one — the ticket lands in the backlog.

### 2. Determine the issue type

Ask the user (or accept from context):

- **Task** (default) — new work, implementation, improvement.
- **Bug** — something is broken or behaving incorrectly.
- **Story** — user-facing feature or capability.

### 3. Draft title + build the ADF description

From the user's input, produce:

- **Title.** Start with an action verb (Improve, Refactor, Fix, Harden, Simplify, Add). Keep specific and under 90 characters.
- **Description.** Build it as ADF from the start via the jq template. Sections:
  - `Context` — what is currently wrong or risky.
  - `Goal` — what should improve after this work.
  - `Scope` — what is included. Each item is a string OR `{title, body}` if a sub-heading helps.
  - `Out of scope` — what is explicitly NOT included. Pass `[]` to omit.
  - `Acceptance criteria` — taskItem checkboxes the reviewer ticks as they verify. Pass `[]` to omit.

If the input is too vague to produce a meaningful description, ask one clarification question before proceeding.

Render the ADF:

```bash
adf_tmp="$(mktemp -t ticket-adf.XXXXXX)"
jq -n \
  --arg     context "$CONTEXT" \
  --arg     goal    "$GOAL" \
  --argjson scope                "$SCOPE_JSON" \
  --argjson out_of_scope         "$OOS_JSON" \
  --argjson acceptance_criteria  "$AC_JSON" \
  -f "${CLAUDE_PLUGIN_ROOT}/references/ticket-description-adf-template.jq" \
  > "$adf_tmp"
```

Input shapes:

| Variable | Type | Example |
|---|---|---|
| `$CONTEXT` | string | `"The exports cron job times out for tenants with >50k jobs."` |
| `$GOAL` | string | `"Stream pages instead of loading everything; eliminate the timeout."` |
| `$SCOPE_JSON` | `[string \| {title, body}]` | `'["Switch the loader to a paginated query.", {"title":"Batch boundary.", "body":"Stay at the same per-page count as the rest of the exporter (100)."}]'` |
| `$OOS_JSON` | `[string]` | `'[]'` to skip the section; else `'["No changes to the per-tenant queueing model."]'` |
| `$AC_JSON` | `[string]` | `'[]'` to skip; else `'["Cron job completes for the largest tenant in under 5min.", "No regression in p95 latency for smaller tenants."]'` |

### 4. Bug-specific fields (Bug only)

If type = Bug, ask the user:

- **Impact:** Low / Medium / High / Critical (default Low).
- **Priority:** Low / Medium / High / Urgent (default Low).

These map to Jira option IDs inside `create-ticket.sh` — the script accepts either the friendly name (`--impact High`) or the raw id (`--impact 10645`).

### 5. Resolve the active sprint (when board id is set)

```bash
if [[ -n "$JIRA_BOARD_ID" ]]; then
  SPRINT_LINES="$("${CLAUDE_PLUGIN_ROOT}/scripts/tracker/active-sprint.sh" "$JIRA_BOARD_ID" 2>/dev/null || true)"
fi
```

The helper prints `<id>\t<name>` per active sprint:

- **Zero lines:** no active sprint — proceed without a sprint id. Inform the user the ticket goes to the backlog.
- **One line:** use the printed id directly.
- **Two or more lines:** ask the user which sprint to place the ticket in.

Do NOT pass `--sprint-id` to `create-ticket.sh`. On several `acli` versions the follow-up `additionalAttributes` edit (`acli jira workitem edit --key … --from-json …`) errors with `if any flags in the group [key jql filter generate-json from-json] are set none of the others can be`, and the ticket silently lands in the backlog. Step 8 below uses the dedicated REST helper instead.

### 6. Optional epic link — probe parent type first

Ask whether the ticket should hang off an "epic". When the user supplies a key, probe the type BEFORE deciding how to wire the parent:

```bash
PARENT_TYPE="$("${CLAUDE_PLUGIN_ROOT}/scripts/tracker/get-ticket-type.sh" "$PARENT_KEY" 2>/dev/null || true)"
```

- **`PARENT_TYPE == "Epic"`:** pass `--parent <PARENT_KEY>` (or the positional `<epic-key>`) to `create-ticket.sh`.
- **`PARENT_TYPE` is anything else (Task / Story / Bug):** `acli` rejects with `Given parent work item does not belong to appropriate hierarchy`. Create the ticket standalone with `--no-epic` (or the `-` positional), then add a `Relates` link to the would-be-parent in step 7's follow-up. Teams that loosely call a Task "an epic" in conversation hit this trip wire often.
- If the user does NOT want a parent, pass `-` (or `--no-epic`).

### 7. Create the ticket

Compose the call. `create-ticket.sh` is the single vetted entry point for `acli jira workitem create`.

```bash
# Decide the epic positional based on step 6's probe.
EPIC_ARG="${PARENT_TYPE_IS_EPIC:+$PARENT_KEY}"
EPIC_ARG="${EPIC_ARG:--}"

NEW_KEY="$(
  "${CLAUDE_PLUGIN_ROOT}/scripts/tracker/create-ticket.sh" \
    "$JIRA_PROJECT" \
    "$EPIC_ARG" \
    "<TITLE>" - \
    --description-adf-file "$adf_tmp" \
    --type "<Task|Bug|Story>" \
    ${IMPACT_NAME:+--impact "$IMPACT_NAME"} \
    ${PRIORITY_NAME:+--priority "$PRIORITY_NAME"} \
    --assign
)"
rm -f "$adf_tmp"
```

The helper prints **only** the new key on stdout. Capture it as `NEW_KEY`. Get the URL from `"${CLAUDE_PLUGIN_ROOT}/scripts/tracker/ticket-url.sh"` `${NEW_KEY}`.

If the parent in step 6 was NOT an Epic, add the Relates link now:

```bash
if [[ -n "$PARENT_KEY" && -z "$PARENT_TYPE_IS_EPIC" ]]; then
  "${CLAUDE_PLUGIN_ROOT}/scripts/tracker/link-tickets.sh" Relates "$NEW_KEY" "$PARENT_KEY"
fi
```

### 8. Place into the sprint (best-effort)

```bash
if [[ -n "$SPRINT_ID" ]]; then
  if ! "${CLAUDE_PLUGIN_ROOT}/scripts/tracker/add-to-sprint.sh" "$SPRINT_ID" "$NEW_KEY"; then
    TICKET_URL="$("${CLAUDE_PLUGIN_ROOT}/scripts/tracker/ticket-url.sh" "$NEW_KEY")"
    BOARD_URL="${TICKET_URL%%/browse/*}/jira/software/projects/${JIRA_PROJECT}/boards"
    echo "warning: $NEW_KEY landed in the backlog; drag it to the active sprint manually: $BOARD_URL" >&2
  fi
fi
```

`add-to-sprint.sh` uses the Jira Agile REST API (`POST /rest/agile/1.0/sprint/<id>/issue`). Auth comes from `JIRA_EMAIL` + `JIRA_API_TOKEN`; each may be a literal value or an `op://<vault>/<item>/<field>` 1Password reference (resolved via `op read` when the 1Password CLI is on PATH). If the env isn't set, the helper exits 3 with a clear message. Sprint placement is best-effort: when the helper warns, surface that to the user with the board URL so they can drag the ticket manually.

### 9. Output

Return:

- The issue key (e.g. `APP-1234`).
- The URL as a clickable markdown link.
- A one-line summary. Two shapes depending on parent wiring:
  - Epic parent: `Created [ABC-1234](<ticket-url>) — "<title>" (<type>, Sprint <N|backlog>, under epic <PARENT>).`
  - Task-as-parent: `Created [ABC-1234](<ticket-url>) — "<title>" (<type>, Sprint <N|backlog>, Relates to <PARENT>).`

## Hard rules

- **All Jira side effects go through the vetted helpers.** Don't inline `acli` in the skill, even for "just a quick edit". The helpers' customfield-fallback + labels + ADF handling + link verification + REST sprint placement are why they exist.
- **Description in ADF, not markdown.** Pass the ADF document built in step 3 via `--description-adf-file`. The markdown-string path is unreliable across `acli` versions.
- **Probe the parent type before passing `--parent`.** A Task masquerading as an "epic" makes `acli` reject the whole create.
- **Sprint placement via the dedicated helper, not `--sprint-id`.** The `--sprint-id` path silently drops tickets to the backlog on the broken `acli` versions.
- **The `specto` label is applied automatically** by the helper, in addition to any `--label` flags passed. Leave it on.
- **One ticket per invocation.** For bulk creation from a plan, defer to `plan-to-tickets`.

## When this skill should NOT run

- The user wants a stack of tickets created from `.specto/plan.md` — use `plan-to-tickets`.
- The user wants a `Test Plan` ticket paired with an implementation ticket — use `create-test-plan`.
- The user wants the whole flow (ticket → branch → MR) — use `implement-ticket`.
