#!/usr/bin/env bash
# Resolve the active sprint(s) for this backend: sprint = milestone (documented
# degradation), so "active" means every OPEN milestone of the repo. Pairs with
# create-ticket.sh's --sprint-id flag and add-to-sprint.sh, exactly like the
# jira board flow.
#
# Usage (identical to the jira counterpart):
#   active-sprint.sh <board-id>                       # live
#   active-sprint.sh <board-id> --from-fixture <path> # test
#
# <board-id> mapping: an owner/repo value targets that repo's milestones; any
# other value (a Jira board id, a team name) is accepted and IGNORED, the
# current repo checkout is the board. Repos without milestones cleanly print
# nothing (exit 0): no active sprint, tickets go to the backlog.
#
# Fixture shape (backend-shaped): the REST milestones array
# `gh api repos/{owner}/{repo}/milestones?state=open` returns, e.g.
#   [{"number": 34, "title": "Sprint 7"}, ...]
#
# Output (live + fixture): one TAB-separated `<id>\t<name>` per open milestone
# on stdout; nothing if none. Warnings/errors to stderr.
# Exit:
#   0 - fetched (zero or more open milestones; the empty case is NOT an error)
#   2 - bad usage
#   3 - gh not on PATH, the gh call failed, or the fixture is unusable

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/_lib.sh"

usage() {
  echo "usage: active-sprint.sh <board-id> [--from-fixture <path>]" >&2
  exit 2
}

[[ $# -lt 1 ]] && usage
BOARD_ID="$1"
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

emit_rows() {
  jq -r '.[] | "\(.number)\t\(.title)"'
}

if [[ -n "$FIXTURE" ]]; then
  [[ -f "$FIXTURE" ]] || { echo "fixture not found: $FIXTURE" >&2; exit 3; }
  jq . "$FIXTURE" >/dev/null 2>&1 || { echo "fixture JSON unparseable: $FIXTURE" >&2; exit 3; }
  emit_rows < "$FIXTURE"
  exit 0
fi

specto_require_gh

REPO_PATH="$(specto_gh_repo_path "$BOARD_ID")"
RESP="$(gh api "$REPO_PATH/milestones?state=open" 2>/dev/null)" || {
  echo "gh api milestones failed (auth? repo?)" >&2
  exit 3
}
printf '%s' "$RESP" | emit_rows
