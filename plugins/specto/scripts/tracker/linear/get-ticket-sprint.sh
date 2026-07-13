#!/usr/bin/env bash
# Read a Linear issue's current cycle id (sprints map 1:1 onto Linear cycles).
# Prints the cycle id on stdout; empty stdout means "not in a cycle"
# (backlog). Mirrors the jira counterpart's argv and exit contract.
#
# Usage:
#   get-ticket-sprint.sh <KEY>                       # live
#   get-ticket-sprint.sh <KEY> --from-fixture <path> # test: canned response
#
# --from-fixture <path>: the raw GraphQL response:
#   {"data":{"issue":{"cycle":{"id":"..."} | null}}}
#
# Output: the cycle id on stdout, newline-terminated; nothing if the issue is
# not in a cycle. Warnings/errors to stderr.
# Exit:
#   0 - cycle id printed, OR no cycle (clean exit, empty stdout)
#   2 - bad usage
#   3 - auth/transport failure

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GQL="$HERE/_gql.sh"

usage() {
  echo "usage: get-ticket-sprint.sh <KEY> [--from-fixture <path>]" >&2
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

Q='query($id: String!) { issue(id: $id) { cycle { id } } }'
if [[ -n "$FIXTURE" ]]; then
  DATA="$(bash "$GQL" --from-fixture "$FIXTURE" "$Q" '{}')" || exit $?
else
  DATA="$(bash "$GQL" "$Q" "$(jq -nc --arg id "$KEY" '{id: $id}')")" || exit $?
fi

CYCLE_ID="$(printf '%s' "$DATA" | jq -r '.issue.cycle.id // empty')"
[[ -n "$CYCLE_ID" ]] && printf '%s\n' "$CYCLE_ID"
exit 0
