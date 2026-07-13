#!/usr/bin/env bash
# Find MRs whose title carries a ticket key (the implement-ticket convention:
# MR titles start with `[<KEY>]`). Prints a normalized JSON array of
# change-request objects, same guaranteed fields as `mr-fetch.sh info`:
#   [{"iid": 42, "web_url": "...", "title": "...", "state": "opened",
#     "draft": true, "source_branch": "...", "target_branch": "..."}, …]
#
# Replaces the previous inline `glab mr list --search "[<KEY>]"` in the dod
# agent (docs/contracts.md single-vetted-entry-point rule). Project-scoped:
# run from within the repo.
#
# Usage:
#   find-mr-for-ticket.sh <TICKET-KEY> [--state opened|merged|closed|all]
#   find-mr-for-ticket.sh <TICKET-KEY> [--state …] --from-fixture <path>
#
# Fixture / glab JSON shape: the `glab mr list --output json` array.
#
# Output: the normalized JSON array on stdout (possibly []). Warnings to stderr.
# Exit:
#   0 — array printed
#   1 — JSON unparseable
#   2 — bad usage
#   3 — glab not on PATH, or glab call failed

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
  if ! command -v glab >/dev/null; then
    echo "glab not on PATH; install the GitLab CLI" >&2
    exit 3
  fi
  ARGS=(mr list --search "[$KEY]" --output json)
  [[ "$STATE" != "all" ]] && ARGS+=(--"$STATE")
  JSON="$(glab "${ARGS[@]}" 2>/dev/null)" || {
    echo "glab mr list failed (auth? network?); run 'glab auth status' to verify" >&2
    exit 3
  }
fi

echo "$JSON" | jq . >/dev/null 2>&1 || { echo "JSON unparseable from mr list" >&2; exit 1; }
echo "$JSON" | jq '[.[] | {iid, web_url, title, state, draft,
                           source_branch, target_branch}]'
