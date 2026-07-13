#!/usr/bin/env bash
# Write one specto finding into the markdown-reviewer local-comment sidecar
# (markdown-reviewer is an optional external companion app, not part of this plugin)
# (`<repo-root>/.md-review/comments.json`) instead of posting an MR thread.
# This is the write side of the local-triage seam: findings land here,
# the author triages them in a local-comment UI (edit / resolve / delete
# false positives), and only the survivors get pushed to GitLab later (replay
# via list-local-comments.sh + post-mr-comment.sh).
#
# Pure filesystem — no network, no server needed (no companion app has to be
# running; the sidecar file IS the API). The store shape matches the
# markdown-reviewer comment store, including the
# self-ignoring `.gitignore` (`*`) so the folder is never committed regardless
# of which side created it.
#
# Idempotency mirrors post-mr-comment.sh:
#   sha8 = sha1(<agent> ∥ <file> ∥ normalize(<section>) ∥ normalize(<finding-type>))[:8]
# The stored body's FIRST LINE is the marker + replay metadata:
#   [specto:<agent>#<sha8>] <section-normalized> <finding-type-normalized>
# A comment whose body already starts with the same marker is EDITed in place
# (body / source_line / line_text refreshed; id, created_at, resolved, replies
# preserved) — re-running a reviewer folds onto the same comment instead of
# duplicating. The marker tail lets the push-survivors replay reconstruct the
# (agent, section, finding-type) triple post-mr-comment.sh needs, so a finding
# pushed later folds onto its existing MR thread (same sha8).
#
# Usage:
#   add-local-comment.sh <repo-root> <file> <line> <agent> <section> <finding-type> <body-file|->
#   add-local-comment.sh ... --from-fixture <dir>
#
# <file> is repo-root-relative (the same path the markdown-reviewer UI shows).
# <body-file> may be "-" to read the body from stdin.
# --from-fixture <dir>: reads <dir>/comments.json as the existing store and
#   prints the decision WITHOUT writing anything (test mode).
#
# Output: one machine-parseable decision line on stdout:
#       CREATE sha8=<8hex> id=<id>
#       EDIT sha8=<8hex> id=<id>
# Exit:
#   0 — comment created/updated (or decision printed in fixture mode)
#   1 — body empty, or the existing store is not valid JSON (never clobbered)
#   2 — bad usage
#   3 — jq not on PATH

set -u
set -o pipefail

usage() {
  echo "usage: add-local-comment.sh <repo-root> <file> <line> <agent> <section> <finding-type> <body-file|-> [--from-fixture <dir>]" >&2
  exit 2
}

[[ $# -lt 7 ]] && usage
REPO_ROOT="$1"; FILE="$2"; LINE="$3"; AGENT="$4"; SECTION="$5"; FINDING_TYPE="$6"; BODY_SRC="$7"
shift 7

FIXTURE_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from-fixture) [[ $# -ge 2 ]] || usage; FIXTURE_DIR="$2"; shift 2 ;;
    *)              usage ;;
  esac
done

command -v jq >/dev/null || { echo "jq not on PATH" >&2; exit 3; }
[[ "$LINE" =~ ^[0-9]+$ ]] || usage
[[ -d "$REPO_ROOT" ]] || { echo "repo root not found: $REPO_ROOT" >&2; exit 2; }

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

# Same normalize + key derivation as post-mr-comment.sh, so the same finding
# carries the same sha8 on both surfaces.
normalize() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'; }
SECTION_N="$(normalize "$SECTION")"
TYPE_N="$(normalize "$FINDING_TYPE")"
SHA8="$(printf '%s\0%s\0%s\0%s' "$AGENT" "$FILE" "$SECTION_N" "$TYPE_N" | sha1sum | cut -c1-8)"
MARKER="[specto:${AGENT}#${SHA8}]"
FULL_BODY="${MARKER} ${SECTION_N} ${TYPE_N}
${BODY}"

# Resolve the store (fixture = read-only).
if [[ -n "$FIXTURE_DIR" ]]; then
  STORE="$FIXTURE_DIR/comments.json"
  [[ -f "$STORE" ]] || { echo "fixture store not found: $STORE" >&2; exit 3; }
else
  STORE="$REPO_ROOT/.md-review/comments.json"
fi

if [[ -f "$STORE" ]]; then
  EXISTING="$(cat "$STORE")"
  if ! printf '%s' "$EXISTING" | jq -e . >/dev/null 2>&1; then
    echo "existing store is not valid JSON — refusing to clobber: $STORE" >&2
    exit 1
  fi
else
  EXISTING='{"version":1,"comments":[]}'
fi

EXIST_ID="$(printf '%s' "$EXISTING" | jq -r --arg m "$MARKER" \
  '[.comments[]? | select((.body // "") | startswith($m)) | .id] | first // empty')"

LINE_TEXT=""
[[ -f "$REPO_ROOT/$FILE" ]] && LINE_TEXT="$(sed -n "${LINE}p" "$REPO_ROOT/$FILE")"

if [[ -n "$EXIST_ID" ]]; then
  NEW_STORE="$(printf '%s' "$EXISTING" | jq \
    --arg id "$EXIST_ID" --arg body "$FULL_BODY" --argjson line "$LINE" --arg lt "$LINE_TEXT" '
    .comments = (.comments | map(
      if .id == $id then .body = $body | .source_line = $line | .line_text = $lt else . end))')"
  DECISION="EDIT sha8=$SHA8 id=$EXIST_ID"
else
  ID="$(uuidgen 2>/dev/null | tr '[:upper:]' '[:lower:]' || true)"
  [[ -n "$ID" ]] || ID="specto-${SHA8}-$$"
  COMMIT_SHA="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || true)"
  CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  NEW_STORE="$(printf '%s' "$EXISTING" | jq \
    --arg id "$ID" --arg file "$FILE" --argjson line "$LINE" --arg lt "$LINE_TEXT" \
    --arg sha "$COMMIT_SHA" --arg body "$FULL_BODY" --arg at "$CREATED_AT" --arg src "specto:$AGENT" '
    .version = (.version // 1)
    | .comments = ((.comments // []) + [{
        id: $id, file: $file, source_line: $line, line_text: $lt, commit_sha: $sha,
        body: $body, created_at: $at, resolved: false, source: $src, replies: []
      }])')"
  DECISION="CREATE sha8=$SHA8 id=$ID"
fi

if [[ -z "$FIXTURE_DIR" ]]; then
  mkdir -p "$REPO_ROOT/.md-review"
  [[ -f "$REPO_ROOT/.md-review/.gitignore" ]] || printf '*\n' > "$REPO_ROOT/.md-review/.gitignore"
  printf '%s\n' "$NEW_STORE" > "$STORE"
fi

echo "$DECISION"
