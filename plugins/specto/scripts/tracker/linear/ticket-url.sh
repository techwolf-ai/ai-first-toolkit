#!/usr/bin/env bash
# Print the canonical browse URL for a Linear issue. Linear embeds the
# workspace slug in issue.url, so the URL is read from the API rather than
# assembled from config (no tenant hardcoding, and no extra config key).
#
# Usage:
#   ticket-url.sh <KEY>                       # live
#   ticket-url.sh <KEY> --from-fixture <path> # test: canned response
#
# (The jira counterpart needs no fixture flag because it builds the URL from
# config offline; this one performs a read, so it carries the standard
# --from-fixture mode. Callers passing just <KEY> are unaffected.)
#
# --from-fixture <path>: the raw GraphQL response:
#   {"data":{"issue":{"url":"https://linear.app/acme/issue/ENG-123/..."}}}
#
# Output: the URL on stdout, newline-terminated.
# Exit:
#   0 - URL printed
#   1 - the issue key did not resolve, or no url in the response
#   2 - bad usage
#   3 - auth/transport failure

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GQL="$HERE/_gql.sh"

usage() {
  echo "usage: ticket-url.sh <KEY> [--from-fixture <path>]" >&2
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
[[ $# -gt 0 ]] && usage

Q='query($id: String!) { issue(id: $id) { url } }'
if [[ -n "$FIXTURE" ]]; then
  DATA="$(bash "$GQL" --from-fixture "$FIXTURE" "$Q" '{}')" || exit $?
else
  DATA="$(bash "$GQL" "$Q" "$(jq -nc --arg id "$KEY" '{id: $id}')")" || exit $?
fi

URL="$(printf '%s' "$DATA" | jq -r '.issue.url // empty')"
[[ -n "$URL" ]] || { echo "no url for $KEY" >&2; exit 1; }
printf '%s\n' "$URL"
