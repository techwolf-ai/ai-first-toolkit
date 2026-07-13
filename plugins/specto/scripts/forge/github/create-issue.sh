#!/usr/bin/env bash
# Create a GitHub issue for plugin friction. This is the one vetted
# `gh issue create` call; the plugin-feedback skill shells out to it instead of
# inlining gh.
#
# The target repo is an argument, same contract as the gitlab impl: pass
# --repo <owner/repo> (the plugin-feedback skill reads `feedback_repo` from
# config). Live mode requires it: there is no sane hardcoded default.
#
# Safe for sequential batch use: every call blocks until the created issue is
# re-fetched and verified against the submitted title + body (the verification
# pattern ported from the gitlab impl: gh is better-behaved than glab, but the
# defense is kept):
#   - false-failure: a non-zero exit with the created-issue URL still printed
#     is treated as success (the exit code alone is never trusted).
#   - title/body desync: the re-fetch catches it via a body fingerprint and
#     repairs the body in place (PATCH).
#
# Usage:
#   create-issue.sh <title> <body-file|-> --repo <owner/repo>
#   create-issue.sh <title> <body-file|-> [--repo <owner/repo>] --from-fixture <dir>
#
# <body-file> may be "-" to read the body from stdin.
# --from-fixture <dir>: reads <dir>/issue.json: {"number": 7, "html_url": "..."} -
#   and prints the number without touching the network. If <dir>/verify.json
#   exists: {"number": 7, "title": "...", "body": "..."}: the post-create
#   verification runs against it (fixture mode cannot repair; a mismatch
#   reports and exits 1).
#
# Output: the new issue's number on stdout (nothing else). Warnings/errors to stderr.
# Exit:
#   0: issue created and verified (or number printed in fixture mode)
#   1: body empty / unreadable, the number could not be parsed from gh output,
#       or the issue exists with wrong content that could not be repaired (the
#       number is still printed on stdout; do NOT re-file)
#   2: bad usage (incl. live mode without --repo)
#   3: gh not on PATH / the gh call failed without creating anything

set -u
set -o pipefail

usage() {
  echo "usage: create-issue.sh <title> <body-file|-> --repo <owner/repo> [--from-fixture <dir>]" >&2
  exit 2
}

[[ $# -lt 2 ]] && usage
TITLE="$1"
BODY_SRC="$2"
shift 2

REPO=""
FIXTURE_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)         [[ $# -ge 2 ]] || usage; REPO="$2"; shift 2 ;;
    --from-fixture) [[ $# -ge 2 ]] || usage; FIXTURE_DIR="$2"; shift 2 ;;
    *)              usage ;;
  esac
done

# Read the body.
if [[ "$BODY_SRC" == "-" ]]; then
  BODY="$(cat)"
else
  [[ -f "$BODY_SRC" ]] || { echo "body file not found: $BODY_SRC" >&2; exit 2; }
  BODY="$(cat "$BODY_SRC")"
fi
if [[ -z "${BODY//[[:space:]]/}" ]]; then
  echo "issue body is empty" >&2
  exit 1
fi

# --- verification helpers -----------------------------------------------------------
# The body comparison is a fingerprint (first non-blank line + whitespace-stripped
# length), not byte equality: robust against trailing-newline / line-ending
# normalization on GitHub's side while still catching a body shift.

first_nonblank_line() {
  printf '%s\n' "$1" | sed -n '/[^[:space:]]/{s/^[[:space:]]*//;s/[[:space:]]*$//;p;q;}'
}

stripped_len() {
  printf '%s' "$1" | tr -d '[:space:]' | wc -c | tr -d ' '
}

MISMATCH=""
verify_match() { # <fetched-title> <fetched-body>
  local ft="$1" fd="$2"
  if [[ "$ft" != "$TITLE" ]]; then
    MISMATCH="title (submitted: $TITLE; stored: $ft)"
    return 1
  fi
  if [[ "$(first_nonblank_line "$fd")" != "$(first_nonblank_line "$BODY")" ]]; then
    MISMATCH="body (first line differs: likely another call's body)"
    return 1
  fi
  if [[ "$(stripped_len "$fd")" != "$(stripped_len "$BODY")" ]]; then
    MISMATCH="body (length differs: likely another call's body)"
    return 1
  fi
  return 0
}

# --- fixture mode -----------------------------------------------------------------
if [[ -n "$FIXTURE_DIR" ]]; then
  [[ -d "$FIXTURE_DIR" ]] || { echo "fixture dir not found: $FIXTURE_DIR" >&2; exit 3; }
  f="$FIXTURE_DIR/issue.json"
  [[ -f "$f" ]] || { echo "fixture file not found: $f" >&2; exit 3; }
  data="$(cat "$f")"
  echo "$data" | jq . >/dev/null 2>&1 || { echo "fixture JSON unparseable: $f" >&2; exit 1; }
  num="$(echo "$data" | jq -r '.number // empty')"
  [[ -n "$num" ]] || { echo "no .number in fixture: $f" >&2; exit 1; }
  vf="$FIXTURE_DIR/verify.json"
  if [[ -f "$vf" ]]; then
    vt="$(jq -r '.title // empty' "$vf")"
    vd="$(jq -r '.body // empty' "$vf")"
    if ! verify_match "$vt" "$vd"; then
      echo "$num"
      echo "VERIFY FAILED: issue #$num exists with wrong content ($MISMATCH); do NOT re-file" >&2
      exit 1
    fi
  fi
  echo "$num"
  exit 0
fi

# --- live mode --------------------------------------------------------------------
if ! command -v gh >/dev/null; then
  echo "gh not on PATH; install the GitHub CLI" >&2
  exit 3
fi
[[ -n "$REPO" ]] || { echo "--repo <owner/repo> is required in live mode" >&2; usage; }

# Capture stdout+stderr together: on a false-failure gh may still print the
# created-issue URL, and the exit code alone must never decide failure.
OUT="$(printf '%s' "$BODY" | gh issue create --repo "$REPO" --title "$TITLE" --body-file - 2>&1)"
RC=$?

# gh prints the new issue URL: https://github.com/<owner>/<repo>/issues/<number>.
NUM="$(printf '%s\n' "$OUT" | grep -oE '/issues/[0-9]+' | grep -oE '[0-9]+$' | tail -1)"
if [[ -z "$NUM" ]]; then
  if [[ "$RC" -ne 0 ]]; then
    echo "gh issue create failed on $REPO (exit $RC) and printed no created-issue URL (auth? repo access?):" >&2
    printf '%s\n' "$OUT" >&2
    exit 3
  fi
  echo "created the issue but could not parse its number from gh output: $OUT" >&2
  exit 1
fi
if [[ "$RC" -ne 0 ]]; then
  echo "warning: gh exited $RC but the issue WAS created as #$NUM; continuing to verification" >&2
fi

fetch_issue() {
  gh api "repos/$REPO/issues/$NUM" 2>/dev/null \
    || gh issue view "$NUM" --repo "$REPO" --json number,title,body 2>/dev/null
}

DATA="$(fetch_issue)"
if [[ -z "$DATA" ]] || ! printf '%s' "$DATA" | jq -e '.number' >/dev/null 2>&1; then
  echo "$NUM"
  echo "warning: created issue #$NUM but could not re-fetch it to verify; check it manually" >&2
  exit 0
fi

FT="$(printf '%s' "$DATA" | jq -r '.title // empty')"
FD="$(printf '%s' "$DATA" | jq -r '.body // empty')"
if ! verify_match "$FT" "$FD"; then
  case "$MISMATCH" in
    body*)
      # A desync leaves the right title with another call's body: the
      # submitted body is authoritative, so repair the body in place.
      echo "warning: issue #$NUM stored mismatching content ($MISMATCH); repairing body" >&2
      if jq -n --arg b "$BODY" '{body: $b}' \
           | gh api --method PATCH "repos/$REPO/issues/$NUM" --input - >/dev/null 2>&1; then
        DATA="$(fetch_issue)"
        FT="$(printf '%s' "$DATA" | jq -r '.title // empty')"
        FD="$(printf '%s' "$DATA" | jq -r '.body // empty')"
        if verify_match "$FT" "$FD"; then
          echo "$NUM"
          echo "warning: issue #$NUM body repaired and verified" >&2
          exit 0
        fi
      fi
      ;;
  esac
  echo "$NUM"
  echo "VERIFY FAILED: issue #$NUM exists with wrong content ($MISMATCH); do NOT re-file" >&2
  exit 1
fi

echo "$NUM"
