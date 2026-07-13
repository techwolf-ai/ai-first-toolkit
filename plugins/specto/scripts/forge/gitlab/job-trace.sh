#!/usr/bin/env bash
# Print the tail (~last 200 lines) of a CI job's trace log — the failing tail is
# what implement-ticket needs to attempt a fix. Live mode uses
#   GET projects/<id>/jobs/<job-id>/trace
# (`glab ci trace` streams interactively, which isn't script-friendly).
#
# Usage:
#   job-trace.sh <job-id>                       # live
#   job-trace.sh <job-id> --from-fixture <dir>  # test: reads <dir>/trace-<job-id>.txt
#
# Output: up to the last 200 lines of the trace on stdout. Warnings/errors to stderr.
# Exit:
#   0 — trace printed
#   2 — bad usage
#   3 — glab not on PATH / not in a repo / the API call failed

set -u
set -o pipefail

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

if ! command -v glab >/dev/null; then
  echo "glab not on PATH; install the GitLab CLI" >&2
  exit 3
fi
PROJECT_ID="$(glab repo view --output json 2>/dev/null | jq -r '.id // empty')" || true
[[ -n "$PROJECT_ID" ]] || { echo "could not resolve the GitLab project" >&2; exit 3; }

glab api "projects/$PROJECT_ID/jobs/$JOB_ID/trace" 2>/dev/null | tail -n "$TAIL_LINES" || {
  echo "glab api failed fetching trace for job $JOB_ID" >&2; exit 3; }
