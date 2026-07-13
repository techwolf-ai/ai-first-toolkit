#!/usr/bin/env bash
# Reply to a discussion thread on the current branch's PR.
#
# Thread ids come from mr-fetch.sh discussions, which merges two worlds:
#   * review threads (GraphQL reviewThread node ids, resolvable): a reply is
#     addPullRequestReviewThreadReply, a resolve is resolveReviewThread.
#   * synthetic issue-comment / review-summary threads (resolvable:false) -
#     GitHub has no threaded reply on those, so a reply is a quote-reply
#     top-level comment (gh pr comment). They cannot be resolved; the caller
#     is expected to pass --no-resolve (existing convention for bot threads).
#
# Resolution rules: three modes, same as gitlab:
#   * reply + resolve (default): post the body, then resolve the thread.
#   * --no-resolve: reply only. For deferrals, genuine questions, and
#     non-resolvable threads (bot comments, review summaries).
#   * --resolve-only: resolve WITHOUT posting a reply. Takes no body;
#     combining it with a body or with --no-resolve is a usage error.
#
# The positional form `<discussion-id> <body-file>` is preserved for backward
# compatibility; new callers should prefer the explicit `--discussion <id>` form.
# --iid <N> targets a PR directly (no branch guessing); --branch <name> looks
# the PR up by source branch. --iid and --branch are mutually exclusive.
#
# Usage:
#   mr-reply.sh <discussion-id> <body-file|->                            # legacy form: reply + resolve
#   mr-reply.sh --discussion <id> <body-file|-> [--no-resolve]           # explicit form
#   mr-reply.sh --discussion <id> --resolve-only                         # resolve silently, no reply
#   mr-reply.sh --discussion <id> <body-file|-> --iid <N>                # target PR by number
#   mr-reply.sh --discussion <id> <body-file|-> --branch <name>          # target PR by source branch
#   mr-reply.sh <target...> <body-file|-> --from-fixture <dir>           # test mode
#
# <body-file> may be "-" to read from stdin.
# --from-fixture <dir>: does NOT touch the network. Prints the decision line
# (byte-identical grammar with gitlab):
#       REPLY_RESOLVE discussion=<id>    (default mode)
#       REPLY discussion=<id>            (--no-resolve)
#       RESOLVE discussion=<id>          (--resolve-only)
#
# Output (live): nothing on stdout; warnings to stderr.
# Output (fixture): the decision line on stdout.
# Exit:
#   0: replied/resolved as requested, or decision printed in fixture mode
#   1: body empty
#   2: bad usage (incl. --iid + --branch both supplied, --resolve-only with a
#       body or with --no-resolve)
#   3: gh not on PATH / not in a repo / no PR / thread not found / API call
#       failed (incl. resolving a non-resolvable thread: use --no-resolve)

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
. "$SCRIPT_DIR/_lib.sh"

usage() {
  echo "usage: mr-reply.sh <discussion-id> <body-file|-> [--no-resolve] [--iid <N> | --branch <name>] [--from-fixture <dir>]" >&2
  echo "       mr-reply.sh --discussion <id> <body-file|-> [--no-resolve] [--iid <N> | --branch <name>] [--from-fixture <dir>]" >&2
  echo "       mr-reply.sh --discussion <id> --resolve-only [--iid <N> | --branch <name>] [--from-fixture <dir>]" >&2
  exit 2
}

# Two surfaces: positional `<discussion-id> <body-file>` (legacy) or flag-driven
# `--discussion <id> <body-file>` (new): mirrored from the gitlab impl.
DISCUSSION_ID=""
BODY_SRC=""
NO_RESOLVE=false
RESOLVE_ONLY=false
FIXTURE_DIR=""
EXPLICIT_IID=""
BRANCH=""

if [[ "${1:-}" == "--discussion" ]]; then
  # Explicit flag form.
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --discussion)    [[ $# -ge 2 ]] || usage; DISCUSSION_ID="$2"; shift 2 ;;
      --no-resolve)    NO_RESOLVE=true; shift ;;
      --resolve-only)  RESOLVE_ONLY=true; shift ;;
      --iid)           [[ $# -ge 2 ]] || usage; EXPLICIT_IID="$2"; shift 2 ;;
      --branch)        [[ $# -ge 2 ]] || usage; BRANCH="$2"; shift 2 ;;
      --from-fixture)  [[ $# -ge 2 ]] || usage; FIXTURE_DIR="$2"; shift 2 ;;
      *)
        [[ -z "$BODY_SRC" ]] || usage
        BODY_SRC="$1"; shift
        ;;
    esac
  done
else
  # Legacy positional form.
  [[ $# -lt 2 ]] && usage
  DISCUSSION_ID="$1"
  BODY_SRC="$2"
  shift 2
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-resolve)    NO_RESOLVE=true; shift ;;
      --iid)           [[ $# -ge 2 ]] || usage; EXPLICIT_IID="$2"; shift 2 ;;
      --branch)        [[ $# -ge 2 ]] || usage; BRANCH="$2"; shift 2 ;;
      --from-fixture)  [[ $# -ge 2 ]] || usage; FIXTURE_DIR="$2"; shift 2 ;;
      *)               usage ;;
    esac
  done
fi

[[ -n "$DISCUSSION_ID" ]] || usage
if $RESOLVE_ONLY; then
  # No body to post, and the two resolve flags contradict each other.
  [[ -n "$BODY_SRC" ]] && usage
  $NO_RESOLVE && usage
else
  [[ -n "$BODY_SRC" ]] || usage
fi
# --iid and --branch are mutually exclusive: each names a different PR.
[[ -n "$EXPLICIT_IID" && -n "$BRANCH" ]] && usage

# Read body (skipped under --resolve-only: there is nothing to post).
if ! $RESOLVE_ONLY; then
  if [[ "$BODY_SRC" == "-" ]]; then
    BODY="$(cat)"
  else
    [[ -f "$BODY_SRC" ]] || { echo "body file not found: $BODY_SRC" >&2; exit 2; }
    BODY="$(cat "$BODY_SRC")"
  fi
  if [[ -z "${BODY//[[:space:]]/}" ]]; then
    echo "reply body is empty" >&2
    exit 1
  fi
fi

# Fixture mode: print the decision, don't touch the network.
if [[ -n "$FIXTURE_DIR" ]]; then
  [[ -d "$FIXTURE_DIR" ]] || { echo "fixture dir not found: $FIXTURE_DIR" >&2; exit 3; }
  if $RESOLVE_ONLY; then
    echo "RESOLVE discussion=$DISCUSSION_ID"
  elif $NO_RESOLVE; then
    echo "REPLY discussion=$DISCUSSION_ID"
  else
    echo "REPLY_RESOLVE discussion=$DISCUSSION_ID"
  fi
  exit 0
fi

# Live mode.
if ! command -v gh >/dev/null; then
  echo "gh not on PATH; install the GitHub CLI" >&2
  exit 3
fi

NUM="$(specto_gh_pr_number "$EXPLICIT_IID" "$BRANCH")" || {
  echo "could not resolve the target PR; pass --iid/--branch or set SOURCE_BRANCH" >&2
  exit 3
}

resolve_thread() {
  gh api graphql \
    -f query='mutation($id: ID!) { resolveReviewThread(input: {threadId: $id}) { thread { id } } }' \
    -f id="$DISCUSSION_ID" >/dev/null 2>&1
}

# --resolve-only needs no thread lookup: the resolve mutation is the whole job.
if $RESOLVE_ONLY; then
  resolve_thread || {
    echo "could not resolve discussion $DISCUSSION_ID on PR #$NUM" \
         "(non-resolvable thread? use --no-resolve)" >&2
    exit 3
  }
  exit 0
fi

# A reply needs the thread's kind: review threads take a threaded reply,
# synthetic issue-comment/review threads take a quote-reply PR comment.
if [[ -n "$EXPLICIT_IID" ]]; then
  DISCUSSIONS="$("$SCRIPT_DIR/mr-fetch.sh" discussions --iid "$EXPLICIT_IID")" || exit 3
elif [[ -n "$BRANCH" ]]; then
  DISCUSSIONS="$("$SCRIPT_DIR/mr-fetch.sh" discussions --branch "$BRANCH")" || exit 3
else
  DISCUSSIONS="$("$SCRIPT_DIR/mr-fetch.sh" discussions)" || exit 3
fi
THREAD="$(printf '%s' "$DISCUSSIONS" | jq -c --arg id "$DISCUSSION_ID" '[.[] | select(.id == $id)][0] // empty')"
[[ -n "$THREAD" ]] || { echo "discussion $DISCUSSION_ID not found on PR #$NUM" >&2; exit 3; }
KIND="$(printf '%s' "$THREAD" | jq -r '.kind // "review_thread"')"

if [[ "$KIND" == "review_thread" ]]; then
  gh api graphql \
    -f query='mutation($id: ID!, $body: String!) { addPullRequestReviewThreadReply(input: {pullRequestReviewThreadId: $id, body: $body}) { comment { id } } }' \
    -f id="$DISCUSSION_ID" -f body="$BODY" >/dev/null 2>&1 || {
      echo "gh api graphql failed posting reply to discussion $DISCUSSION_ID on PR #$NUM" >&2
      exit 3
    }
else
  # Quote-reply: GitHub has no threaded replies on issue comments / review
  # summaries, so quote the first line of the original for context.
  QUOTE="$(printf '%s' "$THREAD" | jq -r '.notes[0].body // ""' | sed -n '1p')"
  printf '> %s\n\n%s' "$QUOTE" "$BODY" | gh pr comment "$NUM" --body-file - >/dev/null 2>&1 || {
    echo "gh pr comment failed posting quote-reply on PR #$NUM" >&2
    exit 3
  }
fi

# Resolve (unless --no-resolve). Synthetic threads are non-resolvable: the
# caller is expected to pass --no-resolve for those; keep the failure loud.
if ! $NO_RESOLVE; then
  resolve_thread || {
    echo "could not resolve discussion $DISCUSSION_ID on PR #$NUM" \
         "(non-resolvable thread? use --no-resolve)" >&2
    exit 3
  }
fi
