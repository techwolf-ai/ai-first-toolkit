#!/usr/bin/env bash
# Reply to a discussion thread on the current branch's MR.
#
#   * --discussion <ID>  (default mode) — post a reply via
#                          POST projects/:id/merge_requests/:iid/discussions/:id/notes
#                        Then (by default) resolve the thread via
#                          PUT  projects/:id/merge_requests/:iid/discussions/:id?resolved=true
#                        Pass --no-resolve to skip the resolve step.
#
# Non-resolvable threads (bot reviews like Console Bot / PR Reviewer Guide /
# the MR's own description discussion) are addressed via the SAME endpoint —
# they're discussions in the GitLab API, just with `resolvable: false` on
# their notes. Pass `--no-resolve` to skip the resolve PUT (which would
# 4xx on a non-resolvable thread). The caller (resolve-mr-comments Phase 1
# step 4) decides which mode based on `.notes[0].resolvable`.
#
# Resolution rules  — three modes:
#   * reply + resolve (default) — post the body, then resolve the thread.
#   * --no-resolve — reply only. For deferrals, genuine questions, and
#     non-resolvable threads (bot reviews, the MR description note).
#   * --resolve-only — resolve WITHOUT posting a reply. For feedback already
#     fixed in the pushed commit: the commit is the reply, and a boilerplate
#     "resolved" note is noise. Takes no body; combining it with a body or
#     with --no-resolve is a usage error. The resolve PUT still 4xxes on a
#     non-resolvable thread, so bot threads keep using --no-resolve.
#
# The positional form `<discussion-id> <body-file>` is preserved for backward
# compatibility with the initial V0.9 wire-up; new callers should prefer the
# explicit `--discussion <id>` flag form.
#
# By default the MR iid is resolved off the current branch's open MR (via
# specto_source_branch + `glab mr view`). Pass --iid <N> to target an MR
# directly — this skips branch resolution entirely, so replies work on a
# detached HEAD or when acting on someone else's MR by URL (matching the
# --iid/--branch flags mr-fetch.sh already has, so resolve-mr-comments can
# pass the IID it resolved in Phase 1 straight through to the Phase 5 reply).
# --branch <name> looks the MR up by source branch instead. --iid and --branch
# are mutually exclusive.
#
# Usage:
#   mr-reply.sh <discussion-id> <body-file|->                            # legacy form: reply + resolve
#   mr-reply.sh --discussion <id> <body-file|-> [--no-resolve]           # explicit form
#   mr-reply.sh --discussion <id> --resolve-only                         # resolve silently, no reply
#   mr-reply.sh --discussion <id> <body-file|-> --iid <N>                # target MR by iid (no branch guessing)
#   mr-reply.sh --discussion <id> <body-file|-> --branch <name>          # target MR by source branch
#   mr-reply.sh <target...> <body-file|-> --from-fixture <dir>           # test mode
#
# <body-file> may be "-" to read from stdin.
# --from-fixture <dir>: does NOT touch the network. Prints, on a single
# machine-parseable line, the decision:
#       REPLY_RESOLVE discussion=<id>    (default mode)
#       REPLY discussion=<id>            (--no-resolve)
#       RESOLVE discussion=<id>          (--resolve-only)
# so the test can assert which branch was taken.
#
# Output (live): nothing on stdout (note id goes nowhere); warnings to stderr.
# Output (fixture): the decision line on stdout.
# Exit:
#   0 — replied/resolved as requested, or decision printed in fixture mode
#   1 — body empty
#   2 — bad usage (incl. --iid + --branch both supplied, --resolve-only with a
#       body or with --no-resolve)
#   3 — glab not on PATH / not in a repo / no MR / API call failed
#
# History note: an earlier V0.9 draft added a `--note <NOTE_ID>` mode that
# POSTed to `projects/:id/merge_requests/:iid/notes/:note_id/notes`. That
# endpoint does not exist in the GitLab API (returns 404) — bot notes are
# already inside discussions, so the discussion endpoint handles them. The
# `--note` mode was removed; bot replies use `--discussion <id> --no-resolve`.

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
# `--discussion <id> <body-file>` (new). Both end with the body in $BODY_SRC
# and the thread in $DISCUSSION_ID. --resolve-only exists only in the flag form:
# the legacy form takes the body positionally, so it always has one.
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
# --iid and --branch are mutually exclusive: each names a different MR.
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
if ! command -v glab >/dev/null; then
  echo "glab not on PATH; install the GitLab CLI" >&2
  exit 3
fi
PROJECT_ID="$(glab repo view --output json 2>/dev/null | jq -r '.id // empty')" || true
[[ -n "$PROJECT_ID" ]] || { echo "could not resolve the GitLab project" >&2; exit 3; }
# Resolve the target MR iid. --iid skips branch resolution entirely (deterministic,
# works on a detached HEAD or when reviewing someone else's MR by URL); --branch
# names the source branch to look up; otherwise fall back to the current branch.
if [[ -n "$EXPLICIT_IID" ]]; then
  MR_IID="$EXPLICIT_IID"
else
  [[ -n "$BRANCH" ]] || BRANCH="$(specto_source_branch)" || {
    echo "could not resolve the source branch (detached HEAD?); pass --iid/--branch or set SOURCE_BRANCH" >&2
    exit 3
  }
  MR_IID="$(glab mr view "$BRANCH" --output json 2>/dev/null | jq -r '.iid // empty')" || true
  [[ -n "$MR_IID" ]] || { echo "no open MR for branch $BRANCH" >&2; exit 3; }
fi

# Step 1: reply via the discussion endpoint (skipped under --resolve-only:
# the fix in the pushed commit is the reply).
if ! $RESOLVE_ONLY; then
  glab api --method POST \
    "projects/$PROJECT_ID/merge_requests/$MR_IID/discussions/$DISCUSSION_ID/notes" \
    -f "body=$BODY" >/dev/null 2>&1 || {
      echo "glab api failed posting reply to discussion $DISCUSSION_ID on MR !$MR_IID" >&2
      exit 3
    }
fi

# Step 2: resolve (unless --no-resolve). For non-resolvable discussions
# (bot reviews, the MR description note, …) the caller is expected to
# pass --no-resolve; otherwise the PUT will 4xx and the helper exits 3.
if ! $NO_RESOLVE; then
  glab api --method PUT \
    "projects/$PROJECT_ID/merge_requests/$MR_IID/discussions/$DISCUSSION_ID?resolved=true" \
    >/dev/null 2>&1 || {
      echo "could not resolve discussion $DISCUSSION_ID on MR !$MR_IID" \
           "(non-resolvable thread? use --no-resolve)" >&2
      exit 3
    }
fi
