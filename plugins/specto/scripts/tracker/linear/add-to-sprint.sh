#!/usr/bin/env bash
# Add a Linear issue to a cycle via issueUpdate(cycleId) (sprints map 1:1 onto
# Linear cycles). Mirrors the jira counterpart's argv, including the legacy
# one-arg stub form: the two forms are disambiguated by whether the second
# positional looks like an issue identifier (ABC-123), exactly as jira does.
#
# Usage:
#   add-to-sprint.sh <SPRINT_ID> <KEY>                       # live
#   add-to-sprint.sh <SPRINT_ID> <KEY> --from-fixture <path> # test
#   add-to-sprint.sh <KEY>                                   # legacy stub form
#                                                            # (one-arg) preserved
#                                                            # for backwards compat
#
# <SPRINT_ID> is a Linear cycle id (as printed by active-sprint.sh).
# --from-fixture <path>: the fixture is the raw GraphQL issueUpdate response;
#   issue-id resolution is live-only.
#
# Output: nothing on stdout; warnings to stderr.
# Exit:
#   0 - added (or fixture says success, or legacy no-op)
#   1 - the issue key did not resolve
#   2 - bad usage
#   3 - auth/transport failure, or the mutation failed

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GQL="$HERE/_gql.sh"

usage() {
  echo "usage: add-to-sprint.sh <SPRINT_ID> <KEY> [--from-fixture <path>]" >&2
  echo "       add-to-sprint.sh <KEY> [--from-fixture <path>]    # legacy one-arg form (no sprint id resolution)" >&2
  exit 2
}

[[ $# -lt 1 ]] && usage

# Disambiguate the two usage forms by checking whether the second positional
# looks like an issue identifier (same regex the jira impl uses).
SPRINT_ID=""
KEY=""
if [[ $# -ge 2 && "$2" =~ ^[A-Z][A-Z0-9]+-[0-9]+$ ]]; then
  SPRINT_ID="$1"
  KEY="$2"
  shift 2
else
  KEY="$1"
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

# Legacy one-arg form has no way to know the cycle id; exit 0 with a stub
# warning so older callers don't break (jira parity).
if [[ -z "$SPRINT_ID" ]]; then
  echo "add-to-sprint.sh: called without a SPRINT_ID; cannot place $KEY. Pass <SPRINT_ID> <KEY>." >&2
  exit 0
fi

gql() { bash "$GQL" "$1" "$2"; }

DATA="$(gql 'query($id: String!) { issue(id: $id) { id } }' "$(jq -nc --arg id "$KEY" '{id: $id}')")" || exit $?
ISSUE_ID="$(printf '%s' "$DATA" | jq -r '.issue.id // empty')"
[[ -n "$ISSUE_ID" ]] || { echo "issue not found: $KEY" >&2; exit 1; }

DATA="$(gql 'mutation($id: String!, $input: IssueUpdateInput!) { issueUpdate(id: $id, input: $input) { success } }' \
            "$(jq -nc --arg id "$ISSUE_ID" --arg cycleId "$SPRINT_ID" '{id: $id, input: {cycleId: $cycleId}}')")" || {
  echo "issueUpdate (cycleId) failed adding $KEY to cycle $SPRINT_ID (auth? cycle id?)" >&2
  exit 3
}
[[ "$(printf '%s' "$DATA" | jq -r '.issueUpdate.success // false')" == "true" ]] || {
  echo "issueUpdate reported success=false adding $KEY to cycle $SPRINT_ID" >&2
  exit 3
}
