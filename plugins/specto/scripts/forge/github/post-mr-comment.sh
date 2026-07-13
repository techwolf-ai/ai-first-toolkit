#!/usr/bin/env bash
# Post a line-anchored review comment on the current branch's PR: idempotently.
# This is the single vetted `gh` posting path; the Specto reviewer agents shell
# out to it instead of each carrying a copy of the posting block.
#
# Idempotency: identical to the gitlab impl: a stable 8-hex marker
#   sha8 = sha1(<agent-name> ∥ <spec-path> ∥ normalize(<section>) ∥ normalize(<finding-type>))[:8]
# (∥ = NUL separator; normalize lowercases and collapses non-alphanumeric runs
# to a single '-') embedded in the body as `[specto:<agent-name>#<sha8>] `.
# Before posting, existing threads (via mr-fetch.sh discussions: review
# threads AND synthetic issue-comment/review threads) are scanned for the
# marker. Found -> the note is edited in place: GraphQL
# updatePullRequestReviewComment for a review-thread note, updateIssueComment
# for an issue comment, updatePullRequestReview for a review summary. Not
# found -> a new comment is created.
#
# Position: the GitHub difference: review comments can only anchor to lines a
# diff hunk actually shows. The shared anchor walk (forge/_anchor.sh) runs in
# hunks-only mode: a target line inside a hunk (added or context) anchors via
# POST repos/{o}/{r}/pulls/{n}/comments with {body, commit_id: <head_sha>,
# path, line, side:"RIGHT"}; a line in the gaps between hunks: anchorable on
# GitLab: falls back to a GENERAL comment here (gh pr comment), still
# carrying the marker so it stays idempotent.
#
# Usage:
#   post-mr-comment.sh <agent-name> <spec-path> <line> <section> <finding-type> <body-file|->
#   post-mr-comment.sh <agent-name> <spec-path> <line> <section> <finding-type> <body-file|-> --from-fixture <dir>
#
# <body-file> may be "-" to read from stdin.
# --from-fixture <dir>: reads the GitHub-shaped fixture files via mr-fetch.sh
#   (info.json, threads.json/comments.json, files.json). No network; prints one
#   machine-parseable decision line (byte-identical grammar with gitlab):
#       EDIT sha8=<8hex> discussion=<id> note=<id>
#       CREATE sha8=<8hex> ANCHOR new_line=<n> [old_line=<o>]
#       CREATE sha8=<8hex> GENERAL
#
# Output (live): nothing on stdout; warnings to stderr.
# Output (fixture): the CREATE/EDIT decision line on stdout.
# Exit:
#   0: posted / updated (or decision printed in fixture mode)
#   1: body empty / SHAs missing from the PR object
#   2: bad usage
#   3: gh not on PATH / not in a repo / no PR / API call failed

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=_lib.sh
. "$HERE/_lib.sh"
# shellcheck source=../_anchor.sh
. "$HERE/../_anchor.sh"

usage() {
  echo "usage: post-mr-comment.sh <agent-name> <spec-path> <line> <section> <finding-type> <body-file|-> [--from-fixture <dir>]" >&2
  exit 2
}

[[ $# -lt 6 ]] && usage
AGENT="$1"
SPEC_PATH="$2"
LINE="$3"
SECTION="$4"
FINDING_TYPE="$5"
BODY_SRC="$6"
shift 6

FIXTURE_DIR=""
if [[ $# -gt 0 ]]; then
  if [[ "$1" == "--from-fixture" && $# -ge 2 ]]; then
    FIXTURE_DIR="$2"
    shift 2
  else
    usage
  fi
fi

# Read the body.
if [[ "$BODY_SRC" == "-" ]]; then
  BODY="$(cat)"
else
  [[ -f "$BODY_SRC" ]] || { echo "body file not found: $BODY_SRC" >&2; exit 2; }
  BODY="$(cat "$BODY_SRC")"
fi
if [[ -z "${BODY//[[:space:]]/}" ]]; then
  echo "comment body is empty" >&2
  exit 1
fi

# Stable key: lowercase + collapse runs of non-alphanumerics to a single '-',
# so "§1.4" / "1.4" / " 1.4 " fold together and type casing/spacing stops mattering.
# Byte-identical with the gitlab impl: the marker is the cross-backend contract.
normalize() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'; }
SECTION_N="$(normalize "$SECTION")"
TYPE_N="$(normalize "$FINDING_TYPE")"
SHA8="$(printf '%s\0%s\0%s\0%s' "$AGENT" "$SPEC_PATH" "$SECTION_N" "$TYPE_N" | sha1sum | cut -c1-8)"
MARKER="[specto:${AGENT}#${SHA8}]"
FULL_BODY="${MARKER} ${BODY}"

# How to get discussions + the PR object: from the fixture dir, or via mr-fetch.sh.
fetch_discussions() {
  if [[ -n "$FIXTURE_DIR" ]]; then "$HERE/mr-fetch.sh" discussions --from-fixture "$FIXTURE_DIR"
  else "$HERE/mr-fetch.sh" discussions; fi
}
fetch_info() {
  if [[ -n "$FIXTURE_DIR" ]]; then "$HERE/mr-fetch.sh" info --from-fixture "$FIXTURE_DIR"
  else "$HERE/mr-fetch.sh" info; fi
}
fetch_diff() {
  if [[ -n "$FIXTURE_DIR" ]]; then "$HERE/mr-fetch.sh" diff --from-fixture "$FIXTURE_DIR"
  else "$HERE/mr-fetch.sh" diff; fi
}

# Search every note of every thread for our marker; emit
# "<kind> <discussion_id> <note_id>" if found (first hit), nothing otherwise.
# The kind (review_thread / issue_comment / review) picks the edit mutation.
find_existing() {
  local discussions
  discussions="$(fetch_discussions)" || { echo "could not fetch discussions" >&2; return 3; }
  printf '%s' "$discussions" \
    | jq -r --arg m "$MARKER" '
        .[]? | .id as $did | (.kind // "review_thread") as $k
        | (.notes[]? | select((.body // "") | contains($m)) | "\($k) \($did) \(.id)")' \
    | head -1
}

# --- decide CREATE vs EDIT --------------------------------------------------------
EXISTING="$(find_existing)" || { rc=$?; [[ $rc -eq 3 ]] && exit 3 || true; }
KIND=""
DISCUSSION_ID=""
NOTE_ID=""
if [[ -n "${EXISTING:-}" ]]; then
  read -r KIND DISCUSSION_ID NOTE_ID <<EOF
$EXISTING
EOF
fi

# Anchor decision (only needed for a CREATE; an EDIT just rewrites the note body).
# hunks-only: GitHub review comments cannot anchor to lines outside diff hunks,
# so those degrade to GENERAL instead of a computed between-hunk position.
ANCHOR_KIND=""; ANCHOR_NEW=""; ANCHOR_OLD=""; ANCHOR_NP=""; ANCHOR_OP=""
if [[ -z "$DISCUSSION_ID" ]]; then
  DIFFS="$(fetch_diff)" || { echo "could not fetch PR diff" >&2; exit 3; }
  read -r ANCHOR_KIND ANCHOR_NEW ANCHOR_OLD ANCHOR_NP ANCHOR_OP < <(specto_compute_anchor "$DIFFS" "$SPEC_PATH" "$LINE" hunks-only)
fi

# --- head SHA (needed for an anchored CREATE) --------------------------------------
INFO="$(fetch_info)" || { echo "could not fetch PR info" >&2; exit 3; }
HEAD_SHA="$(printf '%s' "$INFO" | jq -r '.diff_refs.head_sha // empty')"

# --- fixture mode: print the decision, don't touch the network ----------------------
if [[ -n "$FIXTURE_DIR" ]]; then
  if [[ -n "$DISCUSSION_ID" ]]; then
    echo "EDIT sha8=$SHA8 discussion=$DISCUSSION_ID note=$NOTE_ID"
  elif [[ "$ANCHOR_KIND" == "ADDED" ]]; then
    echo "CREATE sha8=$SHA8 ANCHOR new_line=$ANCHOR_NEW"
  elif [[ "$ANCHOR_KIND" == "UNCHANGED" ]]; then
    echo "CREATE sha8=$SHA8 ANCHOR new_line=$ANCHOR_NEW old_line=$ANCHOR_OLD"
  else
    echo "CREATE sha8=$SHA8 GENERAL"
  fi
  exit 0
fi

# --- live mode ----------------------------------------------------------------------
if ! command -v gh >/dev/null; then
  echo "gh not on PATH; install the GitHub CLI" >&2
  exit 3
fi
OWNER_REPO="$(specto_gh_repo)" || { echo "could not resolve the GitHub repo" >&2; exit 3; }
NUM="$(specto_gh_pr_number "" "")" || {
  echo "no open PR for the current branch; set SOURCE_BRANCH" >&2; exit 3; }

if [[ -n "$DISCUSSION_ID" ]]; then
  # Edit the existing note in place: mutation picked by the note's kind.
  case "$KIND" in
    issue_comment)
      MUTATION='mutation($id: ID!, $body: String!) {
        updateIssueComment(input: {id: $id, body: $body}) { issueComment { id } } }'
      ;;
    review)
      MUTATION='mutation($id: ID!, $body: String!) {
        updatePullRequestReview(input: {pullRequestReviewId: $id, body: $body}) { pullRequestReview { id } } }'
      ;;
    *)
      MUTATION='mutation($id: ID!, $body: String!) {
        updatePullRequestReviewComment(input: {pullRequestReviewCommentId: $id, body: $body}) { pullRequestReviewComment { id } } }'
      ;;
  esac
  if ! err="$(gh api graphql -f query="$MUTATION" -f id="$NOTE_ID" -f body="$FULL_BODY" 2>&1 >/dev/null)"; then
    echo "gh api graphql failed editing note $NOTE_ID on PR #$NUM: $err" >&2; exit 3
  fi
  exit 0
fi

# Create a new comment. Anchor it when the line sits inside a diff hunk;
# otherwise fall back to a general PR comment (still carrying the marker, so
# it's idempotent).
if [[ "$ANCHOR_KIND" == "ADDED" || "$ANCHOR_KIND" == "UNCHANGED" ]]; then
  [[ -n "$HEAD_SHA" ]] || {
    echo "PR #$NUM has no head SHA: cannot anchor a line comment" >&2; exit 1; }
  payload="$(mktemp)"
  jq -n --arg body "$FULL_BODY" --arg cid "$HEAD_SHA" --arg path "$ANCHOR_NP" --argjson line "$ANCHOR_NEW" \
    '{body: $body, commit_id: $cid, path: $path, line: $line, side: "RIGHT"}' > "$payload"
  resp="$(gh api --method POST "repos/$OWNER_REPO/pulls/$NUM/comments" --input "$payload" 2>&1)"; rc=$?
  rm -f "$payload"
  if [[ $rc -ne 0 ]]; then
    echo "gh api failed creating a review comment on PR #$NUM: $resp" >&2; exit 3
  fi
  # Verify the anchor actually took (GitHub 422s on bad lines, but stay loud on
  # any response that came back without a line).
  if [[ "$(printf '%s' "$resp" | jq -r '.line // "null"' 2>/dev/null)" == "null" ]]; then
    echo "anchor for §${SECTION} was DROPPED by GitHub: comment posted without a line on PR #$NUM" >&2
    exit 3
  fi
  exit 0
fi

echo "§${SECTION} not anchorable (line outside the PR diff hunks); posted as GENERAL comment" >&2
if ! printf '%s' "$FULL_BODY" | gh pr comment "$NUM" --body-file - >/dev/null 2>&1; then
  echo "gh pr comment failed on PR #$NUM" >&2; exit 3
fi
