#!/usr/bin/env bash
# Add one or more labels to an existing Jira work item. acli's `--labels` is
# additive (it merges with the issue's existing labels), so this never clobbers.
# Used by plan-to-tickets to tag the parent epic with `specto` so milestone-aware
# tools (e.g. the planner's epic discovery) can find specto epics by label instead
# of scanning every epic in the project.
#
# Usage:
#   label-ticket.sh <KEY> <label> [<label>...]
#   label-ticket.sh <KEY> <label>... --from-fixture <path>   # test mode (no write)
#
# Output: nothing on stdout on success; warnings/errors to stderr.
# Exit:
#   0 — labels applied (or test-mode fixture)
#   2 — bad usage
#   3 — acli not on PATH, or the edit failed

set -u
set -o pipefail

usage() {
  echo "usage: label-ticket.sh <KEY> <label> [<label>...] [--from-fixture <path>]" >&2
  exit 2
}

[[ $# -lt 2 ]] && usage
KEY="$1"
shift

LABELS=()
FIXTURE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from-fixture) [[ $# -ge 2 ]] || usage; FIXTURE="$2"; shift 2 ;;
    *) LABELS+=("$1"); shift ;;
  esac
done

[[ ${#LABELS[@]} -ge 1 ]] || usage

if [[ -n "$FIXTURE" ]]; then
  [[ -f "$FIXTURE" ]] || { echo "fixture not found: $FIXTURE" >&2; exit 3; }
  exit 0
fi

if ! command -v acli >/dev/null; then
  echo "acli not on PATH; install Atlassian CLI" >&2
  exit 3
fi

joined="$(IFS=,; echo "${LABELS[*]}")"
if ! acli jira workitem edit --key "$KEY" --labels "$joined" --yes >/dev/null 2>&1; then
  echo "warning: could not apply labels to $KEY: $joined" >&2
  exit 3
fi
