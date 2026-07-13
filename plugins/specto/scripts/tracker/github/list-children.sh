#!/usr/bin/env bash
# List the child issues (native sub-issues) of an epic as a normalized JSON array:
#   [{"key": "101", "summary": "...", "status": "...", "type": "Task"}, ...]
#
# Child status is derived from the sub-issue's state only (sub-issue entries
# carry no labels): OPEN -> "To Do", CLOSED -> "Done" (documented degradation;
# get-ticket-status.sh on the child itself also honors status:* labels).
# Child type is the native issue type name, fallback "Issue".
#
# Usage (identical to the jira counterpart):
#   list-children.sh <EPIC-KEY>                       # live: calls gh
#   list-children.sh <EPIC-KEY> --from-fixture <path> # test: reads a JSON file
#
# Fixture / gh JSON shape: `gh issue view <n> --json subIssues`, i.e.
#   {"subIssues": [{"number": 101, "title": "...", "state": "OPEN",
#                   "issueType": {"name": "Task"}}, ...]}
#
# Output: the normalized JSON array on stdout (possibly []). Warnings to stderr.
# Exit:
#   0 - array printed
#   1 - JSON unparseable / no recognizable sub-issue array
#   2 - bad usage
#   3 - gh not on PATH, or the gh call failed

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/_lib.sh"

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

if [[ -n "$FIXTURE" ]]; then
  [[ -f "$FIXTURE" ]] || { echo "fixture not found: $FIXTURE" >&2; exit 3; }
  JSON="$(cat "$FIXTURE")"
else
  specto_require_gh
  JSON="$(gh issue view "$EPIC" --json subIssues 2>/dev/null)" || {
    echo "gh issue view failed for #$EPIC (auth? number?)" >&2
    exit 3
  }
fi

echo "$JSON" | jq . >/dev/null 2>&1 || { echo "JSON unparseable for children of #$EPIC" >&2; exit 1; }

echo "$JSON" | jq -e '
  (.subIssues // null)
  | if type == "array" then
      map({key: (.number | tostring),
           summary: (.title // ""),
           status: (if ((.state // "") | ascii_downcase) == "closed" then "Done" else "To Do" end),
           type: (.issueType.name // "Issue")})
    else error("no sub-issue array") end
' 2>/dev/null || { echo "no recognizable sub-issue array for children of #$EPIC" >&2; exit 1; }
