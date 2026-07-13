#!/usr/bin/env bash
# Print the canonical browse URL for a GitHub issue. Nothing is configured or
# hardcoded: `gh issue view --json url` resolves the URL from the current repo
# checkout (or $GH_REPO when exported), so skills/templates call this instead
# of assembling a host/owner/repo URL by hand.
#
# Usage (identical to the jira counterpart):
#   ticket-url.sh <KEY>
#
# Output: the URL on stdout, newline-terminated.
# Exit:
#   0 - URL printed
#   1 - gh returned no URL for the issue
#   2 - bad usage
#   3 - gh not on PATH, or the gh call failed

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/_lib.sh"

usage() {
  echo "usage: ticket-url.sh <KEY>" >&2
  exit 2
}

[[ $# -ne 1 ]] && usage
KEY="$1"

specto_require_gh

JSON="$(gh issue view "$KEY" --json url 2>/dev/null)" || {
  echo "gh issue view failed for #$KEY (auth? number?)" >&2
  exit 3
}
URL="$(printf '%s' "$JSON" | jq -r '.url // empty' 2>/dev/null)"
[[ -n "$URL" ]] || { echo "no .url for #$KEY" >&2; exit 1; }
printf '%s\n' "$URL"
