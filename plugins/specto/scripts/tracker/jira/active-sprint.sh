#!/usr/bin/env bash
# Resolve the active sprint(s) for a Jira board. Pairs with create-ticket.sh's
# --sprint-id flag: the caller fetches the active sprint here, then places a new
# ticket into it. create-ticket and (optionally) plan-to-tickets are the
# expected consumers.
#
# Acli's `jira board list-sprints --state active --csv` returns rows of
# `id,name,state,startDate,endDate`. This helper filters to the active sprint(s),
# drops the header row, and emits ONE active sprint per line as a tab-separated
# `<id>\t<name>` pair so the caller can `cut` or `read` it without parsing JSON.
#
# Multiple active sprints (uncommon — Jira allows up to two parallel sprints on
# a board) are all emitted; the caller decides whether to ask the user to pick.
#
# Usage:
#   active-sprint.sh <board-id>                                  # live
#   active-sprint.sh <board-id> --from-fixture <path>            # test
#
# Fixture file shape (JSON, same as add-to-sprint.sh's fixture shape so callers
# can reuse the same files):
#   {"board_id": 12, "active_sprint": {"id": 34, "name": "Sprint 7"}}
#   {"board_id": 12, "active_sprint": null}
# Or, for the multi-active case:
#   {"board_id": 12, "active_sprints": [{"id": 34, "name": "Sprint 7"},
#                                       {"id": 35, "name": "Sprint 8"}]}
#
# Output (live + fixture): one TAB-separated `<id>\t<name>` per active sprint on
# stdout; nothing if no active sprint. Warnings/errors to stderr.
# Exit:
#   0 — fetched (zero or more active sprints; the empty case is NOT an error,
#       it just means "no active sprint, ticket goes to backlog")
#   2 — bad usage
#   3 — acli not on PATH, or acli call failed

set -u
set -o pipefail

usage() {
  echo "usage: active-sprint.sh <board-id> [--from-fixture <path>]" >&2
  exit 2
}

[[ $# -lt 1 ]] && usage
BOARD_ID="$1"
shift

FIXTURE=""
if [[ $# -gt 0 ]]; then
  if [[ "$1" == "--from-fixture" && $# -ge 2 ]]; then
    FIXTURE="$2"
    shift 2
  else
    usage
  fi
fi

# Fixture mode: read either {active_sprint: {...}} or {active_sprints: [{...}]}.
if [[ -n "$FIXTURE" ]]; then
  [[ -f "$FIXTURE" ]] || { echo "fixture not found: $FIXTURE" >&2; exit 3; }
  data="$(cat "$FIXTURE")"
  echo "$data" | jq . >/dev/null 2>&1 || { echo "fixture JSON unparseable: $FIXTURE" >&2; exit 3; }
  echo "$data" | jq -r '
    if (.active_sprints | type) == "array" then
      .active_sprints[] | "\(.id)\t\(.name)"
    elif (.active_sprint // null) != null then
      .active_sprint | "\(.id)\t\(.name)"
    else
      empty
    end
  '
  exit 0
fi

# Live mode.
if ! command -v acli >/dev/null; then
  echo "acli not on PATH; install Atlassian CLI" >&2
  exit 3
fi

# acli prints a header row (id,name,state,...). Drop it and any rows whose id
# isn't a digit. CSV here is simple enough (no embedded commas in sprint names
# in practice) that awk on the first two fields is robust.
csv="$(acli jira board list-sprints --id "$BOARD_ID" --state active --csv 2>/dev/null)" || {
  echo "acli list-sprints failed for board $BOARD_ID (auth? board id?)" >&2
  exit 3
}

printf '%s\n' "$csv" | awk -F',' '
  NR == 1 && tolower($1) == "id" { next }      # skip header
  $1 !~ /^[0-9]+$/                 { next }    # skip blanks / non-numeric
  { printf "%s\t%s\n", $1, $2 }
'
