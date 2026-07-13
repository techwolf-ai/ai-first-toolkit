#!/usr/bin/env bash
# Place a GitHub issue in a sprint. Sprint = milestone on this backend
# (documented degradation): the sprint id is the milestone NUMBER (what
# active-sprint.sh emits), resolved to its title via the REST API because
# `gh issue edit --milestone` takes the title, not the number.
#
# Usage (identical to the jira counterpart):
#   add-to-sprint.sh <SPRINT_ID> <KEY>                       # live
#   add-to-sprint.sh <SPRINT_ID> <KEY> --from-fixture <path> # test
#   add-to-sprint.sh <KEY>                                   # legacy one-arg stub
#                                                            # form preserved for
#                                                            # backwards compat
#
# The two-positional form is detected by a numeric second positional (issue
# numbers are bare digits on this backend, mirroring the jira PROJ-NNN check).
#
# Fixture file shapes (test mode only), same as the jira counterpart:
#   {"status": "ok"}                       # success
#   {"status": "error", "error": "..."}    # simulated failure
# OR the legacy active-sprint fixture shape:
#   {"board_id": 12, "active_sprint": {"id": 34, "name": "Sprint 7"}}
#   {"board_id": 12, "active_sprint": null}      # no active sprint -> no-op
#
# Output: nothing on stdout; warnings to stderr.
# Exit:
#   0 - added (or fixture says success, or no-op)
#   2 - bad usage
#   3 - gh not on PATH, milestone unresolvable, or the edit failed

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/_lib.sh"

usage() {
  echo "usage: add-to-sprint.sh <SPRINT_ID> <KEY> [--from-fixture <path>]" >&2
  echo "       add-to-sprint.sh <KEY> [--from-fixture <path>]    # legacy one-arg form (no sprint id resolution)" >&2
  exit 2
}

[[ $# -lt 1 ]] && usage

# Disambiguate the two usage forms: <SPRINT_ID> <KEY> when the second
# positional looks like an issue number, else the legacy <KEY>-only form.
SPRINT_ID=""
KEY=""
if [[ $# -ge 2 && "$2" =~ ^[0-9]+$ ]]; then
  SPRINT_ID="$1"
  KEY="$2"
  shift 2
else
  KEY="$1"
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

# Fixture mode: handle both the {"status": ...} shape and the legacy
# active-sprint fixture shape, mirroring the jira counterpart.
if [[ -n "$FIXTURE" ]]; then
  [[ -f "$FIXTURE" ]] || { echo "fixture not found: $FIXTURE" >&2; exit 3; }
  data="$(cat "$FIXTURE")"
  echo "$data" | jq . >/dev/null 2>&1 || { echo "fixture JSON unparseable: $FIXTURE" >&2; exit 3; }
  status="$(echo "$data" | jq -r '.status // empty')"
  if [[ -n "$status" ]]; then
    case "$status" in
      ok)    exit 0 ;;
      error) echo "fixture: $(echo "$data" | jq -r '.error // "milestone edit failed"')" >&2; exit 3 ;;
      *)     echo "fixture: unknown status: $status" >&2; exit 3 ;;
    esac
  fi
  active="$(echo "$data" | jq -r '.active_sprint // empty')"
  if [[ -z "$active" || "$active" == "null" ]]; then
    echo "no active sprint for #$KEY's board (fixture); no-op" >&2
    exit 0
  fi
  echo "would add #$KEY to active sprint $(echo "$data" | jq -r '.active_sprint.name // .active_sprint.id')" >&2
  exit 0
fi

# Legacy one-arg form has no way to know the sprint id; preserve the stub
# behaviour (warn, exit 0) so older callers don't break.
if [[ -z "$SPRINT_ID" ]]; then
  echo "add-to-sprint.sh: called without a SPRINT_ID; cannot place #$KEY. Pass <SPRINT_ID> <KEY>." >&2
  exit 0
fi

specto_require_gh

# Resolve the milestone number to its title (gh issue edit takes the title).
REPO_PATH="$(specto_gh_repo_path)"
TITLE="$(gh api "$REPO_PATH/milestones/$SPRINT_ID" 2>/dev/null | jq -r '.title // empty')"
if [[ -z "$TITLE" ]]; then
  echo "add-to-sprint.sh: could not resolve milestone $SPRINT_ID (auth? number?)" >&2
  exit 3
fi

if ! gh issue edit "$KEY" --milestone "$TITLE" >/dev/null 2>&1; then
  echo "add-to-sprint.sh: gh issue edit --milestone failed for #$KEY -> $TITLE" >&2
  exit 3
fi
