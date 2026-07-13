#!/usr/bin/env bash
# Report the status of the checks on the current branch's PR.
# Prints exactly one of: running | success | failed | none  on the first stdout line.
# When the status is `failed`, a `---` line follows, then the failed job IDs, one
# per line (Actions job ids parsed from each failed check's …/job/<id> link, so
# implement-ticket can pull each trace with job-trace.sh on this backend; failed
# checks from external apps carry no Actions job id and are skipped with a
# stderr warning).
#
# Pass --manual-jobs to switch modes: emit `<environment>\t<run-name>\t<run-url>`
# per pending deployment approval (workflow runs waiting on environment
# protection rules) instead of the regular status line. Nothing on stdout when
# there are none: GitHub has no direct manual-job equivalent, so this is the
# documented degradation.
#
# Live mode:
#   gh pr checks <branch> --json bucket,name,link,state          -> status + failed links
#   gh api repos/{o}/{r}/actions/runs?head_sha=…&status=waiting  -> waiting runs
#   gh api repos/{o}/{r}/actions/runs/<id>/pending_deployments   -> environments per run
#
# Usage:
#   pipeline-status.sh                                 # live, status mode
#   pipeline-status.sh --manual-jobs                   # live, manual-jobs mode
#   pipeline-status.sh --from-fixture <dir>            # test, status mode
#   pipeline-status.sh --manual-jobs --from-fixture <dir>  # test, manual-jobs mode
#
# Fixture files (GitHub-shaped):
#   checks.json                     : the `gh pr checks --json bucket,name,link,state` array
#   waiting-runs.json               : the actions/runs response ({"workflow_runs":[…]})
#   pending-deployments-<run>.json  : the pending_deployments array for run id <run>
#
# Output: see above. Warnings/errors to stderr.
# Exit:
#   0: status determined (including `none` and `failed`), or manual-jobs listed
#   2: bad usage
#   3: gh not on PATH / not in a repo / no PR / the API call failed

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

# Map a `gh pr checks` bucket array to our four-value vocabulary. Precedence:
# any fail -> failed; any pending -> running; any pass -> success; else none
# (no checks, or everything skipped/cancelled).
status_from_checks() {
  printf '%s' "$1" | jq -r '
    ([.[] | select(.bucket == "fail")]    | length) as $f |
    ([.[] | select(.bucket == "pending")] | length) as $p |
    ([.[] | select(.bucket == "pass")]    | length) as $s |
    if $f > 0 then "failed" elif $p > 0 then "running" elif $s > 0 then "success" else "none" end'
}

# Failed check links -> Actions job ids (…/job/<id>). Checks without one
# (external status apps) are untraceable on this backend; warn, don't fail.
failed_job_ids() {
  printf '%s' "$1" | jq -r '
    .[] | select(.bucket == "fail") | (.link // "")
    | select(test("/job/[0-9]+")) | capture("/job/(?<id>[0-9]+)") | .id'
  printf '%s' "$1" | jq -r '
    [.[] | select(.bucket == "fail") | select(((.link // "") | test("/job/[0-9]+")) | not) | .name]
    | if length > 0 then "no Actions job id for failed check(s): " + join(", ") else empty end' >&2
}

emit_manual_rows() { # <runs-json> <pending-deployments-reader-cmd-prefix…>
  local runs="$1"
  shift
  printf '%s' "$runs" | jq -r '.workflow_runs[]? | "\(.id)\t\(.name // "")\t\(.html_url // "")"' \
    | while IFS="$(printf '\t')" read -r run_id run_name run_url; do
        [[ -n "$run_id" ]] || continue
        "$@" "$run_id" | jq -r --arg n "$run_name" --arg u "$run_url" \
          '.[]? | "\(.environment.name // "?")\t\($n)\t\($u)"'
      done
}

read_pending_fixture() { # <run-id>
  local f="$FIXTURE_DIR/pending-deployments-$1.json"
  if [[ -f "$f" ]]; then cat "$f"; else echo '[]'; fi
}

if [[ -n "$FIXTURE_DIR" ]]; then
  [[ -d "$FIXTURE_DIR" ]] || { echo "fixture dir not found: $FIXTURE_DIR" >&2; exit 3; }
  if $MANUAL_JOBS; then
    # No waiting-runs fixture = no pending approvals (empty stdout, exit 0).
    rf="$FIXTURE_DIR/waiting-runs.json"
    if [[ -f "$rf" ]]; then
      emit_manual_rows "$(cat "$rf")" read_pending_fixture
    fi
    exit 0
  fi
  cf="$FIXTURE_DIR/checks.json"
  [[ -f "$cf" ]] || { echo "fixture file not found: $cf" >&2; exit 3; }
  checks="$(cat "$cf")"
  echo "$checks" | jq . >/dev/null 2>&1 || { echo "fixture JSON unparseable: $cf" >&2; exit 3; }
  status="$(status_from_checks "$checks")"
  echo "$status"
  if [[ "$status" == "failed" ]]; then
    echo "---"
    failed_job_ids "$checks"
  fi
  exit 0
fi

if ! command -v gh >/dev/null; then
  echo "gh not on PATH; install the GitHub CLI" >&2
  exit 3
fi
BRANCH="$(specto_source_branch)" || { echo "could not resolve the source branch (detached HEAD?); set SOURCE_BRANCH" >&2; exit 3; }

read_pending_live() { # <run-id>
  gh api "repos/$OWNER_REPO/actions/runs/$1/pending_deployments" 2>/dev/null || echo '[]'
}

if $MANUAL_JOBS; then
  OWNER_REPO="$(specto_gh_repo)" || { echo "could not resolve the GitHub repo" >&2; exit 3; }
  HEAD_SHA="$(gh pr view "$BRANCH" --json headRefOid --jq '.headRefOid' 2>/dev/null)" || HEAD_SHA=""
  [[ -n "$HEAD_SHA" ]] || { echo "no open PR for branch $BRANCH" >&2; exit 3; }
  runs="$(gh api "repos/$OWNER_REPO/actions/runs?head_sha=$HEAD_SHA&status=waiting" 2>/dev/null)" || exit 0
  emit_manual_rows "$runs" read_pending_live
  exit 0
fi

# gh pr checks exits non-zero when checks are failing or pending, and errors
# outright when the PR has no checks: capture output either way and decide
# from the JSON (an empty/non-JSON response maps to `none`).
checks="$(gh pr checks "$BRANCH" --json bucket,name,link,state 2>/dev/null)" || true
if [[ -z "$checks" ]] || ! printf '%s' "$checks" | jq -e 'type == "array"' >/dev/null 2>&1; then
  # Distinguish "no checks" from "no PR": a missing PR is a hard failure.
  gh pr view "$BRANCH" --json number >/dev/null 2>&1 || {
    echo "no open PR for branch $BRANCH" >&2; exit 3; }
  echo "none"
  exit 0
fi
status="$(status_from_checks "$checks")"
echo "$status"
if [[ "$status" == "failed" ]]; then
  echo "---"
  failed_job_ids "$checks"
fi
