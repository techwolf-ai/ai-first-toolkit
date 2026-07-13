#!/usr/bin/env bash
# Read a Linear issue's description and emit it as Markdown on stdout. Linear
# descriptions ARE markdown, so this is a pure passthrough; there is no ADF
# (or any other rich-format) conversion on this backend. Mirrors the jira
# counterpart's argv and its exit contract.
#
# Usage:
#   get-ticket-description.sh <KEY>                       # live
#   get-ticket-description.sh <KEY> --from-fixture <path> # test: canned response
#
# --from-fixture <path>: the raw GraphQL response:
#   {"data":{"issue":{"description":"markdown body ..."}}}
#
# Output: Markdown on stdout. Warnings/errors to stderr.
# Exit:
#   0 - description printed
#   1 - the issue key did not resolve, or the description is empty/absent
#   2 - bad usage
#   3 - auth/transport failure

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GQL="$HERE/_gql.sh"

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

Q='query($id: String!) { issue(id: $id) { description } }'
if [[ -n "$FIXTURE" ]]; then
  DATA="$(bash "$GQL" --from-fixture "$FIXTURE" "$Q" '{}')" || exit $?
else
  DATA="$(bash "$GQL" "$Q" "$(jq -nc --arg id "$KEY" '{id: $id}')")" || exit $?
fi

DESC="$(printf '%s' "$DATA" | jq -r '.issue.description // empty')"
if [[ -z "$DESC" ]]; then
  echo "no description on $KEY (empty ticket body)" >&2
  exit 1
fi
printf '%s\n' "$DESC"
