#!/usr/bin/env bash
# Read side of the markdown-reviewer local-comment seam (markdown-reviewer is an
# optional external companion app, not part of this plugin): list the
# comments in `<repo-root>/.md-review/comments.json` as JSON lines, optionally
# filtered to specto-written and/or unresolved ones. This powers the
# "push the survivors" replay: after the author triages findings in a
# local-comment UI, the still-unresolved specto comments are the survivors —
# each line carries the parsed (agent, section, finding_type) from the marker
# plus `body_clean` (marker line stripped), which is exactly what
# post-mr-comment.sh needs to post the finding line-anchored on the MR with the
# SAME sha8 (so a previously posted finding folds onto its existing thread).
#
# Usage:
#   list-local-comments.sh <repo-root> [--specto-only] [--unresolved]
#
# Output: one JSON object per line (jq -c). specto-written comments gain:
#   agent, sha8, section, finding_type, body_clean
# Exit:
#   0 — listed (a missing store is an empty list, not an error)
#   1 — the store exists but is not valid JSON
#   2 — bad usage
#   3 — jq not on PATH

set -u
set -o pipefail

usage() {
  echo "usage: list-local-comments.sh <repo-root> [--specto-only] [--unresolved]" >&2
  exit 2
}

[[ $# -lt 1 ]] && usage
REPO_ROOT="$1"; shift

SPECTO_ONLY=false
UNRESOLVED=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --specto-only) SPECTO_ONLY=true; shift ;;
    --unresolved)  UNRESOLVED=true; shift ;;
    *)             usage ;;
  esac
done

command -v jq >/dev/null || { echo "jq not on PATH" >&2; exit 3; }
[[ -d "$REPO_ROOT" ]] || { echo "repo root not found: $REPO_ROOT" >&2; exit 2; }

STORE="$REPO_ROOT/.md-review/comments.json"
[[ -f "$STORE" ]] || exit 0

if ! jq -e . "$STORE" >/dev/null 2>&1; then
  echo "store is not valid JSON: $STORE" >&2
  exit 1
fi

jq -c --argjson specto_only "$SPECTO_ONLY" --argjson unresolved "$UNRESOLVED" '
  .comments[]?
  | select(($specto_only | not) or ((.source // "") | startswith("specto:")))
  | select(($unresolved | not) or ((.resolved // false) | not))
  | ((.body // "") | split("\n")) as $lines
  | (($lines[0] // "")
     | capture("^\\[specto:(?<agent>[^#]+)#(?<sha8>[0-9a-f]{8})\\] (?<section>\\S+) (?<ftype>\\S+)$")
     // null) as $m
  | if $m then
      . + { agent: $m.agent, sha8: $m.sha8, section: $m.section,
            finding_type: $m.ftype, body_clean: ($lines[1:] | join("\n")) }
    else . end
' "$STORE"
