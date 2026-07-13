#!/usr/bin/env bash
# Read a GitHub issue's current sprint id. Sprint = milestone on this backend
# (documented degradation), so this prints the assigned milestone's number, or
# nothing when the issue has no milestone. A CLOSED milestone reads as "not in
# an active sprint" (empty), mirroring the jira backend's active-only filter.
#
# Usage (identical to the jira counterpart):
#   get-ticket-sprint.sh <KEY>                       # live: calls gh
#   get-ticket-sprint.sh <KEY> --from-fixture <path> # test: reads a JSON file
#
# Fixture / gh JSON shape: `gh issue view <n> --json milestone`, i.e.
#   {"milestone": {"number": 34, "title": "Sprint 7", "state": "OPEN"}}
#   {"milestone": null}
#
# Output: the milestone number on stdout, newline-terminated; nothing if the
# issue is not in an open milestone. Warnings/errors to stderr.
# Exit:
#   0 - sprint id printed, OR no active sprint (clean exit, empty stdout)
#   1 - JSON unparseable
#   2 - bad usage
#   3 - gh not on PATH, or the gh call failed

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/_lib.sh"

usage() {
  echo "usage: get-ticket-sprint.sh <KEY> [--from-fixture <path>]" >&2
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
  JSON="$(gh issue view "$KEY" --json milestone 2>/dev/null)" || {
    echo "gh issue view failed for #$KEY (auth? number?)" >&2
    exit 3
  }
fi

echo "$JSON" | jq . >/dev/null 2>&1 || { echo "JSON unparseable for #$KEY" >&2; exit 1; }

# The milestone must exist and not be closed (a closed milestone is a past
# sprint, not the current one).
SPRINT_ID="$(echo "$JSON" | jq -r '
  .milestone // empty
  | select(((.state // "open") | ascii_downcase) != "closed")
  | .number
')"
[[ -n "$SPRINT_ID" ]] && printf '%s\n' "$SPRINT_ID"
exit 0
