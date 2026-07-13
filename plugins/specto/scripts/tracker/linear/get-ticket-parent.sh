#!/usr/bin/env bash
# Read a Linear issue's parent identifier. Tries the real parent first
# (issue.parent, the epic-as-parent-issue convention), then falls back to the
# first `related` relation in either direction (the relates-based parent
# convention the callers adopt when set-parent soft-fails). Mirrors the jira
# counterpart's argv and its output shape.
#
# Usage:
#   get-ticket-parent.sh <KEY>                       # live
#   get-ticket-parent.sh <KEY> --from-fixture <path> # test: canned response
#
# --from-fixture <path>: the raw GraphQL response for the parent query:
#   {"data":{"issue":{"parent":{"identifier":..} | null,
#                     "relations":{"nodes":[{"type":..,"relatedIssue":{"identifier":..}}]},
#                     "inverseRelations":{"nodes":[{"type":..,"issue":{"identifier":..}}]}}}}
#
# Output: `<PARENT-KEY>\tparent` (real parent), `<PARENT-KEY>\trelates`
# (relation-based fallback), or nothing when no parent pointer exists.
# Exit:
#   0 - parent printed, OR no parent (clean exit, empty stdout)
#   1 - the issue key did not resolve
#   2 - bad usage
#   3 - auth/transport failure

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GQL="$HERE/_gql.sh"

usage() {
  echo "usage: get-ticket-parent.sh <KEY> [--from-fixture <path>]" >&2
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

Q='query($id: String!) { issue(id: $id) { parent { identifier } relations { nodes { type relatedIssue { identifier } } } inverseRelations { nodes { type issue { identifier } } } } }'
if [[ -n "$FIXTURE" ]]; then
  DATA="$(bash "$GQL" --from-fixture "$FIXTURE" "$Q" '{}')" || exit $?
else
  DATA="$(bash "$GQL" "$Q" "$(jq -nc --arg id "$KEY" '{id: $id}')")" || exit $?
fi

printf '%s' "$DATA" | jq -e '.issue' >/dev/null 2>&1 || { echo "issue not found: $KEY" >&2; exit 1; }

# Prefer the real parent (epic-as-parent-issue). Fall back to the first
# `related` relation, outgoing side first, then incoming.
PARENT="$(printf '%s' "$DATA" | jq -r '.issue.parent.identifier // empty')"
if [[ -n "$PARENT" ]]; then
  printf '%s\tparent\n' "$PARENT"
  exit 0
fi

RELATES_PARENT="$(printf '%s' "$DATA" | jq -r '
  ([.issue.relations.nodes[]? | select(.type == "related") | .relatedIssue.identifier]
   + [.issue.inverseRelations.nodes[]? | select(.type == "related") | .issue.identifier])
  | map(select(. != null)) | first // empty
')"
if [[ -n "$RELATES_PARENT" ]]; then
  printf '%s\trelates\n' "$RELATES_PARENT"
  exit 0
fi

exit 0
