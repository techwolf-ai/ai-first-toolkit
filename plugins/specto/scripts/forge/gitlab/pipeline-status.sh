#!/usr/bin/env bash
# Report the status of the latest pipeline for the current branch's MR.
# Prints exactly one of: running | success | failed | none  on the first stdout line.
# When the status is `failed`, a `---` line follows, then the failed job IDs, one
# per line (so implement-ticket can pull each trace with job-trace.sh).
#
# Pass --manual-jobs to switch modes: emit `<stage>\t<name>\t<web_url>` per job
# with status="manual" instead of the regular status line. Used by create-mr to
# surface staging-deploy / teardown / etc. gates the user still needs to click
# manually. Nothing on stdout if there are no manual jobs.
#
# Live mode uses the GitLab API:
#   GET projects/<id>/merge_requests/<iid>/pipelines   -> newest pipeline
#   GET projects/<id>/pipelines/<pid>/jobs             -> failed / manual job rows
# (pipelines come back newest-first; we take .[0].)
#
# Usage:
#   pipeline-status.sh                                 # live, status mode
#   pipeline-status.sh --manual-jobs                   # live, manual-jobs mode
#   pipeline-status.sh --from-fixture <dir>            # test, status mode
#   pipeline-status.sh --manual-jobs --from-fixture <dir>  # test, manual-jobs mode
#
# Fixture files:
#   pipelines.json : array of pipeline objects, newest first, each with .id and .status
#   jobs.json      : array of job objects for that pipeline, each with .id, .status,
#                    .stage, .name, .web_url
#
# Output: see above. Warnings/errors to stderr.
# Exit:
#   0 — status determined (including `none` and `failed`), or manual-jobs listed
#   2 — bad usage
#   3 — glab not on PATH / not in a repo / no MR / the API call failed

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
. "$SCRIPT_DIR/_lib.sh"

usage() {
  echo "usage: pipeline-status.sh [--manual-jobs] [--from-fixture <dir>]" >&2
  exit 2
}

FIXTURE_DIR=""
MANUAL_JOBS=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --manual-jobs)   MANUAL_JOBS=true; shift ;;
    --from-fixture)  [[ $# -ge 2 ]] || usage; FIXTURE_DIR="$2"; shift 2 ;;
    *)               usage ;;
  esac
done

# Map a GitLab pipeline status string to our four-value vocabulary.
normalise() {
  case "$1" in
    success)                                  echo "success" ;;
    failed)                                   echo "failed" ;;
    running|pending|created|preparing|waiting_for_resource|scheduled)
                                              echo "running" ;;
    canceled|cancelled|skipped|manual|"")     echo "none" ;;
    *)                                        echo "running" ;;  # unknown -> treat as in-flight
  esac
}

if [[ -n "$FIXTURE_DIR" ]]; then
  [[ -d "$FIXTURE_DIR" ]] || { echo "fixture dir not found: $FIXTURE_DIR" >&2; exit 3; }
  pf="$FIXTURE_DIR/pipelines.json"
  [[ -f "$pf" ]] || { echo "fixture file not found: $pf" >&2; exit 3; }
  pipelines="$(cat "$pf")"
  echo "$pipelines" | jq . >/dev/null 2>&1 || { echo "fixture JSON unparseable: $pf" >&2; exit 3; }
  if $MANUAL_JOBS; then
    # Manual-jobs mode: list jobs with status="manual" from the newest pipeline's
    # jobs fixture. No pipeline = no manual jobs (empty stdout, exit 0).
    jf="$FIXTURE_DIR/jobs.json"
    if [[ -f "$jf" ]]; then
      cat "$jf" | jq -r '.[] | select(.status == "manual") | "\(.stage)\t\(.name)\t\(.web_url // "")"'
    fi
    exit 0
  fi
  raw_status="$(echo "$pipelines" | jq -r 'if length == 0 then "" else .[0].status end')"
  status="$(normalise "$raw_status")"
  echo "$status"
  if [[ "$status" == "failed" ]]; then
    jf="$FIXTURE_DIR/jobs.json"
    echo "---"
    if [[ -f "$jf" ]]; then
      cat "$jf" | jq -r '.[] | select(.status == "failed") | .id'
    fi
  fi
  exit 0
fi

if ! command -v glab >/dev/null; then
  echo "glab not on PATH; install the GitLab CLI" >&2
  exit 3
fi
PROJECT_ID="$(glab repo view --output json 2>/dev/null | jq -r '.id // empty')" || true
[[ -n "$PROJECT_ID" ]] || { echo "could not resolve the GitLab project" >&2; exit 3; }
BRANCH="$(specto_source_branch)" || { echo "could not resolve the source branch (detached HEAD?); set SOURCE_BRANCH" >&2; exit 3; }
MR_IID="$(glab mr view "$BRANCH" --output json 2>/dev/null | jq -r '.iid // empty')" || true
[[ -n "$MR_IID" ]] || { echo "no open MR for branch $BRANCH" >&2; exit 3; }

pipelines="$(glab api "projects/$PROJECT_ID/merge_requests/$MR_IID/pipelines" 2>/dev/null)" || {
  echo "glab api failed fetching pipelines for MR !$MR_IID" >&2; exit 3; }
raw_status="$(echo "$pipelines" | jq -r 'if length == 0 then "" else .[0].status end')"
pipeline_id="$(echo "$pipelines" | jq -r 'if length == 0 then "" else (.[0].id // "") end')"

# Manual-jobs mode: list staging-deploy / teardown / etc. gates without
# triggering them. No pipeline = no manual jobs (empty stdout, exit 0).
if $MANUAL_JOBS; then
  [[ -n "$pipeline_id" ]] || exit 0
  glab api "projects/$PROJECT_ID/pipelines/$pipeline_id/jobs" 2>/dev/null \
    | jq -r '.[] | select(.status == "manual") | "\(.stage)\t\(.name)\t\(.web_url // "")"' || true
  exit 0
fi

status="$(normalise "$raw_status")"
echo "$status"
if [[ "$status" == "failed" && -n "$pipeline_id" ]]; then
  echo "---"
  glab api "projects/$PROJECT_ID/pipelines/$pipeline_id/jobs" 2>/dev/null \
    | jq -r '.[] | select(.status == "failed") | .id' || true
fi
