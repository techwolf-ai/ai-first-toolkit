#!/usr/bin/env bash
# Set (re-attach) the parent of a GitHub issue via `gh issue edit --set-parent`
# (native sub-issues, gh >= 2.94). Used by create-test-plan to mirror the
# implementer's epic onto the paired Test Plan, and by create-ticket.sh for the
# epic attach. A failed edit (older gh, sub-issues disabled, bad number) is a
# soft failure (exit 3) so the caller can fall back to a `relates` link,
# mirroring the jira convention. Note that `relates` itself exits 4 on this
# backend, so that fallback degrades further here; callers already handle it.
#
# Usage (identical to the jira counterpart):
#   set-parent.sh <KEY> <PARENT_KEY>                       # live
#   set-parent.sh <KEY> <PARENT_KEY> --from-fixture <path> # test (no gh, no network)
#
# Output: nothing on stdout on success; warnings/errors to stderr.
# Exit:
#   0 - parent set
#   2 - bad usage
#   3 - gh not on PATH, or `edit --set-parent` failed / is unsupported
set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/_lib.sh"

usage() {
  echo "usage: set-parent.sh <KEY> <PARENT_KEY> [--from-fixture <path>]" >&2
  exit 2
}

[[ $# -lt 2 ]] && usage
KEY="$1"
PARENT_KEY="$2"
shift 2

FIXTURE=""
if [[ $# -gt 0 ]]; then
  if [[ "$1" == "--from-fixture" && $# -ge 2 ]]; then
    FIXTURE="$2"
    shift 2
  else
    usage
  fi
fi
[[ $# -gt 0 ]] && usage

if [[ -n "$FIXTURE" ]]; then
  [[ -f "$FIXTURE" ]] || { echo "fixture not found: $FIXTURE" >&2; exit 3; }
  exit 0
fi

specto_require_gh

if ! gh issue edit "$KEY" --set-parent "$PARENT_KEY" >/dev/null 2>&1; then
  echo "gh issue edit --set-parent failed on #$KEY -> #$PARENT_KEY (gh too old for sub-issues? auth? numbers?)" >&2
  exit 3
fi
