#!/usr/bin/env bash
# Single read path for MR data: discussion threads, the MR object, or per-file diffs.
# All Specto reviewer agents / skills go through this instead of inlining `glab api`.
#
#   mr-fetch.sh discussions   -> JSON array of all MR discussion threads (paginated,
#                                flattened to ONE array — `glab api --paginate`
#                                emits one JSON array per page, this concatenates them).
#   mr-fetch.sh info          -> the MR object JSON (has base_sha / head_sha / start_sha
#                                under .diff_refs, plus iid, web_url, draft, …).
#   mr-fetch.sh diff          -> JSON array of per-file diff entries (.old_path/.new_path/.diff),
#                                paginated & flattened.
#
# By default the MR iid is resolved off the source branch from _lib.sh's
# specto_source_branch (current git branch, or the jj bookmark on @ when HEAD is
# detached under jj-colocated git), then `glab mr list --source-branch <name>`.
# Pass --iid <N> or --branch <name> to target an MR off the current branch
# (used by `resolve-mr-comments` when the user names an MR explicitly). The
# project id is always read from the current repo via `glab repo view`.
#
# Usage:
#   mr-fetch.sh <discussions|info|diff>                       # live, current branch
#   mr-fetch.sh <discussions|info|diff> --iid <N>             # live, explicit MR iid
#   mr-fetch.sh <discussions|info|diff> --branch <name>       # live, look up by source branch
#   mr-fetch.sh <discussions|info|diff> --from-fixture <dir>  # test: reads <dir>/discussions.json, <dir>/info.json, or <dir>/diff.json
#
# Output: JSON on stdout. Warnings/errors to stderr.
# Exit:
#   0 — fetched
#   2 — bad usage (incl. --iid + --branch both supplied)
#   3 — glab not on PATH, not in a repo, no MR for the branch/iid, or the API call failed

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
. "$SCRIPT_DIR/_lib.sh"

usage() {
  echo "usage: mr-fetch.sh <discussions|info|diff> [--iid <N> | --branch <name>] [--from-fixture <dir>]" >&2
  exit 2
}

[[ $# -lt 1 ]] && usage
WHAT="$1"
shift
case "$WHAT" in discussions|info|diff) : ;; *) usage ;; esac

FIXTURE_DIR=""
EXPLICIT_IID=""
BRANCH=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from-fixture)  [[ $# -ge 2 ]] || usage; FIXTURE_DIR="$2"; shift 2 ;;
    --iid)           [[ $# -ge 2 ]] || usage; EXPLICIT_IID="$2"; shift 2 ;;
    --branch)        [[ $# -ge 2 ]] || usage; BRANCH="$2"; shift 2 ;;
    *)               usage ;;
  esac
done
# --iid and --branch are mutually exclusive: each names a different MR.
[[ -n "$EXPLICIT_IID" && -n "$BRANCH" ]] && usage

if [[ -n "$FIXTURE_DIR" ]]; then
  [[ -d "$FIXTURE_DIR" ]] || { echo "fixture dir not found: $FIXTURE_DIR" >&2; exit 3; }
  f="$FIXTURE_DIR/$WHAT.json"
  [[ -f "$f" ]] || { echo "fixture file not found: $f" >&2; exit 3; }
  cat "$f"
  exit 0
fi

if ! command -v glab >/dev/null; then
  echo "glab not on PATH; install the GitLab CLI" >&2
  exit 3
fi

PROJECT_ID="$(glab repo view --output json 2>/dev/null | jq -r '.id // empty')" || true
[[ -n "$PROJECT_ID" ]] || { echo "could not resolve the GitLab project (not a repo? not authed?)" >&2; exit 3; }
if [[ -n "$EXPLICIT_IID" ]]; then
  MR_IID="$EXPLICIT_IID"
else
  # No explicit iid: resolve the source branch ourselves rather than letting glab
  # infer it. Under jj colocated with git, HEAD is detached after `jj git push`, so
  # `glab mr view` would see "HEAD" and fail; specto_source_branch handles that.
  # When --branch was given it already set BRANCH; otherwise auto-resolve it.
  [[ -n "$BRANCH" ]] || BRANCH="$(specto_source_branch)" || {
    echo "could not resolve the source branch (detached HEAD?); pass --branch or set SOURCE_BRANCH" >&2
    exit 3
  }
  # `glab mr list --source-branch <name> --output json` returns an array; take the
  # first matching MR's iid. If nothing matches, exit 3 with a clear message rather
  # than silently fetching the wrong MR.
  MR_IID="$(glab mr list --source-branch "$BRANCH" --output json 2>/dev/null \
              | jq -r '.[0].iid // empty')" || true
  [[ -n "$MR_IID" ]] || { echo "no MR found for source branch '$BRANCH'" >&2; exit 3; }
fi

if [[ "$WHAT" == "info" ]]; then
  glab api "projects/$PROJECT_ID/merge_requests/$MR_IID" 2>/dev/null || {
    echo "glab api failed fetching MR !$MR_IID" >&2; exit 3; }
  exit 0
fi

if [[ "$WHAT" == "diff" ]]; then
  # Use /changes?access_raw_diffs=true, NOT /diffs. The /diffs endpoint collapses
  # large per-file diffs — it returns `collapsed:true` with an empty `.diff` for
  # files over a size threshold (and `access_raw_diffs` has no effect there), which
  # would silently strip the hunks post-mr-comment.sh needs to anchor a line.
  # /changes with access_raw_diffs reads the raw git diff, so nothing collapses.
  # Each `.changes[]` entry shares the .old_path/.new_path/.diff shape /diffs used.
  # (--paginate emits one object per page; pull every page's .changes and flatten.)
  glab api "projects/$PROJECT_ID/merge_requests/$MR_IID/changes?access_raw_diffs=true" --paginate 2>/dev/null \
    | jq -s 'map(.changes // []) | add // []' || {
      echo "glab api failed fetching diffs for MR !$MR_IID" >&2; exit 3; }
  exit 0
fi

# discussions: --paginate emits one JSON array per page; slurp them and concatenate
# into a single flat array so downstream `jq '.[]'` works regardless of page count.
glab api "projects/$PROJECT_ID/merge_requests/$MR_IID/discussions" --paginate 2>/dev/null \
  | jq -s 'add // []' || {
    echo "glab api failed fetching discussions for MR !$MR_IID" >&2; exit 3; }
