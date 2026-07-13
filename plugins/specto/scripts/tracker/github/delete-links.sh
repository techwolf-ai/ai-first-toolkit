#!/usr/bin/env bash
# Delete issue-dependency edges across one or more GitHub issues, the inverse
# of link-tickets.sh. Collects every blocks edge touching the given issues
# (de-duped: an edge appears on both endpoints) and removes each via
# `gh issue edit --remove-blocked-by`.
#
# GitHub exposes no per-edge link id, so edge ids are rendered canonically as
#   <blocker>-blocks-<blocked>
# and those strings are what this helper prints (link ids are backend-opaque
# per docs/adapter-contract.md).
#
# Usage (identical to the jira counterpart):
#   delete-links.sh <KEY> [<KEY>...] [--type <Name>] [--dry-run]
#   delete-links.sh <KEY> [<KEY>...] --from-fixture <deps.json>   # test mode (no gh)
#
#   --type <Name>   only 'blocks' (any casing) is meaningful here; every other
#                   type exits 4 (no such link concept on github)
#   --dry-run       print the edge ids that would be deleted; delete nothing
#   --from-fixture  read the dependency lists from the file instead of gh; the
#                   fixture applies to the FIRST <KEY> (shape below)
#
# Fixture shape: {"blocked_by": [{"number": 5}], "blocking": [{"number": 9}]}
# (the two REST dependency lists for the first key, merged into one document).
#
# Output: the deleted (or, with --dry-run/--from-fixture, the candidate) edge
#   ids, one per line, on stdout; warnings/errors to stderr.
# Exit:
#   0 - edges deleted (or dry-run/fixture listed)
#   1 - fixture JSON unparseable
#   2 - bad usage
#   3 - gh/jq not on PATH, or a delete call failed
#   4 - --type names a link concept github does not have

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/_lib.sh"

usage() {
  echo "usage: delete-links.sh <KEY> [<KEY>...] [--type <Name>] [--dry-run] [--from-fixture <path>]" >&2
  exit 2
}

KEYS=()
TYPE=""
DRY_RUN=0
FIXTURE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --type)         [[ $# -ge 2 ]] || usage; TYPE="$2"; shift 2 ;;
    --dry-run)      DRY_RUN=1; shift ;;
    --from-fixture) [[ $# -ge 2 ]] || usage; FIXTURE="$2"; shift 2 ;;
    -*)             usage ;;
    *)              KEYS+=("$1"); shift ;;
  esac
done

[[ ${#KEYS[@]} -ge 1 ]] || usage

# Static capability check: only the blocks family exists on this backend.
if [[ -n "$TYPE" ]]; then
  case "$(printf '%s' "$TYPE" | tr '[:upper:]' '[:lower:]')" in
    blocks) ;;
    *)
      echo "not supported on github: link type '$TYPE' (only 'blocks' maps to native issue dependencies)" >&2
      exit 4 ;;
  esac
fi

# Render both dependency lists of one issue as canonical edge ids.
# stdin: {"blocked_by": [...], "blocking": [...]}; $1: the issue the doc is for.
edges_for() {
  jq -r --arg k "$1" '
    ((.blocked_by // [])[] | "\(.number)-blocks-\($k)"),
    ((.blocking   // [])[] | "\($k)-blocks-\(.number)")
  '
}

# Fixture mode: list the de-duped candidate edges for the first key, no gh.
if [[ -n "$FIXTURE" ]]; then
  [[ -f "$FIXTURE" ]] || { echo "fixture not found: $FIXTURE" >&2; exit 3; }
  jq . "$FIXTURE" >/dev/null 2>&1 || { echo "fixture JSON unparseable: $FIXTURE" >&2; exit 1; }
  edges_for "${KEYS[0]}" < "$FIXTURE" | sort -u
  exit 0
fi

specto_require_gh
command -v jq >/dev/null || { echo "jq not on PATH" >&2; exit 3; }

REPO_PATH="$(specto_gh_repo_path)"

# One REST list, tolerating failures as an empty list (warn and continue,
# mirroring the jira backend's per-key read behaviour).
fetch_list() {
  local out
  if ! out="$(gh api "$REPO_PATH/issues/$1/dependencies/$2" 2>/dev/null)"; then
    echo "warning: could not read $2 dependencies for #$1" >&2
    echo '[]'
    return 0
  fi
  printf '%s' "$out"
}

collect() {
  local k
  for k in "${KEYS[@]}"; do
    jq -n \
      --argjson bb "$(fetch_list "$k" blocked_by)" \
      --argjson bl "$(fetch_list "$k" blocking)" \
      '{blocked_by: $bb, blocking: $bl}' | edges_for "$k"
  done
}
all_edges="$(collect | sort -u)"

if [[ -z "$all_edges" ]]; then
  echo "no links to delete" >&2
  exit 0
fi

if [[ "$DRY_RUN" == "1" ]]; then
  printf '%s\n' "$all_edges"
  exit 0
fi

rc=0
while IFS= read -r edge; do
  [[ -n "$edge" ]] || continue
  blocker="${edge%%-blocks-*}"
  blocked="${edge##*-blocks-}"
  if gh issue edit "$blocked" --remove-blocked-by "$blocker" >/dev/null 2>&1; then
    echo "$edge"
  else
    echo "warning: failed to delete dependency $edge" >&2
    rc=3
  fi
done <<< "$all_edges"
exit $rc
