#!/usr/bin/env bash
# Read change-classification answers from a Linear epic (parent issue). Linear
# issues have no custom fields, so the answers come from a structured
# `### Change classification` checklist block in the epic issue's description
# (see scripts/tracker/_body-classification.sh for the block format).
#
# The questions are profile-driven, passed by the dispatching skill/agent as
# --questions JSON (see references/compliance-profile.example.yml). Without
# --questions the classification feature is off: the helper prints
# `classification=unconfigured` and exits 0.
#
# Usage (identical to the jira counterpart):
#   epic-fields.sh <epic-key> [--questions <json>] [--from-fixture <path>]
#
# Fixture shape: a raw GraphQL response — {"data":{"issue":{"description":"..."}}}.
#
# Output: the shared key=value contract (flag_<id>=, empty metadata lines,
#   classification=, resolved_via=body). Exit:
#   0 — resolved (unmatched questions default to No with a stderr note)
#   1 — response unparseable / no issue
#   2 — bad usage
#   3 — transport/auth failure (via _gql.sh)

set -u
set -o pipefail

usage() {
  echo "usage: epic-fields.sh <epic-key> [--questions <json>] [--from-fixture <path>]" >&2
  exit 2
}

[[ $# -lt 1 ]] && usage
EPIC_KEY="$1"
shift

FIXTURE=""
QUESTIONS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from-fixture) [[ $# -ge 2 ]] || usage; FIXTURE="$2"; shift 2 ;;
    --questions)    [[ $# -ge 2 ]] || usage; QUESTIONS="$2"; shift 2 ;;
    *) usage ;;
  esac
done

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -n "$QUESTIONS" ]]; then
  echo "$QUESTIONS" | jq -e 'type == "array"' >/dev/null 2>&1 || {
    echo "--questions is not a JSON array" >&2
    exit 2
  }
fi

if [[ -z "$QUESTIONS" ]]; then
  cat <<EOF
development_stage=
epic_type=
delivery_cycle=
classification=unconfigured
resolved_via=body
EOF
  exit 0
fi

QUERY='query($id: String!) { issue(id: $id) { description } }'
VARS="$(jq -nc --arg id "$EPIC_KEY" '{id: $id}')"
if [[ -n "$FIXTURE" ]]; then
  DATA="$("$HERE/_gql.sh" --from-fixture "$FIXTURE" "$QUERY" "$VARS")" || exit $?
else
  DATA="$("$HERE/_gql.sh" "$QUERY" "$VARS")" || exit $?
fi

BODY="$(echo "$DATA" | jq -r '.issue.description // empty')"
if ! echo "$DATA" | jq -e '.issue' >/dev/null 2>&1; then
  echo "no issue found for epic $EPIC_KEY" >&2
  exit 1
fi

. "$HERE/../_body-classification.sh"
specto_classify_from_body "$BODY" "$QUESTIONS"
