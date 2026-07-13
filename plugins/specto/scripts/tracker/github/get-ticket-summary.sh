#!/usr/bin/env bash
# Read a GitHub issue's title and print it on stdout, the single vetted read
# path for "what is this ticket called?". get-ticket-description.sh covers the
# body; this helper covers the title.
#
# Usage (identical to the jira counterpart):
#   get-ticket-summary.sh <KEY>                       # live: calls gh
#   get-ticket-summary.sh <KEY> --from-fixture <path> # test: reads a JSON file
#
# Fixture / gh JSON shape: `gh issue view <n> --json title`, i.e. {"title": "..."}.
#
# Output: the title string on stdout, newline-terminated. Warnings/errors to stderr.
# Exit:
#   0 - title printed
#   1 - JSON unparseable, or no .title found
#   2 - bad usage
#   3 - gh not on PATH, or the gh call failed

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/_lib.sh"

usage() {
  echo "usage: get-ticket-summary.sh <KEY> [--from-fixture <path>]" >&2
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
  JSON="$(gh issue view "$KEY" --json title 2>/dev/null)" || {
    echo "gh issue view failed for #$KEY (auth? number?)" >&2
    exit 3
  }
fi

echo "$JSON" | jq . >/dev/null 2>&1 || { echo "JSON unparseable for #$KEY" >&2; exit 1; }
TITLE="$(echo "$JSON" | jq -r '.title // empty')"
[[ -n "$TITLE" ]] || { echo "no .title for #$KEY" >&2; exit 1; }
printf '%s\n' "$TITLE"
