#!/usr/bin/env bash
# Read a Jira work item's current active sprint id (if any) from the standard
# Sprint customfield (`customfield_10020`). Prints the sprint id on stdout;
# empty stdout means "not in a sprint" (backlog). Sibling of
# get-ticket-summary.sh / get-ticket-type.sh / get-ticket-parent.sh.
#
# Used by create-test-plan to mirror the implementation ticket's sprint onto
# the Test Plan via add-to-sprint.sh.
#
# Usage:
#   get-ticket-sprint.sh <KEY>                       # live: calls acli
#   get-ticket-sprint.sh <KEY> --from-fixture <path> # test: reads a JSON file
#
# Fixture / acli JSON shape: a work-item object whose
# `.fields.customfield_10020` is either an array of sprint objects (each with
# `.id` and `.state`) — Jira's standard Sprint customfield shape — or null.
# We pick the FIRST sprint whose state is "active". If none are active, exit
# clean with empty stdout (a closed-only ticket is "no current sprint").
#
# Output: the sprint id (numeric) on stdout, newline-terminated; nothing if
# the ticket is not in an active sprint. Warnings/errors to stderr.
# Exit:
#   0 — sprint id printed, OR no active sprint (clean exit, empty stdout)
#   1 — JSON unparseable
#   2 — bad usage
#   3 — acli not on PATH, or acli call failed

set -u
set -o pipefail

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
  if ! command -v acli >/dev/null; then
    echo "acli not on PATH; install Atlassian CLI" >&2
    exit 3
  fi
  JSON="$(acli jira workitem view "$KEY" --json --fields 'customfield_10020' 2>/dev/null)" || {
    echo "acli failed (auth? key? network?); run 'acli auth' to verify" >&2
    exit 3
  }
fi

echo "$JSON" | jq . >/dev/null 2>&1 || { echo "JSON unparseable for $KEY" >&2; exit 1; }

# Pick the first ACTIVE sprint (Jira can have multiple sprints in the array
# when a ticket has spanned several; only the currently-active one is the
# right mirror target).
SPRINT_ID="$(echo "$JSON" | jq -r '
  [.fields.customfield_10020[]?
    | select(.state == "active")
    | .id
  ] | first // empty
')"
[[ -n "$SPRINT_ID" ]] && printf '%s\n' "$SPRINT_ID"
exit 0
