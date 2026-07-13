#!/usr/bin/env bash
# Create a GitLab issue (work item) for plugin friction. This is the one vetted
# `glab issue create` call; the plugin-feedback skill shells out to it instead of
# inlining glab.
#
# The target repo is --repo <group/project> (the plugin-feedback skill reads
# `feedback_repo` from config): required in live mode. `glab issue create`
# has no --description-file flag, so the body is read into memory and passed via -d.
#
# Safe for sequential batch use: every call blocks until the created issue is
# re-fetched and verified against the submitted title + body, so a plain shell loop
# over this helper serializes on the verification round-trip. Loop callers should
# still stop the loop on any non-zero exit. A separate batch helper is deliberately
# NOT provided — per-call verification already makes the loop safe, and a second
# entry point would just add unvetted surface.
#
# Two glab failure modes this helper defends against (both observed live):
#   - false-failure: `glab issue create` exits non-zero while still creating the
#     work item. The exit code alone is never trusted — stdout/stderr are scanned
#     for the created-issue URL first, so a created-but-noisy call is not reported
#     as a failure (which previously made callers re-file a duplicate).
#   - title/body desync: under rapid sequential creates, glab attached the NEXT
#     call's body to this call's issue (+1 shift). The post-create verification
#     catches it via a body fingerprint and repairs the description in place.
#
# Usage:
#   create-issue.sh <title> <body-file|-> --repo <group/project>
#   create-issue.sh <title> <body-file|-> [--repo <group/project>] --from-fixture <dir>
#
# <body-file> may be "-" to read the body from stdin.
# --from-fixture <dir>: reads <dir>/issue.json — {"iid": 7, "web_url": "..."} — and
#   prints the iid without touching the network. If <dir>/verify.json exists —
#   {"iid": 7, "title": "...", "description": "..."} — the post-create verification
#   runs against it (fixture mode cannot repair; a mismatch reports and exits 1).
#
# Output: the new issue's IID on stdout (nothing else). Warnings/errors to stderr.
# Exit:
#   0 — issue created and verified (or iid printed in fixture mode)
#   1 — body empty / unreadable, the iid could not be parsed from glab output, or
#       the issue exists with wrong content that could not be repaired (the IID is
#       still printed on stdout; do NOT re-file)
#   2 — bad usage (incl. live mode without --repo)
#   3 — glab not on PATH / the glab call failed without creating anything

set -u
set -o pipefail

REPO=""

usage() {
  echo "usage: create-issue.sh <title> <body-file|-> --repo <group/project> [--from-fixture <dir>]" >&2
  exit 2
}

[[ $# -lt 2 ]] && usage
TITLE="$1"
BODY_SRC="$2"
shift 2

FIXTURE_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)         [[ $# -ge 2 ]] || usage; REPO="$2"; shift 2 ;;
    --from-fixture) [[ $# -ge 2 ]] || usage; FIXTURE_DIR="$2"; shift 2 ;;
    *)              usage ;;
  esac
done

[[ -z "$FIXTURE_DIR" && -z "$REPO" ]] && usage

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
# length), not byte equality — robust against trailing-newline / line-ending
# normalization on GitLab's side while still catching the observed +1 body shift.

first_nonblank_line() {
  printf '%s\n' "$1" | sed -n '/[^[:space:]]/{s/^[[:space:]]*//;s/[[:space:]]*$//;p;q;}'
}

stripped_len() {
  printf '%s' "$1" | tr -d '[:space:]' | wc -c | tr -d ' '
}

MISMATCH=""
verify_match() { # <fetched-title> <fetched-description>
  local ft="$1" fd="$2"
  if [[ "$ft" != "$TITLE" ]]; then
    MISMATCH="title (submitted: $TITLE; stored: $ft)"
    return 1
  fi
  if [[ "$(first_nonblank_line "$fd")" != "$(first_nonblank_line "$BODY")" ]]; then
    MISMATCH="body (first line differs — likely another call's body)"
    return 1
  fi
  if [[ "$(stripped_len "$fd")" != "$(stripped_len "$BODY")" ]]; then
    MISMATCH="body (length differs — likely another call's body)"
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
  iid="$(echo "$data" | jq -r '.iid // empty')"
  [[ -n "$iid" ]] || { echo "no .iid in fixture: $f" >&2; exit 1; }
  vf="$FIXTURE_DIR/verify.json"
  if [[ -f "$vf" ]]; then
    vt="$(jq -r '.title // empty' "$vf")"
    vd="$(jq -r '.description // empty' "$vf")"
    if ! verify_match "$vt" "$vd"; then
      echo "$iid"
      echo "VERIFY FAILED — issue #$iid exists with wrong content ($MISMATCH); do NOT re-file" >&2
      exit 1
    fi
  fi
  echo "$iid"
  exit 0
fi

# --- live mode --------------------------------------------------------------------
if ! command -v glab >/dev/null; then
  echo "glab not on PATH; install the GitLab CLI" >&2
  exit 3
fi

REPO_ENC="$(jq -rn --arg s "$REPO" '$s|@uri')"

# Capture stdout+stderr together: on a false-failure glab still prints the created
# issue URL, and the exit code alone must never decide failure.
OUT="$(glab issue create --repo "$REPO" --title "$TITLE" -d "$BODY" --yes 2>&1)"
RC=$?

# glab prints the new issue URL. Older glab: …/-/issues/<iid>; current glab:
# …/-/work_items/<iid>. Accept both shapes and extract the trailing number.
IID="$(printf '%s\n' "$OUT" | grep -oE '/(issues|work_items)/[0-9]+' | grep -oE '[0-9]+$' | tail -1)"
if [[ -z "$IID" ]]; then
  if [[ "$RC" -ne 0 ]]; then
    echo "glab issue create failed on $REPO (exit $RC) and printed no created-issue URL (auth? repo access?):" >&2
    printf '%s\n' "$OUT" >&2
    exit 3
  fi
  echo "created the issue but could not parse its IID from glab output: $OUT" >&2
  exit 1
fi
if [[ "$RC" -ne 0 ]]; then
  echo "warning: glab exited $RC but the issue WAS created as #$IID; continuing to verification" >&2
fi

fetch_issue() {
  glab api "projects/$REPO_ENC/issues/$IID" 2>/dev/null \
    || glab issue view "$IID" --repo "$REPO" --output json 2>/dev/null
}

DATA="$(fetch_issue)"
if [[ -z "$DATA" ]] || ! printf '%s' "$DATA" | jq -e .iid >/dev/null 2>&1; then
  echo "$IID"
  echo "warning: created issue #$IID but could not re-fetch it to verify; check it manually" >&2
  exit 0
fi

FT="$(printf '%s' "$DATA" | jq -r '.title // empty')"
FD="$(printf '%s' "$DATA" | jq -r '.description // empty')"
if ! verify_match "$FT" "$FD"; then
  case "$MISMATCH" in
    body*)
      # The observed desync leaves the right title with another call's body — the
      # submitted body is authoritative, so repair the description in place.
      echo "warning: issue #$IID stored mismatching content ($MISMATCH); repairing description" >&2
      if jq -n --arg d "$BODY" '{description:$d}' \
           | glab api --method PUT "projects/$REPO_ENC/issues/$IID" --input - >/dev/null 2>&1; then
        DATA="$(fetch_issue)"
        FT="$(printf '%s' "$DATA" | jq -r '.title // empty')"
        FD="$(printf '%s' "$DATA" | jq -r '.description // empty')"
        if verify_match "$FT" "$FD"; then
          echo "$IID"
          echo "warning: issue #$IID description repaired and verified" >&2
          exit 0
        fi
      fi
      ;;
  esac
  echo "$IID"
  echo "VERIFY FAILED — issue #$IID exists with wrong content ($MISMATCH); do NOT re-file" >&2
  exit 1
fi

echo "$IID"
