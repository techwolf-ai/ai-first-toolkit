#!/usr/bin/env bash
# Read a Jira work item's `.fields.issuetype.name` (the type, e.g. Epic / Task /
# Bug / Story / Test Plan) and print it on stdout. Sibling of
# get-ticket-summary.sh. Used to probe a would-be-parent before passing it to
# `--parent`: `acli` rejects with "Given parent work item does not belong to
# appropriate hierarchy" when the supposed epic is actually a Task (a common convention
# of labelling some Tasks "epics" in human speech is the trip wire). Callers
# (create-ticket, create-test-plan, plan-to-tickets) probe with this helper
# and fall back to a `Relates` link when the parent isn't a true Epic.
#
# Usage:
#   get-ticket-type.sh <KEY>                       # live: calls acli
#   get-ticket-type.sh <KEY> --from-fixture <path> # test: reads a JSON file
#
# Fixture / acli JSON shape: a work-item object with `.fields.issuetype.name`.
#
# Output: the type string on stdout, newline-terminated. Warnings/errors to stderr.
# Exit:
#   0 — type printed
#   1 — JSON unparseable, or no `.fields.issuetype.name` found
#   2 — bad usage
#   3 — acli not on PATH, or acli call failed

set -u
set -o pipefail

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
  if ! command -v acli >/dev/null; then
    echo "acli not on PATH; install Atlassian CLI" >&2
    exit 3
  fi
  JSON="$(acli jira workitem view "$KEY" --json --fields 'issuetype' 2>/dev/null)" || {
    echo "acli failed (auth? key? network?); run 'acli auth' to verify" >&2
    exit 3
  }
fi

echo "$JSON" | jq . >/dev/null 2>&1 || { echo "JSON unparseable for $KEY" >&2; exit 1; }
TYPE="$(echo "$JSON" | jq -r '.fields.issuetype.name // empty')"
[[ -n "$TYPE" ]] || { echo "no .fields.issuetype.name for $KEY" >&2; exit 1; }
printf '%s\n' "$TYPE"
