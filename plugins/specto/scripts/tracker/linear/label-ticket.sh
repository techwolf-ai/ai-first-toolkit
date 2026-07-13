#!/usr/bin/env bash
# Add one or more labels to an existing Linear issue. issueAddLabel is
# additive by construction (one label per call, existing labels untouched),
# so this never clobbers. Labels are found case-insensitively and created via
# issueLabelCreate when missing. Mirrors the jira counterpart's argv.
#
# Usage:
#   label-ticket.sh <KEY> <label> [<label>...]
#   label-ticket.sh <KEY> <label>... --from-fixture <path>   # test mode (no write)
#
# --from-fixture <path>: the fixture is a raw GraphQL issueAddLabel response;
#   label find/create and the issue lookup are live-only.
#
# Output: nothing on stdout on success; warnings/errors to stderr.
# Exit:
#   0 - labels applied (or fixture says success)
#   1 - the issue key did not resolve
#   2 - bad usage
#   3 - auth/transport failure, or a label find/create/apply failed

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GQL="$HERE/_gql.sh"

usage() {
  echo "usage: label-ticket.sh <KEY> <label> [<label>...] [--from-fixture <path>]" >&2
  exit 2
}

[[ $# -lt 2 ]] && usage
KEY="$1"
shift

LABELS=()
FIXTURE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from-fixture) [[ $# -ge 2 ]] || usage; FIXTURE="$2"; shift 2 ;;
    *) LABELS+=("$1"); shift ;;
  esac
done

[[ ${#LABELS[@]} -ge 1 ]] || usage

if [[ -n "$FIXTURE" ]]; then
  DATA="$(bash "$GQL" --from-fixture "$FIXTURE" 'mutation' '{}')" || exit $?
  [[ "$(printf '%s' "$DATA" | jq -r '.issueAddLabel.success // false')" == "true" ]] || {
    echo "fixture: issueAddLabel success=false" >&2
    exit 3
  }
  exit 0
fi

gql() { bash "$GQL" "$1" "$2"; }

DATA="$(gql 'query($id: String!) { issue(id: $id) { id } }' "$(jq -nc --arg id "$KEY" '{id: $id}')")" || exit $?
ISSUE_ID="$(printf '%s' "$DATA" | jq -r '.issue.id // empty')"
[[ -n "$ISSUE_ID" ]] || { echo "issue not found: $KEY" >&2; exit 1; }

# Find-or-create a label by name (case-insensitive find; workspace-level
# create). Prints the label id.
ensure_label() {
  local name="$1" data id
  data="$(gql 'query($name: String!) { issueLabels(filter: {name: {eqIgnoreCase: $name}}) { nodes { id name } } }' \
              "$(jq -nc --arg name "$name" '{name: $name}')")" || return 3
  id="$(printf '%s' "$data" | jq -r '.issueLabels.nodes[0].id // empty')"
  if [[ -z "$id" ]]; then
    data="$(gql 'mutation($input: IssueLabelCreateInput!) { issueLabelCreate(input: $input) { success issueLabel { id } } }' \
                "$(jq -nc --arg name "$name" '{input: {name: $name}}')")" || return 3
    id="$(printf '%s' "$data" | jq -r '.issueLabelCreate.issueLabel.id // empty')"
  fi
  [[ -n "$id" ]] || { echo "could not find or create Linear label '$name'" >&2; return 3; }
  printf '%s' "$id"
}

for name in "${LABELS[@]}"; do
  LABEL_ID="$(ensure_label "$name")" || exit 3
  DATA="$(gql 'mutation($id: String!, $labelId: String!) { issueAddLabel(id: $id, labelId: $labelId) { success } }' \
              "$(jq -nc --arg id "$ISSUE_ID" --arg labelId "$LABEL_ID" '{id: $id, labelId: $labelId}')")" || {
    echo "warning: could not apply label to $KEY: $name" >&2
    exit 3
  }
  [[ "$(printf '%s' "$DATA" | jq -r '.issueAddLabel.success // false')" == "true" ]] || {
    echo "warning: issueAddLabel reported success=false for $KEY: $name" >&2
    exit 3
  }
done
