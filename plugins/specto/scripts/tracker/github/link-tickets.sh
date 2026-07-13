#!/usr/bin/env bash
# Create a link between two GitHub issues. Only the canonical `blocks` type
# exists natively (issue dependencies, gh >= 2.94); `relates` and every other
# type exit 4 (no native concept; a task-list mention is a v2 idea).
#
# Usage (identical to the jira counterpart):
#   link-tickets.sh <link-type> <from-KEY> <to-KEY>
#   link-tickets.sh <link-type> <from-KEY> <to-KEY> --from-fixture <path>
#
# The link reads as: "<from-KEY> <link-type> <to-KEY>", same as the jira
# backend's outward-description convention:
#   link-tickets.sh blocks 100 200  ->  "#100 blocks #200"
#
# Direction mapping: GitHub models the dependency edge from the BLOCKED side
# ("#200 is blocked by #100"), so "<FROM> blocks <TO>" writes
#   gh issue edit <TO> --add-blocked-by <FROM>
# gh's flag names are unambiguous (no acli-style --in/--out lie), so no
# read-back direction verification is needed on this backend.
#
# Output: nothing on stdout on success; warnings/errors to stderr.
# Exit:
#   0 - link created (or fixture says success)
#   2 - bad usage
#   3 - gh not on PATH, or the gh call failed
#   4 - link type has no native GitHub concept (relates, or anything else)

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/_lib.sh"

usage() {
  echo "usage: link-tickets.sh <link-type> <from-KEY> <to-KEY> [--from-fixture <path>]" >&2
  exit 2
}

[[ $# -lt 3 ]] && usage
LINK_TYPE="$1"
FROM_KEY="$2"
TO_KEY="$3"
shift 3

FIXTURE=""
if [[ $# -gt 0 ]]; then
  if [[ "$1" == "--from-fixture" && $# -ge 2 ]]; then
    FIXTURE="$2"
    shift 2
  else
    usage
  fi
fi

# Static capability check: happens before fixture handling, so an unsupported
# type exits 4 in every mode.
case "$(printf '%s' "$LINK_TYPE" | tr '[:upper:]' '[:lower:]')" in
  blocks) ;;
  relates)
    echo "not supported on github: link type 'relates' has no native concept (a task-list mention is a v2 idea)" >&2
    exit 4 ;;
  *)
    echo "not supported on github: link type '$LINK_TYPE' (only 'blocks' maps to native issue dependencies)" >&2
    exit 4 ;;
esac

if [[ -n "$FIXTURE" ]]; then
  # Fixture mode: a present (any-content) file means "the link create succeeded".
  [[ -f "$FIXTURE" ]] || { echo "fixture not found: $FIXTURE" >&2; exit 3; }
  exit 0
fi

specto_require_gh

# "<FROM> blocks <TO>" == "<TO> is blocked by <FROM>": the write goes to the
# blocked issue (see the direction note in the header).
if ! gh issue edit "$TO_KEY" --add-blocked-by "$FROM_KEY" >/dev/null 2>&1; then
  echo "gh issue edit --add-blocked-by failed: $FROM_KEY blocks $TO_KEY (auth? numbers?)" >&2
  exit 3
fi
