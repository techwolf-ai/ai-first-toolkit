#!/usr/bin/env bash
# Set (re-attach) the parent of a Linear issue via issueUpdate(parentId).
# Linear epics are parent issues, so this is the epic-attach path. Mirrors the
# jira counterpart's argv and its soft-failure contract: exit 3 lets the
# caller fall back to a `relates` link.
#
# Usage:
#   set-parent.sh <KEY> <PARENT_KEY>                       # live
#   set-parent.sh <KEY> <PARENT_KEY> --from-fixture <path> # test (no network)
#
# --from-fixture <path>: the fixture is the raw GraphQL issueUpdate response;
#   issue-id resolution is live-only.
#
# Output: nothing on stdout on success; warnings/errors to stderr.
# Exit:
#   0 - parent set (or fixture says success)
#   1 - a key did not resolve
#   2 - bad usage
#   3 - auth/transport failure, or the mutation failed (soft failure)

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GQL="$HERE/_gql.sh"

usage() {
  echo "usage: set-parent.sh <KEY> <PARENT_KEY> [--from-fixture <path>]" >&2
  exit 2
}

[[ $# -lt 2 ]] && usage
KEY="$1"
PARENT_KEY="$2"
shift 2

FIXTURE=""
if [[ $# -gt 0 ]]; then
  if [[ "$1" == "--from-fixture" && $# -ge 2 ]]; then
    FIXTURE="$2"
    shift 2
  else
    usage
  fi
fi
[[ $# -gt 0 ]] && usage

if [[ -n "$FIXTURE" ]]; then
  DATA="$(bash "$GQL" --from-fixture "$FIXTURE" 'mutation' '{}')" || exit $?
  [[ "$(printf '%s' "$DATA" | jq -r '.issueUpdate.success // false')" == "true" ]] || {
    echo "fixture: issueUpdate success=false" >&2
    exit 3
  }
  exit 0
fi

gql() { bash "$GQL" "$1" "$2"; }

DATA="$(gql 'query($id: String!) { issue(id: $id) { id } }' "$(jq -nc --arg id "$KEY" '{id: $id}')")" || exit $?
ISSUE_ID="$(printf '%s' "$DATA" | jq -r '.issue.id // empty')"
[[ -n "$ISSUE_ID" ]] || { echo "issue not found: $KEY" >&2; exit 1; }

DATA="$(gql 'query($id: String!) { issue(id: $id) { id } }' "$(jq -nc --arg id "$PARENT_KEY" '{id: $id}')")" || exit $?
PARENT_ID="$(printf '%s' "$DATA" | jq -r '.issue.id // empty')"
[[ -n "$PARENT_ID" ]] || { echo "parent issue not found: $PARENT_KEY" >&2; exit 1; }

DATA="$(gql 'mutation($id: String!, $input: IssueUpdateInput!) { issueUpdate(id: $id, input: $input) { success } }' \
            "$(jq -nc --arg id "$ISSUE_ID" --arg parentId "$PARENT_ID" '{id: $id, input: {parentId: $parentId}}')")" || {
  echo "issueUpdate (parentId) failed on $KEY -> $PARENT_KEY (auth? key?)" >&2
  exit 3
}
[[ "$(printf '%s' "$DATA" | jq -r '.issueUpdate.success // false')" == "true" ]] || {
  echo "issueUpdate reported success=false on $KEY -> $PARENT_KEY" >&2
  exit 3
}
