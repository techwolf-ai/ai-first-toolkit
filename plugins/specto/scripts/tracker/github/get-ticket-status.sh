#!/usr/bin/env bash
# Read a GitHub issue's live status and print it on stdout. GitHub issues have
# two states, so the mapping (documented degradation) is:
#   state closed              -> "Done" (a stale status:* label never shadows a
#                                closed issue; state wins when closed)
#   state open + status:<v>   -> the label value, rendered as a display name
#                                (status:in_progress -> "In Progress",
#                                 status:in_review -> "In Review"; unknown
#                                 values print verbatim)
#   state open, no label      -> "To Do"
# The status:* labels are what transition-ticket.sh writes for the two
# in-between canonical statuses.
#
# Usage (identical to the jira counterpart):
#   get-ticket-status.sh <KEY>                       # live: calls gh
#   get-ticket-status.sh <KEY> --from-fixture <path> # test: reads a JSON file
#
# Fixture / gh JSON shape: `gh issue view <n> --json state,labels`, i.e.
#   {"state": "OPEN", "labels": [{"name": "status:in_review"}, ...]}
#
# Output: the status string on stdout, newline-terminated. Warnings/errors to stderr.
# Exit:
#   0 - status printed
#   1 - JSON unparseable, or no .state found
#   2 - bad usage
#   3 - gh not on PATH, or the gh call failed

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/_lib.sh"

usage() {
  echo "usage: get-ticket-status.sh <KEY> [--from-fixture <path>]" >&2
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
  JSON="$(gh issue view "$KEY" --json state,labels 2>/dev/null)" || {
    echo "gh issue view failed for #$KEY (auth? number?)" >&2
    exit 3
  }
fi

echo "$JSON" | jq . >/dev/null 2>&1 || { echo "JSON unparseable for #$KEY" >&2; exit 1; }

STATE="$(echo "$JSON" | jq -r '.state // empty' | tr '[:lower:]' '[:upper:]')"
[[ -n "$STATE" ]] || { echo "no .state for #$KEY" >&2; exit 1; }

if [[ "$STATE" == "CLOSED" ]]; then
  echo "Done"
  exit 0
fi

STATUS_LABEL="$(echo "$JSON" | jq -r '[.labels[]?.name // "" | select(startswith("status:"))] | first // empty')"
if [[ -n "$STATUS_LABEL" ]]; then
  value="${STATUS_LABEL#status:}"
  case "$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]' | tr ' -' '__')" in
    in_progress) echo "In Progress" ;;
    in_review)   echo "In Review" ;;
    todo|to_do)  echo "To Do" ;;
    done)        echo "Done" ;;
    *)           printf '%s\n' "$value" ;;
  esac
  exit 0
fi

echo "To Do"
