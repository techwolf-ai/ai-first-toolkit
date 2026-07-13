#!/usr/bin/env bash
# Read a Linear issue's effective type. Linear has no issue types, so specto
# derives one:
#   * the issue has children  -> "Epic" (epics are parent issues on Linear)
#   * else the first label whose name is bug/task/story (case-insensitive)
#     -> that name capitalized ("Bug"/"Task"/"Story")
#   * else -> "Issue"
# Mirrors the jira counterpart's argv. Callers use this to probe a would-be
# parent before attaching children to it.
#
# Usage:
#   get-ticket-type.sh <KEY>                       # live
#   get-ticket-type.sh <KEY> --from-fixture <path> # test: canned response
#
# --from-fixture <path>: the raw GraphQL response:
#   {"data":{"issue":{"children":{"nodes":[...]},"labels":{"nodes":[{"name":..}]}}}}
#
# Output: the type string on stdout, newline-terminated.
# Exit:
#   0 - type printed
#   1 - the issue key did not resolve
#   2 - bad usage
#   3 - auth/transport failure

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GQL="$HERE/_gql.sh"

usage() {
  echo "usage: get-ticket-type.sh <KEY> [--from-fixture <path>]" >&2
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

Q='query($id: String!) { issue(id: $id) { children { nodes { id } } labels { nodes { name } } } }'
if [[ -n "$FIXTURE" ]]; then
  DATA="$(bash "$GQL" --from-fixture "$FIXTURE" "$Q" '{}')" || exit $?
else
  DATA="$(bash "$GQL" "$Q" "$(jq -nc --arg id "$KEY" '{id: $id}')")" || exit $?
fi

printf '%s' "$DATA" | jq -e '.issue' >/dev/null 2>&1 || { echo "issue not found: $KEY" >&2; exit 1; }

TYPE="$(printf '%s' "$DATA" | jq -r '
  if (.issue.children.nodes | length) > 0 then "Epic"
  else
    ([.issue.labels.nodes[]?.name | ascii_downcase | select(. == "bug" or . == "task" or . == "story")] | first) as $t
    | if   $t == "bug"   then "Bug"
      elif $t == "task"  then "Task"
      elif $t == "story" then "Story"
      else "Issue" end
  end
')"
printf '%s\n' "$TYPE"
