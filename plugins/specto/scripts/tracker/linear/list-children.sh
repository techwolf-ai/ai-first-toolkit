#!/usr/bin/env bash
# List the child issues of a Linear epic (epics are parent issues) as the
# normalized JSON array every backend emits:
#   [{"key": "ENG-12", "summary": "...", "status": "...", "type": "Task"}, ...]
#
# `type` is derived per child the same way get-ticket-type.sh derives it from
# labels (bug/task/story capitalized, fallback "Issue"; the has-children Epic
# probe is not applied to children to keep this a single query). Mirrors the
# jira counterpart's argv.
#
# Usage:
#   list-children.sh <EPIC-KEY>                       # live
#   list-children.sh <EPIC-KEY> --from-fixture <path> # test: canned response
#
# --from-fixture <path>: the raw GraphQL response:
#   {"data":{"issue":{"children":{"nodes":[{"identifier":..,"title":..,
#     "state":{"name":..},"labels":{"nodes":[{"name":..}]}}]}}}}
#
# Output: the normalized JSON array on stdout (possibly []). Warnings to stderr.
# Exit:
#   0 - array printed
#   1 - the epic key did not resolve
#   2 - bad usage
#   3 - auth/transport failure

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GQL="$HERE/_gql.sh"

usage() {
  echo "usage: list-children.sh <EPIC-KEY> [--from-fixture <path>]" >&2
  exit 2
}

[[ $# -lt 1 ]] && usage
EPIC="$1"
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

Q='query($id: String!) { issue(id: $id) { children(first: 250) { nodes { identifier title state { name } labels { nodes { name } } } } } }'
if [[ -n "$FIXTURE" ]]; then
  DATA="$(bash "$GQL" --from-fixture "$FIXTURE" "$Q" '{}')" || exit $?
else
  DATA="$(bash "$GQL" "$Q" "$(jq -nc --arg id "$EPIC" '{id: $id}')")" || exit $?
fi

printf '%s' "$DATA" | jq -e '.issue' >/dev/null 2>&1 || { echo "epic issue not found: $EPIC" >&2; exit 1; }

printf '%s' "$DATA" | jq '
  def type_of:
    ([.labels.nodes[]?.name | ascii_downcase | select(. == "bug" or . == "task" or . == "story")] | first) as $t
    | if   $t == "bug"   then "Bug"
      elif $t == "task"  then "Task"
      elif $t == "story" then "Story"
      else "Issue" end;
  [.issue.children.nodes[]?
   | {key: .identifier,
      summary: (.title // ""),
      status: (.state.name // ""),
      type: type_of}]
'
