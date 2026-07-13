#!/usr/bin/env bash
# Read a Linear issue's title and print it on stdout; the single vetted read
# path for "what is this ticket called?". Mirrors the jira counterpart's argv
# (jira reads .fields.summary; Linear's equivalent is issue.title).
#
# Usage:
#   get-ticket-summary.sh <KEY>                       # live
#   get-ticket-summary.sh <KEY> --from-fixture <path> # test: canned response
#
# --from-fixture <path>: the raw GraphQL response:
#   {"data":{"issue":{"title":"..."}}}
#
# Output: the title string on stdout, newline-terminated.
# Exit:
#   0 - title printed
#   1 - the issue key did not resolve, or no title in the response
#   2 - bad usage
#   3 - auth/transport failure

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GQL="$HERE/_gql.sh"

usage() {
  echo "usage: get-ticket-summary.sh <KEY> [--from-fixture <path>]" >&2
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

Q='query($id: String!) { issue(id: $id) { title } }'
if [[ -n "$FIXTURE" ]]; then
  DATA="$(bash "$GQL" --from-fixture "$FIXTURE" "$Q" '{}')" || exit $?
else
  DATA="$(bash "$GQL" "$Q" "$(jq -nc --arg id "$KEY" '{id: $id}')")" || exit $?
fi

TITLE="$(printf '%s' "$DATA" | jq -r '.issue.title // empty')"
[[ -n "$TITLE" ]] || { echo "no title for $KEY" >&2; exit 1; }
printf '%s\n' "$TITLE"
