#!/usr/bin/env bash
# Idempotently maintain a marker-delimited section inside a PR's description,
# leaving the rest of the description (and the title) untouched.
#
# Port of the gitlab impl: splices ONE region delimited by
#     <!-- specto:walkthrough:start -->  …  <!-- specto:walkthrough:end -->
# Re-running replaces that region in place instead of appending a duplicate.
# Used by the `mr-walkthrough` skill to keep a "## Change walkthrough" section live.
#
# The section body is read from <body-file> or "-" (stdin) and should be the full
# markdown (heading + mermaid blocks). The markers are added by this script.
#
# Usage:
#   mr-describe.sh <body-file|-> [--iid <N> | --branch <name>]
#   mr-describe.sh <body-file|-> [--iid <N> | --branch <name>] --from-fixture <dir>
#
# --from-fixture <dir>: reads <dir>/info.json (the GitHub `gh pr view --json …`
#   shape: the current description is `.body`), performs the splice in memory,
#   and prints the resulting description to stdout WITHOUT touching the network.
#
# Output (live): the PR web URL on stdout. Output (fixture): the spliced description.
# Exit:
#   0: updated (or spliced description printed in fixture mode)
#   1: body empty / unreadable
#   2: bad usage (incl. --iid + --branch both supplied)
#   3: gh not on PATH / not in a repo / no PR / the gh call failed

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
. "$SCRIPT_DIR/_lib.sh"

START='<!-- specto:walkthrough:start -->'
END='<!-- specto:walkthrough:end -->'

usage() {
  echo "usage: mr-describe.sh <body-file|-> [--iid <N> | --branch <name>] [--from-fixture <dir>]" >&2
  exit 2
}

[[ $# -lt 1 ]] && usage
BODY_SRC="$1"
shift

FIXTURE_DIR=""
EXPLICIT_IID=""
BRANCH=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from-fixture)  [[ $# -ge 2 ]] || usage; FIXTURE_DIR="$2"; shift 2 ;;
    --iid)           [[ $# -ge 2 ]] || usage; EXPLICIT_IID="$2"; shift 2 ;;
    --branch)        [[ $# -ge 2 ]] || usage; BRANCH="$2"; shift 2 ;;
    *)               usage ;;
  esac
done
[[ -n "$EXPLICIT_IID" && -n "$BRANCH" ]] && usage

# Read the section body.
if [[ "$BODY_SRC" == "-" ]]; then
  BODY="$(cat)"
else
  [[ -f "$BODY_SRC" ]] || { echo "body file not found: $BODY_SRC" >&2; exit 2; }
  BODY="$(cat "$BODY_SRC")"
fi
if [[ -z "${BODY//[[:space:]]/}" ]]; then
  echo "walkthrough body is empty" >&2
  exit 1
fi

# splice <current-description> -> stdout: drop any existing marker block, trim the
# trailing blank line it left behind, then append the fresh block.
splice() {
  local cur="$1"
  local stripped
  stripped="$(printf '%s\n' "$cur" | awk -v s="$START" -v e="$END" '
    $0==s {skip=1; next}
    skip && $0==e {skip=0; next}
    !skip {print}
  ')"
  # Trim trailing whitespace-only lines so the block always sits one blank line down.
  stripped="$(printf '%s' "$stripped" | awk 'NR>1{print prev} {prev=$0} END{if (NR>0 && prev ~ /[^[:space:]]/) print prev}')"
  if [[ -n "${stripped//[[:space:]]/}" ]]; then
    printf '%s\n\n%s\n%s\n%s\n' "$stripped" "$START" "$BODY" "$END"
  else
    printf '%s\n%s\n%s\n' "$START" "$BODY" "$END"
  fi
}

# --- fixture mode -----------------------------------------------------------------
if [[ -n "$FIXTURE_DIR" ]]; then
  [[ -d "$FIXTURE_DIR" ]] || { echo "fixture dir not found: $FIXTURE_DIR" >&2; exit 3; }
  f="$FIXTURE_DIR/info.json"
  [[ -f "$f" ]] || { echo "fixture file not found: $f" >&2; exit 3; }
  jq . "$f" >/dev/null 2>&1 || { echo "fixture JSON unparseable: $f" >&2; exit 3; }
  cur="$(jq -r '.body // ""' "$f")"
  splice "$cur"
  exit 0
fi

# --- live mode --------------------------------------------------------------------
if ! command -v gh >/dev/null; then
  echo "gh not on PATH; install the GitHub CLI" >&2
  exit 3
fi

[[ -n "$BRANCH" || -n "$EXPLICIT_IID" ]] || BRANCH="$(specto_source_branch)" || {
  echo "could not resolve the source branch (detached HEAD?); pass --branch or --iid" >&2
  exit 3
}

# Read the current description through the single read path (its normalized
# output carries the description as an extra field).
if [[ -n "$EXPLICIT_IID" ]]; then
  info="$("$SCRIPT_DIR/mr-fetch.sh" info --iid "$EXPLICIT_IID")" || exit 3
else
  info="$("$SCRIPT_DIR/mr-fetch.sh" info --branch "$BRANCH")" || exit 3
fi
cur="$(jq -r '.description // ""' <<<"$info")"
NEW="$(splice "$cur")"

# gh pr edit takes the description via --body-file and leaves the title alone.
TARGET="${EXPLICIT_IID:-$BRANCH}"
if ! printf '%s' "$NEW" | gh pr edit "$TARGET" --body-file - >/dev/null 2>&1; then
  echo "gh pr edit failed for PR '$TARGET'" >&2; exit 3
fi
jq -r '.web_url // empty' <<<"$info"
