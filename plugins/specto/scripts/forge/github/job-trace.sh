#!/usr/bin/env bash
# Print the tail (~last 200 lines) of an Actions job's log: the failing tail is
# what implement-ticket needs to attempt a fix. Job ids come from
# pipeline-status.sh (parsed from each failed check's …/job/<id> link).
#
# Live mode tries `gh run view --job <id> --log` first, then falls back to the
# raw log endpoint `GET repos/{o}/{r}/actions/jobs/<id>/logs` (run view needs
# the run to be fully indexed; the raw endpoint works as soon as the job ends).
#
# Usage:
#   job-trace.sh <job-id>                       # live
#   job-trace.sh <job-id> --from-fixture <dir>  # test: reads <dir>/trace-<job-id>.txt
#
# Output: up to the last 200 lines of the trace on stdout. Warnings/errors to stderr.
# Exit:
#   0: trace printed
#   2: bad usage
#   3: gh not on PATH / not in a repo / the API call failed

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
. "$SCRIPT_DIR/_lib.sh"

TAIL_LINES=200

usage() {
  echo "usage: job-trace.sh <job-id> [--from-fixture <dir>]" >&2
  exit 2
}

[[ $# -lt 1 ]] && usage
JOB_ID="$1"
shift

FIXTURE_DIR=""
if [[ $# -gt 0 ]]; then
  if [[ "$1" == "--from-fixture" && $# -ge 2 ]]; then
    FIXTURE_DIR="$2"
    shift 2
  else
    usage
  fi
fi

if [[ -n "$FIXTURE_DIR" ]]; then
  [[ -d "$FIXTURE_DIR" ]] || { echo "fixture dir not found: $FIXTURE_DIR" >&2; exit 3; }
  f="$FIXTURE_DIR/trace-$JOB_ID.txt"
  [[ -f "$f" ]] || { echo "fixture file not found: $f" >&2; exit 3; }
  tail -n "$TAIL_LINES" "$f"
  exit 0
fi

if ! command -v gh >/dev/null; then
  echo "gh not on PATH; install the GitHub CLI" >&2
  exit 3
fi

if out="$(gh run view --job "$JOB_ID" --log 2>/dev/null)" && [[ -n "$out" ]]; then
  printf '%s\n' "$out" | tail -n "$TAIL_LINES"
  exit 0
fi

OWNER_REPO="$(specto_gh_repo)" || { echo "could not resolve the GitHub repo" >&2; exit 3; }
gh api "repos/$OWNER_REPO/actions/jobs/$JOB_ID/logs" 2>/dev/null | tail -n "$TAIL_LINES" || {
  echo "gh failed fetching the log for job $JOB_ID" >&2; exit 3; }
