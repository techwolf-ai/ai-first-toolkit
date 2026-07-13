#!/usr/bin/env bash
# Post a line-anchored review discussion on the current branch's MR — idempotently.
# This is the single vetted `glab api` posting path; the five Specto reviewer
# agents shell out to it instead of each carrying a copy of the posting block.
#
# Idempotency: a stable 8-hex marker
#   sha8 = sha1(<agent-name> ∥ <spec-path> ∥ normalize(<section>) ∥ normalize(<finding-type>))[:8]
# (∥ = NUL separator; normalize lowercases and collapses non-alphanumeric runs to
# a single '-'). It is embedded in the body as `[specto:<agent-name>#<sha8>] `.
# Before posting, the helper fetches existing discussions (via mr-fetch.sh) and
# scans EVERY note in EVERY discussion for that marker. If found → it PUTs an
# update to that note in place. If not → it creates a new discussion. So re-running
# a reviewer collapses onto the same thread instead of duplicating findings — and
# because the key is derived from (section, finding-type) rather than free text,
# reworded findings still fold onto the same thread.
#
# Position: a CREATE computes its GitLab text-position from the MR diff (fetched via
# mr-fetch.sh diff). An added line anchors with `new_line` only; an unchanged line
# (in a hunk's context, or in the gaps between hunks) anchors with both `old_line`
# and `new_line`. If the spec file is not in the MR diff at all, the helper falls
# back to a general (non-line-anchored) note — still carrying the marker, so it
# stays idempotent.
#
# Usage:
#   post-mr-comment.sh <agent-name> <spec-path> <line> <section> <finding-type> <body-file|->
#   post-mr-comment.sh <agent-name> <spec-path> <line> <section> <finding-type> <body-file|-> --from-fixture <dir>
#
# <body-file> may be "-" to read from stdin.
# --from-fixture <dir>: reads <dir>/info.json (for diff_refs SHAs), <dir>/diff.json
#   (for the position computation) and <dir>/discussions.json (for the existing-marker
#   search). It does NOT call the network; instead it prints, on a single
#   machine-parseable line, one of:
#       EDIT sha8=<8hex> discussion=<id> note=<id>
#       CREATE sha8=<8hex> ANCHOR new_line=<n> [old_line=<o>]
#       CREATE sha8=<8hex> GENERAL
#   so the test can assert which branch was taken.
#
# Output (live): nothing on stdout (the discussion/note id goes nowhere); warnings to stderr.
# Output (fixture): the CREATE/EDIT decision line on stdout.
# Exit:
#   0 — posted / updated (or decision printed in fixture mode)
#   1 — body empty / SHAs missing from the MR object
#   2 — bad usage
#   3 — glab not on PATH / not in a repo / no MR / API call failed

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=_lib.sh
. "$HERE/_lib.sh"

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
normalize() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'; }
SECTION_N="$(normalize "$SECTION")"
TYPE_N="$(normalize "$FINDING_TYPE")"
SHA8="$(printf '%s\0%s\0%s\0%s' "$AGENT" "$SPEC_PATH" "$SECTION_N" "$TYPE_N" | sha1sum | cut -c1-8)"
MARKER="[specto:${AGENT}#${SHA8}]"
FULL_BODY="${MARKER} ${BODY}"

# How to get discussions + the MR object: from the fixture dir, or via mr-fetch.sh.
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

# Anchor math is shared across forge backends: specto_compute_anchor in
# ../_anchor.sh emits the five fields (ADDED/UNCHANGED/NONE + lines + canonical
# repo-relative paths). GitLab text positions can anchor any line in the file,
# so no "hunks-only" narrowing here (GitHub's backend passes it).
. "$HERE/../_anchor.sh"
compute_anchor() { specto_compute_anchor "$@"; }

# Search every note of every discussion for our marker; emit "<discussion_id> <note_id>"
# if found (first hit), nothing otherwise.
find_existing() {
  local discussions
  discussions="$(fetch_discussions)" || { echo "could not fetch discussions" >&2; return 3; }
  printf '%s' "$discussions" \
    | jq -r --arg m "$MARKER" '
        .[]? | .id as $did
        | (.notes[]? | select((.body // "") | contains($m)) | "\($did) \(.id)")' \
    | head -1
}

# --- decide CREATE vs EDIT --------------------------------------------------------
EXISTING="$(find_existing)" || { rc=$?; [[ $rc -eq 3 ]] && exit 3 || true; }
DISCUSSION_ID=""
NOTE_ID=""
if [[ -n "${EXISTING:-}" ]]; then
  DISCUSSION_ID="${EXISTING%% *}"
  NOTE_ID="${EXISTING##* }"
fi

# Anchor decision (only needed for a CREATE; an EDIT just rewrites the note body).
# ANCHOR_NP/ANCHOR_OP are the diff's canonical repo-relative paths for position[...].
ANCHOR_KIND=""; ANCHOR_NEW=""; ANCHOR_OLD=""; ANCHOR_NP=""; ANCHOR_OP=""
if [[ -z "$DISCUSSION_ID" ]]; then
  DIFFS="$(fetch_diff)" || { echo "could not fetch MR diff" >&2; exit 3; }
  read -r ANCHOR_KIND ANCHOR_NEW ANCHOR_OLD ANCHOR_NP ANCHOR_OP < <(compute_anchor "$DIFFS" "$SPEC_PATH" "$LINE")
fi

# --- SHAs (needed for a CREATE; harmless to fetch for an EDIT too) ----------------
INFO="$(fetch_info)" || { echo "could not fetch MR info" >&2; exit 3; }
BASE_SHA="$(printf '%s' "$INFO" | jq -r '.diff_refs.base_sha // empty')"
HEAD_SHA="$(printf '%s' "$INFO" | jq -r '.diff_refs.head_sha // empty')"
START_SHA="$(printf '%s' "$INFO" | jq -r '.diff_refs.start_sha // empty')"

# --- fixture mode: print the decision, don't touch the network --------------------
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

# --- live mode --------------------------------------------------------------------
if ! command -v glab >/dev/null; then
  echo "glab not on PATH; install the GitLab CLI" >&2
  exit 3
fi
PROJECT_ID="$(glab repo view --output json 2>/dev/null | jq -r '.id // empty')" || true
[[ -n "$PROJECT_ID" ]] || { echo "could not resolve the GitLab project" >&2; exit 3; }
BRANCH="$(specto_source_branch)" || { echo "could not resolve the source branch (detached HEAD?); set SOURCE_BRANCH" >&2; exit 3; }
MR_IID="$(glab mr view "$BRANCH" --output json 2>/dev/null | jq -r '.iid // empty')" || true
[[ -n "$MR_IID" ]] || { echo "no open MR for branch $BRANCH" >&2; exit 3; }

if [[ -n "$DISCUSSION_ID" ]]; then
  # Edit the existing note in place.
  if ! err="$(glab api --method PUT \
      "projects/$PROJECT_ID/merge_requests/$MR_IID/discussions/$DISCUSSION_ID/notes/$NOTE_ID" \
      -f "body=$FULL_BODY" 2>&1 >/dev/null)"; then
    echo "glab api failed editing note $NOTE_ID on MR !$MR_IID: $err" >&2; exit 3
  fi
  exit 0
fi

# Create a new discussion. Anchor it when the line is in the MR diff; otherwise
# fall back to a general note (still carrying the marker, so it's idempotent).
#
# The position MUST be sent as nested JSON (--input + Content-Type: application/json).
# glab's `-f "position[new_line]=…"` form serializes into a JSON body with the LITERAL
# flat key "position[new_line]"; GitLab does not parse bracket-notation inside JSON
# keys into a nested position, so it silently drops the anchor and creates a plain
# DiscussionNote (a 201, no error). Building real nested JSON is the only thing that
# produces a DiffNote.
payload="$(mktemp)"
if [[ "$ANCHOR_KIND" == "ADDED" || "$ANCHOR_KIND" == "UNCHANGED" ]]; then
  [[ -n "$BASE_SHA" && -n "$HEAD_SHA" && -n "$START_SHA" ]] || {
    echo "MR !$MR_IID has no diff_refs SHAs — cannot anchor a line comment" >&2; rm -f "$payload"; exit 1; }
  pos="$(jq -n --arg base "$BASE_SHA" --arg head "$HEAD_SHA" --arg start "$START_SHA" \
              --arg np "$ANCHOR_NP" --arg op "$ANCHOR_OP" --argjson nl "$ANCHOR_NEW" \
              '{base_sha:$base, head_sha:$head, start_sha:$start, position_type:"text",
                new_path:$np, old_path:$op, new_line:$nl}')"
  [[ "$ANCHOR_KIND" == "UNCHANGED" ]] && \
    pos="$(printf '%s' "$pos" | jq --argjson ol "$ANCHOR_OLD" '. + {old_line:$ol}')"
  jq -n --arg body "$FULL_BODY" --argjson position "$pos" '{body:$body, position:$position}' > "$payload"
else
  echo "§${SECTION} not anchorable (file not in MR diff); posted as GENERAL note" >&2
  jq -n --arg body "$FULL_BODY" '{body:$body}' > "$payload"
fi
resp="$(glab api --method POST "projects/$PROJECT_ID/merge_requests/$MR_IID/discussions" \
          --input "$payload" -H "Content-Type: application/json" 2>&1)"; rc=$?
rm -f "$payload"
if [[ $rc -ne 0 ]]; then
  echo "glab api failed creating a discussion on MR !$MR_IID: $resp" >&2; exit 3
fi
# Verify the anchor actually took. If a position was computed but GitLab created a
# plain note (no position), fail loudly rather than silently reporting success.
if [[ "$ANCHOR_KIND" == "ADDED" || "$ANCHOR_KIND" == "UNCHANGED" ]]; then
  if [[ "$(printf '%s' "$resp" | jq -r '.notes[0].position // "null"' 2>/dev/null)" == "null" ]]; then
    echo "anchor for §${SECTION} was DROPPED by GitLab — note posted without a position on MR !$MR_IID" >&2
    exit 3
  fi
fi
