#!/usr/bin/env bash
# Transition a Linear issue to a target workflow state, with the same
# synonym-walking the jira impl uses. Unlike acli, Linear exposes the team's
# real state list (issue.team.states), so the walk is a plain lookup: try the
# literal name first, then each known synonym, against the actual states; the
# first present name wins, then issueUpdate(stateId) applies it. It warns to
# stderr when a synonym (not the literal) matched.
#
# Usage:
#   transition-ticket.sh <KEY> <target-status>                       # live
#   transition-ticket.sh <KEY> <target-status> --from-fixture <path> # test
#
# --from-fixture <path>: the fixture is the raw GraphQL states-query response:
#   {"data":{"issue":{"id":"...","team":{"states":{"nodes":[{"id":"s1","name":"Backlog"},...]}}}}}
#   Fixture mode exercises the selection logic and prints the decision line
#   without a mutation (no network), mirroring the jira fixture behavior.
#
# Output: on success prints `transitioned_to=<name>` to stdout; warnings to stderr.
# Exit:
#   0 - transitioned (literal or a synonym matched)
#   1 - no literal/synonym name exists in the team's workflow (available
#       states listed on stderr), or the issue key did not resolve
#   2 - bad usage
#   3 - auth/transport failure, or the issueUpdate mutation failed

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GQL="$HERE/_gql.sh"

usage() {
  echo "usage: transition-ticket.sh <KEY> <target-status> [--from-fixture <path>]" >&2
  exit 2
}

[[ $# -lt 2 ]] && usage
KEY="$1"
TARGET="$2"
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

# Candidate list: the literal target first, then known synonyms keyed off the
# canonical name. Same table as the jira impl (bash 3.2: case, not assoc arrays).
candidates=("$TARGET")
case "$TARGET" in
  "To Do")       candidates+=("Backlog" "Open" "Selected for Development" "Todo") ;;
  "In Progress") candidates+=("Doing" "Started" "In Development") ;;
  "In Review")   candidates+=("Code Review" "Review" "In Code Review" "Peer Review") ;;
  "Done")        candidates+=("Closed" "Resolved" "Complete") ;;
esac

# Fetch the issue id + the team's state list (fixture or live: same query).
STATES_Q='query($id: String!) { issue(id: $id) { id team { states { nodes { id name } } } } }'
if [[ -n "$FIXTURE" ]]; then
  DATA="$(bash "$GQL" --from-fixture "$FIXTURE" "$STATES_Q" '{}')" || exit $?
else
  DATA="$(bash "$GQL" "$STATES_Q" "$(jq -nc --arg id "$KEY" '{id: $id}')")" || exit $?
fi

ISSUE_ID="$(printf '%s' "$DATA" | jq -r '.issue.id // empty')"
[[ -n "$ISSUE_ID" ]] || { echo "issue not found: $KEY" >&2; exit 1; }
AVAILABLE="$(printf '%s' "$DATA" | jq -c '[.issue.team.states.nodes[]?.name]')"

MATCHED=""
STATE_ID=""
for name in "${candidates[@]}"; do
  STATE_ID="$(printf '%s' "$DATA" | jq -r --arg n "$name" '[.issue.team.states.nodes[]? | select(.name == $n) | .id] | first // empty')"
  if [[ -n "$STATE_ID" ]]; then
    MATCHED="$name"
    break
  fi
done

if [[ -z "$MATCHED" ]]; then
  echo "no workflow status matched '$TARGET' or its known synonyms (available: $AVAILABLE)" >&2
  exit 1
fi

if [[ -n "$FIXTURE" ]]; then
  if [[ "$MATCHED" != "$TARGET" ]]; then
    echo "note: target status '$TARGET' not in workflow; matched synonym '$MATCHED'" >&2
  fi
  echo "transitioned_to=$MATCHED"
  exit 0
fi

DATA="$(bash "$GQL" 'mutation($id: String!, $input: IssueUpdateInput!) { issueUpdate(id: $id, input: $input) { success } }' \
             "$(jq -nc --arg id "$ISSUE_ID" --arg stateId "$STATE_ID" '{id: $id, input: {stateId: $stateId}}')")" || {
  echo "issueUpdate (stateId) failed for $KEY (auth? key?)" >&2
  exit 3
}
[[ "$(printf '%s' "$DATA" | jq -r '.issueUpdate.success // false')" == "true" ]] || {
  echo "issueUpdate reported success=false for $KEY" >&2
  exit 3
}

if [[ "$MATCHED" != "$TARGET" ]]; then
  echo "note: target status '$TARGET' not in workflow for $KEY; matched synonym '$MATCHED'" >&2
fi
echo "transitioned_to=$MATCHED"
