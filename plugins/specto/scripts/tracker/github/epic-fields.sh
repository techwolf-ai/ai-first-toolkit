#!/usr/bin/env bash
# Read change-classification answers from a GitHub epic issue. GitHub issues
# have no custom fields, so the answers come from a structured
# `### Change classification` checklist block in the epic issue's body
# (see scripts/tracker/_body-classification.sh for the block format).
#
# The questions are profile-driven, passed by the dispatching skill/agent as
# --questions JSON (see references/compliance-profile.example.yml). Without
# --questions the classification feature is off: the helper prints
# `classification=unconfigured` and exits 0.
#
# Usage (identical to the jira counterpart):
#   epic-fields.sh <epic-number> [--questions <json>] [--from-fixture <path>]
#
# Fixture / gh JSON shape: `gh issue view --json body` — {"body": "..."}.
#
# Output: the shared key=value contract (flag_<id>=, empty metadata lines,
#   classification=, resolved_via=body). Exit:
#   0 — resolved (unmatched questions default to No with a stderr note)
#   1 — JSON unparseable
#   2 — bad usage
#   3 — gh not on PATH, or gh call failed

set -u
set -o pipefail

usage() {
  echo "usage: epic-fields.sh <epic-number> [--questions <json>] [--from-fixture <path>]" >&2
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

if [[ -n "$FIXTURE" ]]; then
  [[ -f "$FIXTURE" ]] || { echo "fixture not found: $FIXTURE" >&2; exit 2; }
  JSON="$(cat "$FIXTURE")"
else
  . "$HERE/_lib.sh"
  specto_require_gh
  JSON="$(gh issue view "$EPIC_KEY" --json body 2>/dev/null)" || {
    echo "gh issue view failed (auth? number? network?); run 'gh auth status' to verify" >&2
    exit 3
  }
fi

echo "$JSON" | jq . >/dev/null 2>&1 || { echo "JSON unparseable for epic $EPIC_KEY" >&2; exit 1; }
BODY="$(echo "$JSON" | jq -r '.body // ""')"

. "$HERE/../_body-classification.sh"
specto_classify_from_body "$BODY" "$QUESTIONS"
