#!/usr/bin/env bash
# Find PRs whose title carries a ticket key (the implement-ticket convention:
# PR titles start with `[<KEY>]`). Prints a normalized JSON array of
# change-request objects, same guaranteed fields as `mr-fetch.sh info`:
#   [{"iid": 42, "web_url": "...", "title": "...", "state": "opened",
#     "draft": true, "source_branch": "...", "target_branch": "..."}, …]
#
# Live mode: `gh pr list --search "[<KEY>] in:title" --state <s> --json …`.
# --state maps to gh's vocabulary: opened -> open; merged/closed/all pass
# through. GitHub states come back upper-case (OPEN/MERGED/CLOSED) and are
# normalized to opened/merged/closed. Project-scoped: run from within the repo.
#
# Usage:
#   find-mr-for-ticket.sh <TICKET-KEY> [--state opened|merged|closed|all]
#   find-mr-for-ticket.sh <TICKET-KEY> [--state …] --from-fixture <path>
#
# Fixture / gh JSON shape: the `gh pr list --json
# number,url,title,state,isDraft,headRefName,baseRefName` array.
#
# Output: the normalized JSON array on stdout (possibly []). Warnings to stderr.
# Exit:
#   0: array printed
#   1: JSON unparseable
#   2: bad usage
#   3: gh not on PATH, or gh call failed

set -u
set -o pipefail

usage() {
  echo "usage: find-mr-for-ticket.sh <TICKET-KEY> [--state opened|merged|closed|all] [--from-fixture <path>]" >&2
  exit 2
}

[[ $# -lt 1 ]] && usage
KEY="$1"
shift

STATE="all"
FIXTURE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --state) [[ $# -ge 2 ]] || usage; STATE="$2"; shift 2 ;;
    --from-fixture) [[ $# -ge 2 ]] || usage; FIXTURE="$2"; shift 2 ;;
    *) usage ;;
  esac
done

if [[ -n "$FIXTURE" ]]; then
  [[ -f "$FIXTURE" ]] || { echo "fixture not found: $FIXTURE" >&2; exit 3; }
  JSON="$(cat "$FIXTURE")"
else
  if ! command -v gh >/dev/null; then
    echo "gh not on PATH; install the GitHub CLI" >&2
    exit 3
  fi
  # Map the neutral state vocabulary to gh's.
  case "$STATE" in
    opened) GH_STATE="open" ;;
    *)      GH_STATE="$STATE" ;;
  esac
  JSON="$(gh pr list --search "[$KEY] in:title" --state "$GH_STATE" \
            --json number,url,title,state,isDraft,headRefName,baseRefName 2>/dev/null)" || {
    echo "gh pr list failed (auth? network?); run 'gh auth status' to verify" >&2
    exit 3
  }
fi

echo "$JSON" | jq . >/dev/null 2>&1 || { echo "JSON unparseable from pr list" >&2; exit 1; }
echo "$JSON" | jq '[.[] | {
  iid: .number,
  web_url: .url,
  title: .title,
  state: ((.state // "") | ascii_downcase | if . == "open" then "opened" else . end),
  draft: (.isDraft // false),
  source_branch: (.headRefName // ""),
  target_branch: (.baseRefName // "")
}]'
