#!/usr/bin/env bash
# Set the assignee on a GitHub issue via `gh issue edit --add-assignee`.
# GitHub has no reporter field, so the jira backend's best-effort reporter
# write has no equivalent here (the issue author is immutable).
#
# Usage (identical to the jira counterpart):
#   assign-ticket.sh <KEY> [<assignee>]                       # default assignee: @me
#   assign-ticket.sh <KEY> [<assignee>] --from-fixture <path> # test mode
#
# Output: nothing on stdout on success; warnings/errors to stderr.
# Exit:
#   0 - assignee set
#   2 - bad usage
#   3 - gh not on PATH, or the edit failed

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/_lib.sh"

usage() {
  echo "usage: assign-ticket.sh <KEY> [<assignee>] [--from-fixture <path>]" >&2
  exit 2
}

[[ $# -lt 1 ]] && usage
KEY="$1"
shift

ASSIGNEE="@me"
if [[ $# -gt 0 && "$1" != "--from-fixture" ]]; then
  ASSIGNEE="$1"
  shift
fi

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
  exit 0
fi

specto_require_gh

if ! gh issue edit "$KEY" --add-assignee "$ASSIGNEE" >/dev/null 2>&1; then
  echo "gh issue edit --add-assignee failed on #$KEY -> $ASSIGNEE (auth? number? unknown user?)" >&2
  exit 3
fi
