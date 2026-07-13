#!/usr/bin/env bash
# Read a Jira work item's `.fields.summary` (the ticket title) and print it on
# stdout — the single vetted read path for "what is this ticket called?".
# get-ticket-description.sh covers the description body; this helper covers the
# title. Callers (create-test-plan, future MR-title rendering in create-mr /
# implement-ticket) shell out to this instead of inlining `acli jira workitem
# view | jq '.fields.summary'`.
#
# Usage:
#   get-ticket-summary.sh <KEY>                       # live: calls acli
#   get-ticket-summary.sh <KEY> --from-fixture <path> # test: reads a JSON file
#
# The fixture / acli JSON is a work-item object; the summary is at
# `.fields.summary` — same shape get-ticket-description.sh reads.
#
# Output: the summary string on stdout, newline-terminated. Warnings/errors to stderr.
# Exit:
#   0 — summary printed
#   1 — JSON unparseable, or no `.fields.summary` found
#   2 — bad usage
#   3 — acli not on PATH, or acli call failed

set -u
set -o pipefail

usage() {
  echo "usage: get-ticket-summary.sh <KEY> [--from-fixture <path>]" >&2
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
  JSON="$(acli jira workitem view "$KEY" --json --fields 'summary' 2>/dev/null)" || {
    echo "acli failed (auth? key? network?); run 'acli auth' to verify" >&2
    exit 3
  }
fi

echo "$JSON" | jq . >/dev/null 2>&1 || { echo "JSON unparseable for $KEY" >&2; exit 1; }
SUMMARY="$(echo "$JSON" | jq -r '.fields.summary // empty')"
[[ -n "$SUMMARY" ]] || { echo "no .fields.summary for $KEY" >&2; exit 1; }
printf '%s\n' "$SUMMARY"
