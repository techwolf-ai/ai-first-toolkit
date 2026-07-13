#!/usr/bin/env bash
# Set the assignee on a Linear issue via issueUpdate(assigneeId). Mirrors the
# jira counterpart's argv. '@me' (the default) resolves through the viewer
# query; an explicit assignee is matched by email first, then display name
# (case-insensitive). Linear has no writable reporter field (the creator is
# immutable), so the jira impl's best-effort reporter step has no equivalent.
#
# Usage:
#   assign-ticket.sh <KEY> [<assignee>]                       # default: @me
#   assign-ticket.sh <KEY> [<assignee>] --from-fixture <path> # test mode
#
# --from-fixture <path>: the fixture is the raw GraphQL issueUpdate response;
#   issue/user resolution is live-only.
#
# Output: nothing on stdout on success; warnings/errors to stderr.
# Exit:
#   0 - assignee set (or fixture says success)
#   1 - the issue key or assignee did not resolve
#   2 - bad usage
#   3 - auth/transport failure, or the mutation failed

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GQL="$HERE/_gql.sh"

usage() {
  echo "usage: assign-ticket.sh <KEY> [<assignee>] [--from-fixture <path>]" >&2
  exit 2
}

[[ $# -lt 1 ]] && usage
KEY="$1"
shift

ASSIGNEE="@me"
if [[ $# -gt 0 && "$1" != "--from-fixture" ]]; then
  ASSIGNEE="$1"
  shift
fi

FIXTURE=""
if [[ $# -gt 0 ]]; then
  if [[ "$1" == "--from-fixture" && $# -ge 2 ]]; then
    FIXTURE="$2"
    shift 2
  else
    usage
  fi
fi

if [[ -n "$FIXTURE" ]]; then
  DATA="$(bash "$GQL" --from-fixture "$FIXTURE" 'mutation' '{}')" || exit $?
  [[ "$(printf '%s' "$DATA" | jq -r '.issueUpdate.success // false')" == "true" ]] || {
    echo "fixture: issueUpdate success=false" >&2
    exit 3
  }
  exit 0
fi

gql() { bash "$GQL" "$1" "$2"; }

# Resolve the assignee to a user id.
if [[ "$ASSIGNEE" == "@me" || "$ASSIGNEE" == "default" ]]; then
  DATA="$(gql 'query { viewer { id } }' '{}')" || exit $?
  USER_ID="$(printf '%s' "$DATA" | jq -r '.viewer.id // empty')"
  [[ -n "$USER_ID" ]] || { echo "could not resolve the viewer id" >&2; exit 1; }
else
  DATA="$(gql 'query($v: String!) { users(filter: {or: [{email: {eq: $v}}, {displayName: {eqIgnoreCase: $v}}]}) { nodes { id } } }' \
              "$(jq -nc --arg v "$ASSIGNEE" '{v: $v}')")" || exit $?
  USER_ID="$(printf '%s' "$DATA" | jq -r '.users.nodes[0].id // empty')"
  [[ -n "$USER_ID" ]] || { echo "no Linear user matched '$ASSIGNEE' (email or display name)" >&2; exit 1; }
fi

DATA="$(gql 'query($id: String!) { issue(id: $id) { id } }' "$(jq -nc --arg id "$KEY" '{id: $id}')")" || exit $?
ISSUE_ID="$(printf '%s' "$DATA" | jq -r '.issue.id // empty')"
[[ -n "$ISSUE_ID" ]] || { echo "issue not found: $KEY" >&2; exit 1; }

DATA="$(gql 'mutation($id: String!, $input: IssueUpdateInput!) { issueUpdate(id: $id, input: $input) { success } }' \
            "$(jq -nc --arg id "$ISSUE_ID" --arg assigneeId "$USER_ID" '{id: $id, input: {assigneeId: $assigneeId}}')")" || {
  echo "issueUpdate (assigneeId) failed on $KEY -> $ASSIGNEE (auth? key? unknown user?)" >&2
  exit 3
}
[[ "$(printf '%s' "$DATA" | jq -r '.issueUpdate.success // false')" == "true" ]] || {
  echo "issueUpdate reported success=false on $KEY" >&2
  exit 3
}
