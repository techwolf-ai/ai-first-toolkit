#!/usr/bin/env bash
# Read a GitHub issue's description (body) and print it as Markdown on stdout.
# GitHub bodies ARE markdown, so this is a pure passthrough: no ADF walk, no
# conversion, byte-for-byte what the issue carries. Used by implement-ticket to
# read the ticket body + acceptance criteria + spec link.
#
# Usage (identical to the jira counterpart):
#   get-ticket-description.sh <KEY>                       # live: calls gh
#   get-ticket-description.sh <KEY> --from-fixture <path> # test: reads a JSON file
#
# Fixture / gh JSON shape: `gh issue view <n> --json body`, i.e. {"body": "..."}.
#
# Output: Markdown on stdout. Warnings/errors to stderr.
# Exit:
#   0 - body printed
#   1 - JSON unparseable, or the body is empty (empty ticket body)
#   2 - bad usage
#   3 - gh not on PATH, or the gh call failed

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/_lib.sh"

usage() {
  echo "usage: get-ticket-description.sh <KEY> [--from-fixture <path>]" >&2
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
  JSON="$(gh issue view "$KEY" --json body 2>/dev/null)" || {
    echo "gh issue view failed for #$KEY (auth? number?)" >&2
    exit 3
  }
fi

echo "$JSON" | jq . >/dev/null 2>&1 || { echo "JSON unparseable for #$KEY" >&2; exit 1; }

BODY="$(echo "$JSON" | jq -r '.body // empty')"
if [[ -z "${BODY//[[:space:]]/}" ]]; then
  echo "no description on #$KEY (empty ticket body)" >&2
  exit 1
fi
printf '%s\n' "$BODY"
