#!/usr/bin/env bash
# Create a relation between two Linear issues via issueRelationCreate. Used by
# create-ticket.sh and standalone. Mirrors the jira counterpart's argv.
#
# The link reads as: "<from-KEY> <link-type> <to-KEY>".
#   link-tickets.sh blocks  ENG-100 ENG-200  ->  "ENG-100 blocks ENG-200"
#   link-tickets.sh relates ENG-100 ENG-200  ->  "ENG-100 relates to ENG-200"
#
# Linear supports exactly three relation types; the canonical specto names map
# case-insensitively:
#   blocks / Blocks               -> blocks
#   relates / Relates / related   -> related
#   duplicate / duplicates        -> duplicate
# Any other type name exits 4 (Linear has no custom link types).
#
# After a live create, the stored direction is self-verified by re-reading the
# subject's relations (same defensive read-back the jira impl does): the FROM
# issue must carry an outgoing relation of this type to TO.
#
# Usage:
#   link-tickets.sh <link-type> <from-KEY> <to-KEY>
#   link-tickets.sh <link-type> <from-KEY> <to-KEY> --from-fixture <path>
#
# --from-fixture <path>: the fixture is the raw GraphQL issueRelationCreate
#   response; issue-id resolution and the read-back verify are live-only.
#
# Output: nothing on stdout on success; warnings/errors to stderr.
# Exit:
#   0 - relation created (or fixture says success)
#   1 - an issue key did not resolve
#   2 - bad usage
#   3 - auth/transport failure, create failed, or the relation stored in the
#       wrong direction
#   4 - link type not supported on Linear

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GQL="$HERE/_gql.sh"

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

case "$(printf '%s' "$LINK_TYPE" | tr '[:upper:]' '[:lower:]')" in
  blocks)                 LTYPE="blocks" ;;
  relates|related)        LTYPE="related" ;;
  duplicate|duplicates)   LTYPE="duplicate" ;;
  *)
    echo "not supported on linear: link type '$LINK_TYPE' (Linear relations are blocks/related/duplicate)" >&2
    exit 4
    ;;
esac

if [[ -n "$FIXTURE" ]]; then
  DATA="$(bash "$GQL" --from-fixture "$FIXTURE" 'mutation' '{}')" || exit $?
  [[ "$(printf '%s' "$DATA" | jq -r '.issueRelationCreate.success // false')" == "true" ]] || {
    echo "fixture: issueRelationCreate success=false" >&2
    exit 3
  }
  exit 0
fi

gql() { bash "$GQL" "$1" "$2"; }

resolve_issue_id() {
  local key="$1" data id
  data="$(gql 'query($id: String!) { issue(id: $id) { id } }' "$(jq -nc --arg id "$key" '{id: $id}')")" || return 3
  id="$(printf '%s' "$data" | jq -r '.issue.id // empty')"
  [[ -n "$id" ]] || { echo "issue not found: $key" >&2; return 1; }
  printf '%s' "$id"
}

FROM_ID="$(resolve_issue_id "$FROM_KEY")" || exit $?
TO_ID="$(resolve_issue_id "$TO_KEY")" || exit $?

DATA="$(gql 'mutation($input: IssueRelationCreateInput!) { issueRelationCreate(input: $input) { success issueRelation { id } } }' \
            "$(jq -nc --arg issueId "$FROM_ID" --arg relatedIssueId "$TO_ID" --arg type "$LTYPE" \
               '{input: {issueId: $issueId, relatedIssueId: $relatedIssueId, type: $type}}')")" || {
  echo "issueRelationCreate failed: $FROM_KEY $LINK_TYPE $TO_KEY (auth? keys?)" >&2
  exit 3
}
[[ "$(printf '%s' "$DATA" | jq -r '.issueRelationCreate.success // false')" == "true" ]] || {
  echo "issueRelationCreate reported success=false: $FROM_KEY $LINK_TYPE $TO_KEY" >&2
  exit 3
}

# Self-verify the stored direction: the FROM issue must now carry an OUTGOING
# relation of this type whose relatedIssue is TO. Best-effort on the read
# itself (a fetch failure warns but does not fail: the create succeeded), but
# a readable-and-reversed store is a hard error, mirroring the jira impl.
VERIFY="$(gql 'query($id: String!) { issue(id: $id) { relations { nodes { type relatedIssue { identifier } } } } }' \
              "$(jq -nc --arg id "$FROM_KEY" '{id: $id}')" 2>/dev/null || true)"
if [[ -z "$VERIFY" ]]; then
  echo "warning: linked $FROM_KEY $LINK_TYPE $TO_KEY but could not verify direction (read-back failed)" >&2
elif ! printf '%s' "$VERIFY" | jq -e --arg t "$LTYPE" --arg to "$TO_KEY" '
    .issue.relations.nodes[]?
    | select(.type == $t)
    | select(.relatedIssue.identifier == $to)
  ' >/dev/null; then
  echo "ERROR: relation stored in the WRONG direction; expected \"$FROM_KEY $LINK_TYPE $TO_KEY\" (outgoing). Delete the reversed relation and retry." >&2
  exit 3
fi
