#!/usr/bin/env bash
# Read a GitHub issue's parent (sub-issue) number. Prints `<PARENT>\tparent`
# for a native parent; nothing when the issue has no parent. The jira
# backend's Relates-link fallback has no equivalent here (github has no
# relates concept), so the second column is always `parent`.
#
# Usage (identical to the jira counterpart):
#   get-ticket-parent.sh <KEY>                       # live: calls gh
#   get-ticket-parent.sh <KEY> --from-fixture <path> # test: reads a JSON file
#
# Fixture / gh JSON shape: `gh issue view <n> --json parent`, i.e.
#   {"parent": {"number": 100, ...}}  or  {"parent": null}
#
# Output: `<PARENT>\tparent` on stdout, newline-terminated (nothing if no
# parent). Warnings/errors to stderr.
# Exit:
#   0 - parent printed, OR no parent (clean exit, empty stdout)
#   1 - JSON unparseable
#   2 - bad usage
#   3 - gh not on PATH, or the gh call failed

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/_lib.sh"

usage() {
  echo "usage: get-ticket-parent.sh <KEY> [--from-fixture <path>]" >&2
  exit 2
}

[[ $# -lt 1 ]] && usage
KEY="$1"
shift

FIXTURE=""
if [[ $# -gt 0 ]]; then
  if [[ "$1" == "--from-fixture" && $# -ge 2 ]]; then
    FIXTURE="$2"
    shift 2
  else
    usage
  fi
fi

if [[ -n "$FIXTURE" ]]; then
  [[ -f "$FIXTURE" ]] || { echo "fixture not found: $FIXTURE" >&2; exit 3; }
  JSON="$(cat "$FIXTURE")"
else
  specto_require_gh
  JSON="$(gh issue view "$KEY" --json parent 2>/dev/null)" || {
    echo "gh issue view failed for #$KEY (auth? number?)" >&2
    exit 3
  }
fi

echo "$JSON" | jq . >/dev/null 2>&1 || { echo "JSON unparseable for #$KEY" >&2; exit 1; }

PARENT="$(echo "$JSON" | jq -r '.parent.number // empty')"
if [[ -n "$PARENT" ]]; then
  printf '%s\tparent\n' "$PARENT"
fi
exit 0
