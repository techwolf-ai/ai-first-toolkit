#!/usr/bin/env bash
# Transition a GitHub issue to a target status. GitHub issues have exactly two
# states (open / closed), so the canonical statuses map as:
#   done                    -> gh issue close
#   todo                    -> gh issue reopen
#   in_progress / in_review -> add a status:<v> label + warn (documented
#                              degradation: there is no such state to move to)
#
# The same synonym walking as the jira backend applies, case-insensitively:
# the literal canonical token, the display name, and the known Jira workflow
# synonyms all resolve ("Closed" -> Done, "Code Review" -> In Review, ...).
# A note goes to stderr whenever the input was not the resolved display name.
# Status labels are swapped, not stacked: moving to in_review removes
# status:in_progress (and vice versa); close/reopen best-effort clears both.
#
# Usage (identical to the jira counterpart):
#   transition-ticket.sh <KEY> <target-status>                       # live
#   transition-ticket.sh <KEY> <target-status> --from-fixture <path> # test
#
# Fixture: any existing file (presence = the write would succeed); there is no
# workflow list to consult on this backend, so fixture mode exercises the
# status-resolution logic and prints the decision line without touching gh.
#
# Output: on success prints `transitioned_to=<name>` to stdout; warnings to stderr.
# Exit:
#   0 - transitioned (or label degradation applied)
#   1 - the target status maps to no canonical github action
#   2 - bad usage
#   3 - gh not on PATH, or a gh call failed

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/_lib.sh"

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

# A named-but-missing fixture is an infra error (exit 3) regardless of the
# target, mirroring the jira counterpart's check order.
if [[ -n "$FIXTURE" && ! -f "$FIXTURE" ]]; then
  echo "fixture not found: $FIXTURE" >&2
  exit 3
fi

# Resolve the target to a canonical status. Same synonym set as the jira
# backend's fallback walk, plus the canonical machine tokens from
# docs/adapter-contract.md; case-insensitive because there is no live workflow
# to try literal names against.
lc_target="$(printf '%s' "$TARGET" | tr '[:upper:]' '[:lower:]')"
case "$lc_target" in
  todo|"to do"|backlog|open|"selected for development")
    CANON="todo";        DISPLAY="To Do" ;;
  in_progress|"in progress"|doing|started|"in development")
    CANON="in_progress"; DISPLAY="In Progress" ;;
  in_review|"in review"|"code review"|review|"in code review"|"peer review")
    CANON="in_review";   DISPLAY="In Review" ;;
  done|closed|resolved|complete)
    CANON="done";        DISPLAY="Done" ;;
  *)
    echo "no github status mapping for '$TARGET' (known: todo / in_progress / in_review / done plus the jira workflow synonyms)" >&2
    exit 1 ;;
esac
if [[ "$TARGET" != "$DISPLAY" ]]; then
  echo "note: target status '$TARGET' resolved to '$DISPLAY' on github" >&2
fi

if [[ -n "$FIXTURE" ]]; then
  echo "transitioned_to=$DISPLAY"
  exit 0
fi

specto_require_gh

case "$CANON" in
  done|todo)
    state="$(gh issue view "$KEY" --json state 2>/dev/null | jq -r '.state // empty' | tr '[:lower:]' '[:upper:]')"
    [[ -n "$state" ]] || { echo "gh issue view failed for #$KEY (auth? number?)" >&2; exit 3; }
    if [[ "$CANON" == "done" ]]; then
      if [[ "$state" == "CLOSED" ]]; then
        echo "note: #$KEY is already closed" >&2
      else
        gh issue close "$KEY" >/dev/null 2>&1 || { echo "gh issue close failed for #$KEY" >&2; exit 3; }
      fi
    else
      if [[ "$state" == "OPEN" ]]; then
        echo "note: #$KEY is already open" >&2
      else
        gh issue reopen "$KEY" >/dev/null 2>&1 || { echo "gh issue reopen failed for #$KEY" >&2; exit 3; }
      fi
    fi
    # A stale status label would shadow the state in get-ticket-status.sh's
    # open-issue read, so clear both (best-effort: labels may not exist).
    gh issue edit "$KEY" --remove-label "status:in_progress" --remove-label "status:in_review" >/dev/null 2>&1 || true
    ;;
  in_progress|in_review)
    label="status:$CANON"
    other="status:in_review"
    [[ "$CANON" == "in_review" ]] && other="status:in_progress"
    if ! gh issue edit "$KEY" --add-label "$label" --remove-label "$other" >/dev/null 2>&1; then
      # Most likely the label does not exist in the repo yet (gh does not
      # auto-create). Create it and retry once, without the swap.
      gh label create "$label" --color ededed --description "created by specto" >/dev/null 2>&1 || true
      gh issue edit "$KEY" --add-label "$label" >/dev/null 2>&1 || { echo "gh issue edit --add-label failed for #$KEY" >&2; exit 3; }
    fi
    echo "warning: github issues have no '$DISPLAY' state; applied label $label instead (documented degradation)" >&2
    ;;
esac

echo "transitioned_to=$DISPLAY"
