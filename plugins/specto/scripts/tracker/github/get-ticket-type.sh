#!/usr/bin/env bash
# Read a GitHub issue's type and print it on stdout. Resolution order:
#   1. the native issue type name (`gh issue view --json issueType`, org-level
#      issue types, gh >= 2.94), e.g. Task / Bug / Feature / Epic
#   2. an issue with sub-issues, or carrying an `epic` label, reads as "Epic"
#      (the epic-detection rule from the adapter design)
#   3. fallback: "Issue"
# Used to probe a would-be-parent before attaching children to it, same role
# as the jira counterpart's Task-as-epic trip-wire probe.
#
# Usage (identical to the jira counterpart):
#   get-ticket-type.sh <KEY>                       # live: calls gh
#   get-ticket-type.sh <KEY> --from-fixture <path> # test: reads a JSON file
#
# Fixture / gh JSON shape: `gh issue view <n> --json issueType,labels,subIssues`.
#
# Output: the type string on stdout, newline-terminated. Warnings/errors to stderr.
# Exit:
#   0 - type printed
#   1 - JSON unparseable
#   2 - bad usage
#   3 - gh not on PATH, or the gh call failed

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/_lib.sh"

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

if [[ -n "$FIXTURE" ]]; then
  [[ -f "$FIXTURE" ]] || { echo "fixture not found: $FIXTURE" >&2; exit 3; }
  JSON="$(cat "$FIXTURE")"
else
  specto_require_gh
  JSON="$(gh issue view "$KEY" --json issueType,labels,subIssues 2>/dev/null)" || {
    echo "gh issue view failed for #$KEY (auth? number?)" >&2
    exit 3
  }
fi

echo "$JSON" | jq . >/dev/null 2>&1 || { echo "JSON unparseable for #$KEY" >&2; exit 1; }

TYPE="$(echo "$JSON" | jq -r '.issueType.name // empty')"
if [[ -n "$TYPE" ]]; then
  printf '%s\n' "$TYPE"
  exit 0
fi

IS_EPIC="$(echo "$JSON" | jq -r '
  (((.subIssues // []) | length) > 0)
  or (( [.labels[]?.name // "" | ascii_downcase | select(. == "epic")] | length) > 0)
')"
if [[ "$IS_EPIC" == "true" ]]; then
  echo "Epic"
else
  echo "Issue"
fi
