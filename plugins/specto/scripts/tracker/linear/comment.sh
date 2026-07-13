#!/usr/bin/env bash
# Post a comment on a Linear issue via commentCreate. Linear comments are
# markdown-native, so the body passes through untouched (no conversion step;
# ADF is a jira-internal detail). Mirrors the jira counterpart's argv.
#
# Usage:
#   comment.sh <KEY> <body-file|->                       # live
#   comment.sh <KEY> <body-file|-> --from-fixture <path> # test: canned response
#
# Body is read from a file, or from stdin when <body-file> is "-".
# --from-fixture <path>: the fixture is the raw GraphQL commentCreate response;
#   issue-id resolution is live-only.
#
# Output: nothing on stdout on success; warnings/errors to stderr.
# Exit:
#   0 - comment posted (or fixture says success)
#   1 - body empty / unreadable, or the issue key did not resolve
#   2 - bad usage
#   3 - auth/transport failure, or the mutation failed

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GQL="$HERE/_gql.sh"

usage() {
  echo "usage: comment.sh <KEY> <body-file|-> [--from-fixture <path>]" >&2
  exit 2
}

[[ $# -lt 2 ]] && usage
KEY="$1"
BODY_SRC="$2"
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

# Read the body (file or stdin).
if [[ "$BODY_SRC" == "-" ]]; then
  BODY="$(cat)"
else
  [[ -f "$BODY_SRC" ]] || { echo "body file not found: $BODY_SRC" >&2; exit 2; }
  BODY="$(cat "$BODY_SRC")"
fi
if [[ -z "${BODY//[[:space:]]/}" ]]; then
  echo "comment body is empty" >&2
  exit 1
fi

if [[ -n "$FIXTURE" ]]; then
  DATA="$(bash "$GQL" --from-fixture "$FIXTURE" 'mutation' '{}')" || exit $?
  [[ "$(printf '%s' "$DATA" | jq -r '.commentCreate.success // false')" == "true" ]] || {
    echo "fixture: commentCreate success=false" >&2
    exit 3
  }
  exit 0
fi

gql() { bash "$GQL" "$1" "$2"; }

DATA="$(gql 'query($id: String!) { issue(id: $id) { id } }' "$(jq -nc --arg id "$KEY" '{id: $id}')")" || exit $?
ISSUE_ID="$(printf '%s' "$DATA" | jq -r '.issue.id // empty')"
[[ -n "$ISSUE_ID" ]] || { echo "issue not found: $KEY" >&2; exit 1; }

DATA="$(gql 'mutation($input: CommentCreateInput!) { commentCreate(input: $input) { success } }' \
            "$(jq -nc --arg issueId "$ISSUE_ID" --arg body "$BODY" '{input: {issueId: $issueId, body: $body}}')")" || {
  echo "commentCreate failed on $KEY (auth? key?)" >&2
  exit 3
}
[[ "$(printf '%s' "$DATA" | jq -r '.commentCreate.success // false')" == "true" ]] || {
  echo "commentCreate reported success=false on $KEY" >&2
  exit 3
}
