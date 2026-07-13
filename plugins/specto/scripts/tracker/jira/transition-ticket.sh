#!/usr/bin/env bash
# Transition a Jira work item to a target status, with workflow-name fallback
# discovery. Project workflows name their columns differently ("To Do" vs
# "Backlog" vs "Selected for Development", ...), so this helper tries the literal
# name first and then walks a list of known synonyms. It warns to stderr which
# name actually matched.
#
# `acli jira workitem transition` has no "list available transitions" flag, so in
# live mode the fallback is implemented as attempt-and-retry: try the literal
# status; on failure try each synonym in turn; the first that succeeds wins.
# In --from-fixture mode the fixture supplies the available-transitions list (a
# JSON array of status names) and the helper picks the first canonical/synonym
# present in that list — exercising the same selection logic without a network call.
#
# Usage:
#   transition-ticket.sh <KEY> <target-status>                       # live
#   transition-ticket.sh <KEY> <target-status> --from-fixture <path> # test
#
# Fixture file shape:  ["Backlog", "In Progress", "Code Review", "Done"]
#
# Output: on success prints `transitioned_to=<name>` to stdout; warnings to stderr.
# Exit:
#   0 — transitioned (literal or a synonym matched)
#   1 — no literal/synonym name was accepted by the workflow
#   2 — bad usage
#   3 — acli not on PATH, or every acli transition attempt errored out

set -u
set -o pipefail

usage() {
  echo "usage: transition-ticket.sh <KEY> <target-status> [--from-fixture <path>]" >&2
  exit 2
}

[[ $# -lt 2 ]] && usage
KEY="$1"
TARGET="$2"
shift 2

FIXTURE=""
if [[ $# -gt 0 ]]; then
  if [[ "$1" == "--from-fixture" && $# -ge 2 ]]; then
    FIXTURE="$2"
    shift 2
  else
    usage
  fi
fi

# Build the candidate list: the literal target first, then known synonyms keyed
# off the canonical name. Bash 3.2 — no associative arrays, so a case statement.
# (Each synonym is a separate array element so multi-word names stay intact.)
candidates=("$TARGET")
case "$TARGET" in
  "To Do")       candidates+=("Backlog" "Open" "Selected for Development") ;;
  "In Progress") candidates+=("Doing" "Started" "In Development") ;;
  "In Review")   candidates+=("Code Review" "Review" "In Code Review" "Peer Review") ;;
  "Done")        candidates+=("Closed" "Resolved" "Complete") ;;
esac

if [[ -n "$FIXTURE" ]]; then
  [[ -f "$FIXTURE" ]] || { echo "fixture not found: $FIXTURE" >&2; exit 3; }
  available="$(cat "$FIXTURE")"
  echo "$available" | jq . >/dev/null 2>&1 || { echo "fixture JSON unparseable: $FIXTURE" >&2; exit 1; }
  for name in "${candidates[@]}"; do
    if echo "$available" | jq -e --arg n "$name" 'index($n) != null' >/dev/null 2>&1; then
      if [[ "$name" != "$TARGET" ]]; then
        echo "note: target status '$TARGET' not in workflow; matched synonym '$name'" >&2
      fi
      echo "transitioned_to=$name"
      exit 0
    fi
  done
  echo "no workflow status matched '$TARGET' or its known synonyms (available: $available)" >&2
  exit 1
fi

if ! command -v acli >/dev/null; then
  echo "acli not on PATH; install Atlassian CLI" >&2
  exit 3
fi

errored=1   # tracks "every attempt was an outright acli error" vs "name rejected"
for name in "${candidates[@]}"; do
  if acli jira workitem transition --key "$KEY" --status "$name" --yes >/dev/null 2>&1; then
    if [[ "$name" != "$TARGET" ]]; then
      echo "note: target status '$TARGET' not in workflow for $KEY; matched synonym '$name'" >&2
    fi
    echo "transitioned_to=$name"
    exit 0
  fi
  errored=0  # at least one attempt ran (and was rejected) — not an infra error
done

if (( errored == 1 )); then
  echo "acli transition failed for $KEY (auth? key?)" >&2
  exit 3
fi
echo "no workflow status matched '$TARGET' or its known synonyms for $KEY" >&2
exit 1
