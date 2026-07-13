#!/usr/bin/env bash
# Create a Linear issue (and, in the SAME invocation, any Blocks / BlockedBy
# relations, so a partial create can never leave a missing link). Mirrors the
# jira counterpart's argv exactly; the differences are all backend-internal:
#
#   * <project-key> is the LINEAR TEAM KEY (e.g. ENG). Pass "-" to fall back
#     to config: the `project` key (repo .specto/config.yml, then machine
#     config), then the `linear_team` machine key.
#   * <epic-key|-> is a parent ISSUE identifier; Linear epics are parent
#     issues, so the epic becomes issueCreate's parentId.
#   * Descriptions are markdown-native: the body passes through untouched.
#     --description-adf-file therefore exits 4 (no ADF on Linear).
#   * --type maps to a label: Task (the default) adds nothing; any other type
#     attaches a lowercase label of the same name (bug, story, ...), which is
#     what get-ticket-type.sh reads back.
#   * --impact <v> maps to a label `impact:<v>` (lowercased).
#   * --priority maps to Linear's 0-4 priority scale: urgent=1, high=2,
#     medium=3, low=4 (0 = none). A raw 0-4 passes through; anything else is
#     warned about and skipped.
#   * --sprint-id <id> is a Linear cycle id, set via issueCreate's cycleId.
#   * The `specto` label is always applied; labels are found case-insensitively
#     and created via issueLabelCreate when missing.
#
# Usage:
#   create-ticket.sh <project-key> <epic-key|-> <summary> <description-file|-> \
#       [--type <T>] [--no-epic] [--label <n>]... [--sprint-id <id>]          \
#       [--impact <v>] [--priority <v>] [--description-adf-file <path>]       \
#       [--assign] [--blocks <KEY>]... [--blocked-by <KEY>]...                \
#       [--from-fixture <path>]
#
# <description-file> may be "-" to read the body from stdin.
# --from-fixture <path>: the fixture is the raw GraphQL issueCreate response
#   (e.g. {"data":{"issueCreate":{"success":true,"issue":{"identifier":"ENG-123"}}}});
#   the helper prints that identifier and exercises the link loop against
#   link-tickets.sh in its own fixture mode (sibling tests/fixtures/link-ok.json).
#
# Output: the new issue identifier on stdout (nothing else). Warnings to stderr.
# Exit:
#   0 - issue created and all links created
#   1 - create succeeded but the identifier could not be parsed, or no team
#       with the given key
#   2 - bad usage
#   3 - auth/transport failure, create failed, or a link create failed
#   4 - --description-adf-file passed (no ADF on Linear)

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GQL="$HERE/_gql.sh"

usage() {
  echo "usage: create-ticket.sh <project-key> <epic-key|-> <summary> <description-file|-> [--type <T>] [--no-epic] [--label <n>]... [--sprint-id <id>] [--impact <v>] [--priority <v>] [--description-adf-file <path>] [--assign] [--blocks <KEY>]... [--blocked-by <KEY>]... [--from-fixture <path>]" >&2
  exit 2
}

[[ $# -lt 4 ]] && usage
PROJECT="$1"
EPIC_KEY="$2"
SUMMARY="$3"
DESC_SRC="$4"
shift 4

BLOCKS=()
BLOCKED_BY=()
FIXTURE=""
TYPE="Task"
NO_EPIC=false
LABELS=()
SPRINT_ID=""
IMPACT_RAW=""
PRIORITY_RAW=""
ADF_FILE=""
ASSIGN=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --blocks)                [[ $# -ge 2 ]] || usage; BLOCKS+=("$2"); shift 2 ;;
    --blocked-by)            [[ $# -ge 2 ]] || usage; BLOCKED_BY+=("$2"); shift 2 ;;
    --from-fixture)          [[ $# -ge 2 ]] || usage; FIXTURE="$2"; shift 2 ;;
    --type)                  [[ $# -ge 2 ]] || usage; TYPE="$2"; shift 2 ;;
    --no-epic)               NO_EPIC=true; shift ;;
    --label)                 [[ $# -ge 2 ]] || usage; LABELS+=("$2"); shift 2 ;;
    --sprint-id)             [[ $# -ge 2 ]] || usage; SPRINT_ID="$2"; shift 2 ;;
    --impact)                [[ $# -ge 2 ]] || usage; IMPACT_RAW="$2"; shift 2 ;;
    --priority)              [[ $# -ge 2 ]] || usage; PRIORITY_RAW="$2"; shift 2 ;;
    --description-adf-file)  [[ $# -ge 2 ]] || usage; ADF_FILE="$2"; shift 2 ;;
    --assign)                ASSIGN=true; shift ;;
    *)                       usage ;;
  esac
done

# ADF has no place on Linear: descriptions are markdown-native. The flag is
# accepted by the parser (argv parity with jira) but the capability is absent.
if [[ -n "$ADF_FILE" ]]; then
  echo "not supported on linear: --description-adf-file (Linear descriptions are markdown-native; pass markdown via <description-file>)" >&2
  exit 4
fi

# --no-epic is equivalent to passing "-" for the positional epic key.
[[ "$EPIC_KEY" == "-" ]] && NO_EPIC=true

# Map a friendly priority name to Linear's 0-4 scale (0=none, 1=urgent,
# 2=high, 3=medium, 4=low). Raw 0-4 passes through; unknown values are
# skipped with a warning rather than breaking the mutation (priority is Int).
PRIORITY_NUM=""
if [[ -n "$PRIORITY_RAW" ]]; then
  if [[ "$PRIORITY_RAW" =~ ^[0-4]$ ]]; then
    PRIORITY_NUM="$PRIORITY_RAW"
  else
    case "$(printf '%s' "$PRIORITY_RAW" | tr '[:upper:]' '[:lower:]')" in
      urgent) PRIORITY_NUM="1" ;;
      high)   PRIORITY_NUM="2" ;;
      medium) PRIORITY_NUM="3" ;;
      low)    PRIORITY_NUM="4" ;;
      *) echo "warning: unknown priority '$PRIORITY_RAW' (use Urgent/High/Medium/Low or 0-4); skipping" >&2 ;;
    esac
  fi
fi

# Read the description body (markdown, passed through untouched).
if [[ "$DESC_SRC" == "-" ]]; then
  DESC="$(cat)"
else
  [[ -f "$DESC_SRC" ]] || { echo "description file not found: $DESC_SRC" >&2; exit 2; }
  DESC="$(cat "$DESC_SRC")"
fi

# ----- fixture mode -----
# The fixture is the raw GraphQL issueCreate response; team/label/parent
# resolution is live-only. The link loop runs against link-tickets.sh's own
# fixture mode, same as the jira suite.
if [[ -n "$FIXTURE" ]]; then
  DATA="$(bash "$GQL" --from-fixture "$FIXTURE" 'mutation' '{}')" || exit $?
  NEW_KEY="$(printf '%s' "$DATA" | jq -r '.issueCreate.issue.identifier // empty')"
  [[ -n "$NEW_KEY" ]] || { echo "no .data.issueCreate.issue.identifier in create fixture: $FIXTURE" >&2; exit 1; }
  LINK_FIXTURE="$HERE/tests/fixtures/link-ok.json"
  if [[ -n "${BLOCKS[*]+x}" ]]; then
    for k in "${BLOCKS[@]}"; do
      bash "$HERE/link-tickets.sh" "blocks" "$NEW_KEY" "$k" --from-fixture "$LINK_FIXTURE" || { echo "link (Blocks) failed in fixture mode" >&2; exit 3; }
    done
  fi
  if [[ -n "${BLOCKED_BY[*]+x}" ]]; then
    for k in "${BLOCKED_BY[@]}"; do
      bash "$HERE/link-tickets.sh" "blocks" "$k" "$NEW_KEY" --from-fixture "$LINK_FIXTURE" || { echo "link (BlockedBy) failed in fixture mode" >&2; exit 3; }
    done
  fi
  echo "$NEW_KEY"
  exit 0
fi

# ----- live mode -----

# Resolve the team key: the positional wins; "-" falls back to config
# (`project`, then `linear_team`, each checked repo-then-machine).
if [[ "$PROJECT" == "-" ]]; then
  . "$HERE/../../lib/config.sh"
  PROJECT="$(specto_config_get project)"
  [[ -z "$PROJECT" ]] && PROJECT="$(specto_config_get linear_team)"
  if [[ -z "$PROJECT" ]]; then
    echo "specto: no Linear team configured. Pass the team key positionally, or set 'project' in .specto/config.yml / 'linear_team' via scripts/plugin-config.sh." >&2
    exit 3
  fi
fi

gql() { bash "$GQL" "$1" "$2"; }

# Team key -> teamId.
DATA="$(gql 'query($key: String!) { teams(filter: {key: {eq: $key}}) { nodes { id key } } }' \
            "$(jq -nc --arg key "$PROJECT" '{key: $key}')")" || exit $?
TEAM_ID="$(printf '%s' "$DATA" | jq -r '.teams.nodes[0].id // empty')"
[[ -n "$TEAM_ID" ]] || { echo "no Linear team with key '$PROJECT'" >&2; exit 1; }

# Find-or-create a label by name (case-insensitive find; workspace-level
# create). Prints the label id.
ensure_label() {
  local name="$1" data id
  data="$(gql 'query($name: String!) { issueLabels(filter: {name: {eqIgnoreCase: $name}}) { nodes { id name } } }' \
              "$(jq -nc --arg name "$name" '{name: $name}')")" || return 3
  id="$(printf '%s' "$data" | jq -r '.issueLabels.nodes[0].id // empty')"
  if [[ -z "$id" ]]; then
    data="$(gql 'mutation($input: IssueLabelCreateInput!) { issueLabelCreate(input: $input) { success issueLabel { id } } }' \
                "$(jq -nc --arg name "$name" '{input: {name: $name}}')")" || return 3
    id="$(printf '%s' "$data" | jq -r '.issueLabelCreate.issueLabel.id // empty')"
  fi
  [[ -n "$id" ]] || { echo "could not find or create Linear label '$name'" >&2; return 3; }
  printf '%s' "$id"
}

# Assemble the label set: specto always; --label extras; impact:<v>; the
# lowercase type name for non-Task types (get-ticket-type.sh's read-back set).
WANT_LABELS=("specto")
if [[ -n "${LABELS[*]+x}" ]]; then
  for l in "${LABELS[@]}"; do WANT_LABELS+=("$l"); done
fi
[[ -n "$IMPACT_RAW" ]] && WANT_LABELS+=("impact:$(printf '%s' "$IMPACT_RAW" | tr '[:upper:]' '[:lower:]')")
if [[ "$(printf '%s' "$TYPE" | tr '[:upper:]' '[:lower:]')" != "task" ]]; then
  WANT_LABELS+=("$(printf '%s' "$TYPE" | tr '[:upper:]' '[:lower:]')")
fi

LABEL_IDS='[]'
for name in "${WANT_LABELS[@]}"; do
  lid="$(ensure_label "$name")" || exit 3
  LABEL_IDS="$(printf '%s' "$LABEL_IDS" | jq -c --arg id "$lid" '. + [$id] | unique')"
done

# Epic -> parentId (Linear epics are parent issues).
PARENT_ID=""
if ! $NO_EPIC; then
  DATA="$(gql 'query($id: String!) { issue(id: $id) { id } }' \
              "$(jq -nc --arg id "$EPIC_KEY" '{id: $id}')")" || exit $?
  PARENT_ID="$(printf '%s' "$DATA" | jq -r '.issue.id // empty')"
  [[ -n "$PARENT_ID" ]] || { echo "epic issue not found: $EPIC_KEY" >&2; exit 1; }
fi

# --assign: resolve the viewer's id up front and set assigneeId in the create.
ASSIGNEE_ID=""
if $ASSIGN; then
  DATA="$(gql 'query { viewer { id } }' '{}')" || exit $?
  ASSIGNEE_ID="$(printf '%s' "$DATA" | jq -r '.viewer.id // empty')"
  [[ -n "$ASSIGNEE_ID" ]] || echo "warning: could not resolve viewer id; creating unassigned" >&2
fi

INPUT="$(jq -nc \
  --arg teamId "$TEAM_ID" \
  --arg title "$SUMMARY" \
  --arg description "$DESC" \
  --argjson labelIds "$LABEL_IDS" \
  --arg parentId "$PARENT_ID" \
  --arg priority "$PRIORITY_NUM" \
  --arg cycleId "$SPRINT_ID" \
  --arg assigneeId "$ASSIGNEE_ID" '
  {teamId: $teamId, title: $title, description: $description, labelIds: $labelIds}
  + (if $parentId   != "" then {parentId: $parentId}            else {} end)
  + (if $priority   != "" then {priority: ($priority|tonumber)} else {} end)
  + (if $cycleId    != "" then {cycleId: $cycleId}              else {} end)
  + (if $assigneeId != "" then {assigneeId: $assigneeId}        else {} end)
')"

DATA="$(gql 'mutation($input: IssueCreateInput!) { issueCreate(input: $input) { success issue { identifier id } } }' \
            "$(jq -nc --argjson input "$INPUT" '{input: $input}')")" || {
  echo "Linear issueCreate failed in team $PROJECT (auth? team? parent?)" >&2
  exit 3
}
[[ "$(printf '%s' "$DATA" | jq -r '.issueCreate.success // false')" == "true" ]] || {
  echo "Linear issueCreate reported success=false in team $PROJECT" >&2
  exit 3
}
NEW_KEY="$(printf '%s' "$DATA" | jq -r '.issueCreate.issue.identifier // empty')"
[[ -n "$NEW_KEY" ]] || { echo "created the issue but could not parse its identifier from the response" >&2; exit 1; }

# Create the links in the same invocation. link-tickets.sh self-verifies the
# stored direction by read-back, so no extra batch verification is needed here.
#   --blocks K     => the new issue BLOCKS K       => "$NEW_KEY blocks $k"
#   --blocked-by K => the new issue is BLOCKED BY K => "$k blocks $NEW_KEY"
if [[ -n "${BLOCKS[*]+x}" ]]; then
  for k in "${BLOCKS[@]}"; do
    bash "$HERE/link-tickets.sh" "blocks" "$NEW_KEY" "$k" || { echo "created $NEW_KEY but failed to link Blocks->$k" >&2; exit 3; }
  done
fi
if [[ -n "${BLOCKED_BY[*]+x}" ]]; then
  for k in "${BLOCKED_BY[@]}"; do
    bash "$HERE/link-tickets.sh" "blocks" "$k" "$NEW_KEY" || { echo "created $NEW_KEY but failed to link BlockedBy<-$k" >&2; exit 3; }
  done
fi

echo "$NEW_KEY"
