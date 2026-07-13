#!/usr/bin/env bash
# Single read path for PR data on GitHub: discussion threads, the change-request
# object, or per-file diffs: normalized to the shapes in docs/adapter-contract.md.
# All Specto reviewer agents / skills go through this instead of inlining `gh`.
#
#   mr-fetch.sh info          -> the change-request object (iid = PR number,
#                                state opened|merged|closed, draft, source/target
#                                branch, diff_refs with base_sha = start_sha =
#                                baseRefOid and head_sha = headRefOid).
#   mr-fetch.sh discussions   -> ONE flat JSON thread array merged from THREE
#                                GitHub sources: review threads (GraphQL
#                                reviewThreads, paginated; resolvable:true,
#                                position from path/line/originalLine), plus
#                                top-level issue comments and non-empty review
#                                summaries (gh pr view --json comments,reviews)
#                                as synthetic single-note threads
#                                (resolvable:false, position:null). The merge is
#                                what gives resolve-mr-comments bot-comment
#                                parity with GitLab.
#   mr-fetch.sh diff          -> JSON array of per-file entries mapped from
#                                GET repos/{o}/{r}/pulls/{n}/files (paginated):
#                                filename -> new_path, previous_filename //
#                                filename -> old_path, patch -> diff (missing
#                                patch: binary/huge: maps to ""), status ->
#                                new_file/deleted_file/renamed_file bools.
#
# By default the PR is resolved off the source branch from _lib.sh's
# specto_source_branch. Pass --iid <N> or --branch <name> to target a PR off
# the current branch. Fixture files are GitHub-shaped (raw API/CLI responses);
# the normalization above runs on them too, so fixture output == live output.
#
# Usage:
#   mr-fetch.sh <discussions|info|diff>                       # live, current branch
#   mr-fetch.sh <discussions|info|diff> --iid <N>             # live, explicit PR number
#   mr-fetch.sh <discussions|info|diff> --branch <name>       # live, look up by source branch
#   mr-fetch.sh <discussions|info|diff> --from-fixture <dir>  # test: reads GitHub-shaped files
#
# Fixture files read from <dir>/:
#   info.json     : the `gh pr view --json number,url,title,state,isDraft,…` object
#   threads.json  : raw GraphQL reviewThreads response(s); multiple pages may be
#                    concatenated (the `gh api graphql --paginate` stream shape)
#   comments.json : the `gh pr view --json comments,reviews` object (optional)
#   files.json    : the `pulls/{n}/files` array; two pages may be concatenated
#
# Output: normalized JSON on stdout. Warnings/errors to stderr.
# Exit:
#   0: fetched
#   2: bad usage (incl. --iid + --branch both supplied)
#   3: gh not on PATH, not in a repo, no PR for the branch/number, or the API call failed

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
# --iid and --branch are mutually exclusive: each names a different PR.
[[ -n "$EXPLICIT_IID" && -n "$BRANCH" ]] && usage

# --- normalizers (GitHub raw -> adapter-contract shapes) ---------------------------

normalize_info() { jq "$SPECTO_GH_INFO_JQ"; }

# Review-thread pages (a concatenated JSON-doc stream) -> normalized thread array.
# Thread id = the GraphQL node id; every note in a thread shares the thread's
# resolved flag and position (GitLab puts position on notes, consumers read
# notes[0].position). `line` is null on outdated threads: fall back to
# originalLine so the anchor survives a force-push.
normalize_threads() {
  jq -s '
    [ .[] | .data.repository.pullRequest.reviewThreads.nodes[]? ]
    | map(
        (.isResolved // false) as $res
        | (.path // null) as $p
        | ((.line // .originalLine) // null) as $nl
        | { id: .id,
            kind: "review_thread",
            notes: [ .comments.nodes[]? | {
              id: .id,
              body: (.body // ""),
              author: { username: (.author.login // "") },
              system: false,
              resolvable: true,
              resolved: $res,
              created_at: (.createdAt // null),
              position: { new_path: $p, old_path: $p, new_line: $nl, old_line: null }
            } ] }
      )'
}

# `gh pr view --json comments,reviews` -> synthetic single-note threads. Issue
# comments and non-empty review summaries become non-resolvable, non-anchored
# threads so resolve-mr-comments sees bot comments exactly as it does on GitLab.
# Empty review bodies (bare approvals / change requests) carry no prose to act
# on and are dropped.
normalize_comments() {
  jq '
    ([ .comments[]? | {
         id: .id,
         kind: "issue_comment",
         notes: [ { id: .id, body: (.body // ""),
                    author: { username: (.author.login // "") },
                    system: false, resolvable: false, resolved: false,
                    created_at: (.createdAt // null), position: null } ] } ])
    + ([ .reviews[]? | select((.body // "") != "") | {
         id: .id,
         kind: "review",
         notes: [ { id: .id, body: .body,
                    author: { username: (.author.login // "") },
                    system: false, resolvable: false, resolved: false,
                    created_at: (.submittedAt // null), position: null } ] } ])'
}

# `pulls/{n}/files` pages -> normalized per-file diff array. Entries without a
# `patch` (binary or oversized files) map to diff:"" so the anchor math falls
# back to GENERAL instead of parsing garbage.
normalize_files() {
  jq -s '
    (map(if type == "array" then . else [.] end) | add // [])
    | map({
        new_path: .filename,
        old_path: (.previous_filename // .filename),
        new_file: (.status == "added"),
        deleted_file: (.status == "removed"),
        renamed_file: (.status == "renamed"),
        diff: (.patch // "")
      })'
}

# --- fixture mode -------------------------------------------------------------------
if [[ -n "$FIXTURE_DIR" ]]; then
  [[ -d "$FIXTURE_DIR" ]] || { echo "fixture dir not found: $FIXTURE_DIR" >&2; exit 3; }
  case "$WHAT" in
    info)
      f="$FIXTURE_DIR/info.json"
      [[ -f "$f" ]] || { echo "fixture file not found: $f" >&2; exit 3; }
      normalize_info < "$f"
      ;;
    diff)
      f="$FIXTURE_DIR/files.json"
      [[ -f "$f" ]] || { echo "fixture file not found: $f" >&2; exit 3; }
      normalize_files < "$f"
      ;;
    discussions)
      tf="$FIXTURE_DIR/threads.json"
      cf="$FIXTURE_DIR/comments.json"
      [[ -f "$tf" || -f "$cf" ]] || { echo "fixture file not found: $tf" >&2; exit 3; }
      if [[ -f "$tf" ]]; then threads="$(normalize_threads < "$tf")"; else threads="[]"; fi
      if [[ -f "$cf" ]]; then synth="$(normalize_comments < "$cf")"; else synth="[]"; fi
      jq -n --argjson a "$threads" --argjson b "$synth" '$a + $b'
      ;;
  esac
  exit 0
fi

# --- live mode ----------------------------------------------------------------------
if ! command -v gh >/dev/null; then
  echo "gh not on PATH; install the GitHub CLI" >&2
  exit 3
fi

# gh pr view accepts a number, a branch, or (no arg) the current branch: but
# the current-branch inference breaks under jj-colocated detached HEAD, so the
# branch is always passed explicitly.
if [[ -n "$EXPLICIT_IID" ]]; then
  TARGET="$EXPLICIT_IID"
else
  [[ -n "$BRANCH" ]] || BRANCH="$(specto_source_branch)" || {
    echo "could not resolve the source branch (detached HEAD?); pass --branch or set SOURCE_BRANCH" >&2
    exit 3
  }
  TARGET="$BRANCH"
fi

if [[ "$WHAT" == "info" ]]; then
  raw="$(gh pr view "$TARGET" --json number,url,title,state,isDraft,headRefName,baseRefName,headRefOid,baseRefOid,body 2>/dev/null)" || {
    echo "gh pr view failed for '$TARGET' (no PR? auth?)" >&2; exit 3; }
  printf '%s' "$raw" | normalize_info
  exit 0
fi

# diff + discussions need the repo path and the PR number for the REST/GraphQL calls.
OWNER_REPO="$(specto_gh_repo)" || { echo "could not resolve the GitHub repo (not a repo? not authed?)" >&2; exit 3; }
NUM="$(specto_gh_pr_number "$EXPLICIT_IID" "$BRANCH")" || {
  echo "no PR found for '$TARGET'" >&2; exit 3; }

if [[ "$WHAT" == "diff" ]]; then
  # --paginate emits one JSON array per page; normalize_files slurps and flattens.
  gh api "repos/$OWNER_REPO/pulls/$NUM/files" --paginate 2>/dev/null | normalize_files || {
    echo "gh api failed fetching files for PR #$NUM" >&2; exit 3; }
  exit 0
fi

# discussions: review threads via GraphQL (paginated on the reviewThreads
# connection), then the synthetic issue-comment/review threads merged in.
THREADS_QUERY='query($owner: String!, $name: String!, $number: Int!, $endCursor: String) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      reviewThreads(first: 100, after: $endCursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id isResolved path line originalLine
          comments(first: 100) {
            nodes { id body createdAt author { login } }
          }
        }
      }
    }
  }
}'
threads_raw="$(gh api graphql --paginate \
  -f query="$THREADS_QUERY" \
  -f owner="${OWNER_REPO%%/*}" -f name="${OWNER_REPO##*/}" -F number="$NUM" 2>/dev/null)" || {
    echo "gh api graphql failed fetching review threads for PR #$NUM" >&2; exit 3; }
comments_raw="$(gh pr view "$TARGET" --json comments,reviews 2>/dev/null)" || {
  echo "gh pr view failed fetching comments for PR #$NUM" >&2; exit 3; }
threads="$(printf '%s' "$threads_raw" | normalize_threads)"
synth="$(printf '%s' "$comments_raw" | normalize_comments)"
jq -n --argjson a "${threads:-[]}" --argjson b "${synth:-[]}" '$a + $b'
