#!/usr/bin/env bash
# Read a Jira work item's live `.fields.status.name` (e.g. To Do / In Progress /
# Done) and print it on stdout. Sibling of get-ticket-type.sh. Used by the dod
# agent's state-desync check, which must never trust a cached status.
#
# Usage:
#   get-ticket-status.sh <KEY>                       # live: calls acli
#   get-ticket-status.sh <KEY> --from-fixture <path> # test: reads a JSON file
#
# Fixture / acli JSON shape: a work-item object with `.fields.status.name`.
#
# Output: the status string on stdout, newline-terminated. Warnings/errors to stderr.
# Exit:
#   0 — status printed
#   1 — JSON unparseable, or no `.fields.status.name` found
#   2 — bad usage
#   3 — acli not on PATH, or acli call failed

set -u
set -o pipefail

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
  if ! command -v acli >/dev/null; then
    echo "acli not on PATH; install Atlassian CLI" >&2
    exit 3
  fi
  JSON="$(acli jira workitem view "$KEY" --json --fields 'status' 2>/dev/null)" || {
    echo "acli failed (auth? key? network?); run 'acli auth' to verify" >&2
    exit 3
  }
fi

echo "$JSON" | jq . >/dev/null 2>&1 || { echo "JSON unparseable for $KEY" >&2; exit 1; }
STATUS="$(echo "$JSON" | jq -r '.fields.status.name // empty')"
[[ -n "$STATUS" ]] || { echo "no .fields.status.name for $KEY" >&2; exit 1; }
printf '%s\n' "$STATUS"
