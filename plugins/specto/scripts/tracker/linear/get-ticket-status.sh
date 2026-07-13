#!/usr/bin/env bash
# Read a Linear issue's live workflow state name (issue.state.name) and print
# it on stdout. Mirrors the jira counterpart's argv. Used by the dod agent's
# state-desync check, which must never trust a cached status.
#
# Usage:
#   get-ticket-status.sh <KEY>                       # live
#   get-ticket-status.sh <KEY> --from-fixture <path> # test: canned response
#
# --from-fixture <path>: the raw GraphQL response:
#   {"data":{"issue":{"state":{"name":"In Progress"}}}}
#
# Output: the status string on stdout, newline-terminated.
# Exit:
#   0 - status printed
#   1 - the issue key did not resolve, or no state name in the response
#   2 - bad usage
#   3 - auth/transport failure

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GQL="$HERE/_gql.sh"

usage() {
  echo "usage: get-ticket-status.sh <KEY> [--from-fixture <path>]" >&2
  exit 2
}

[[ $# -lt 1 ]] && usage
KEY="$1"
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

Q='query($id: String!) { issue(id: $id) { state { name } } }'
if [[ -n "$FIXTURE" ]]; then
  DATA="$(bash "$GQL" --from-fixture "$FIXTURE" "$Q" '{}')" || exit $?
else
  DATA="$(bash "$GQL" "$Q" "$(jq -nc --arg id "$KEY" '{id: $id}')")" || exit $?
fi

STATUS="$(printf '%s' "$DATA" | jq -r '.issue.state.name // empty')"
[[ -n "$STATUS" ]] || { echo "no state name for $KEY" >&2; exit 1; }
printf '%s\n' "$STATUS"
