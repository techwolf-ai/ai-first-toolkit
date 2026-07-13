#!/usr/bin/env bash
# Set the assignee on a Jira work item, and best-effort ensure the reporter is set
# too (B2: children created by plan-to-tickets must not land unassigned / with a
# stale reporter). Assignee uses `acli jira workitem assign`; reporter is set via
# `acli jira workitem edit --from-json` when the project allows it (some workflows
# lock the reporter field — that's a warning, not a failure).
#
# Usage:
#   assign-ticket.sh <KEY> [<assignee>]                       # default assignee: @me
#   assign-ticket.sh <KEY> [<assignee>] --from-fixture <path> # test mode
#
# Output: nothing on stdout on success; warnings/errors to stderr.
# Exit:
#   0 — assignee set (reporter set or warned-and-skipped)
#   2 — bad usage
#   3 — acli not on PATH, or the assignee call failed

set -u
set -o pipefail

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

if ! command -v acli >/dev/null; then
  echo "acli not on PATH; install Atlassian CLI" >&2
  exit 3
fi

if ! acli jira workitem assign --key "$KEY" --assignee "$ASSIGNEE" --yes >/dev/null 2>&1; then
  echo "acli assign failed on $KEY -> $ASSIGNEE (auth? key? unknown user?)" >&2
  exit 3
fi

# Best-effort reporter set. '@me' / 'default' aren't valid reporter values, so only
# attempt when the caller passed an explicit account ID / email.
if [[ "$ASSIGNEE" != "@me" && "$ASSIGNEE" != "default" ]]; then
  tmp_json="$(mktemp -t specto-assign.XXXXXX)"
  printf '{"reporter": "%s"}\n' "$ASSIGNEE" > "$tmp_json"
  if ! acli jira workitem edit --key "$KEY" --from-json "$tmp_json" --yes >/dev/null 2>&1; then
    echo "warning: could not set reporter on $KEY (field may be locked by the workflow); assignee is set" >&2
  fi
  rm -f "$tmp_json"
fi
