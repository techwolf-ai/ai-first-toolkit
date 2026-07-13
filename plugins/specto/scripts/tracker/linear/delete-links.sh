#!/usr/bin/env bash
# Delete issue relations across one or more Linear issues; the inverse of
# link-tickets.sh. Collects every relation id on the given issues in BOTH
# directions (relations + inverseRelations, de-duped: a relation is one row
# shared by both endpoints) and deletes each via issueRelationDelete. Mirrors
# the jira counterpart's argv.
#
# Usage:
#   delete-links.sh <KEY> [<KEY>...] [--type <Name>] [--dry-run]
#   delete-links.sh <KEY> [<KEY>...] --from-fixture <relations.json>  # test (no deletes)
#
#   --type <Name>   only delete relations of this type; canonical names map
#                   (blocks->blocks, relates/related->related,
#                   duplicate/duplicates->duplicate); other values are used
#                   verbatim (lowercased) and simply match nothing
#   --dry-run       print the relation ids that would be deleted; delete nothing
#   --from-fixture  the raw GraphQL relations-query response for ONE issue:
#                   {"data":{"issue":{"relations":{"nodes":[{"id":..,"type":..}]},
#                                     "inverseRelations":{"nodes":[...]}}}}
#                   lists the de-duped candidate ids; no network, no deletes
#
# Output: the deleted (or, with --dry-run/--from-fixture, the candidate)
#   relation ids, one per line, on stdout; warnings/errors to stderr.
# Exit:
#   0 - relations deleted (or dry-run/fixture listed)
#   2 - bad usage
#   3 - auth/transport failure, or a delete call failed

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GQL="$HERE/_gql.sh"

usage() {
  echo "usage: delete-links.sh <KEY> [<KEY>...] [--type <Name>] [--dry-run] [--from-fixture <path>]" >&2
  exit 2
}

KEYS=()
TYPE=""
DRY_RUN=0
FIXTURE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --type)         [[ $# -ge 2 ]] || usage; TYPE="$2"; shift 2 ;;
    --dry-run)      DRY_RUN=1; shift ;;
    --from-fixture) [[ $# -ge 2 ]] || usage; FIXTURE="$2"; shift 2 ;;
    -*)             usage ;;
    *)              KEYS+=("$1"); shift ;;
  esac
done

[[ ${#KEYS[@]} -ge 1 ]] || usage

# Map the canonical/jira type names onto Linear's enum; unknown names pass
# through lowercased (they filter to nothing, which is harmless).
LTYPE=""
if [[ -n "$TYPE" ]]; then
  case "$(printf '%s' "$TYPE" | tr '[:upper:]' '[:lower:]')" in
    blocks)               LTYPE="blocks" ;;
    relates|related)      LTYPE="related" ;;
    duplicate|duplicates) LTYPE="duplicate" ;;
    *)                    LTYPE="$(printf '%s' "$TYPE" | tr '[:upper:]' '[:lower:]')" ;;
  esac
fi

# Extract relation ids from a relations-query .data document, optionally
# filtered by type; covers both directions.
jq_ids() {
  if [[ -n "$LTYPE" ]]; then
    jq -r --arg t "$LTYPE" '
      (.issue.relations.nodes[]?, .issue.inverseRelations.nodes[]?)
      | select(.type == $t) | .id'
  else
    jq -r '(.issue.relations.nodes[]?, .issue.inverseRelations.nodes[]?) | .id'
  fi
}

RELS_Q='query($id: String!) { issue(id: $id) { relations { nodes { id type } } inverseRelations { nodes { id type } } } }'

# Fixture mode: read relations from the file (via _gql), list de-duped ids, exit.
if [[ -n "$FIXTURE" ]]; then
  DATA="$(bash "$GQL" --from-fixture "$FIXTURE" "$RELS_Q" '{}')" || exit $?
  printf '%s' "$DATA" | jq_ids | sort -u
  exit 0
fi

gql() { bash "$GQL" "$1" "$2"; }

# Collect every relation id across all keys, de-duped via sort -u (a relation
# appears on both endpoints).
collect() {
  local k data
  for k in "${KEYS[@]}"; do
    data="$(gql "$RELS_Q" "$(jq -nc --arg id "$k" '{id: $id}')")" \
      || { echo "warning: could not read relations for $k" >&2; continue; }
    printf '%s' "$data" | jq_ids
  done
}
all_ids="$(collect | sort -u)"

if [[ -z "$all_ids" ]]; then
  echo "no links to delete" >&2
  exit 0
fi

if [[ "$DRY_RUN" == "1" ]]; then
  printf '%s\n' "$all_ids"
  exit 0
fi

rc=0
while IFS= read -r id; do
  [[ -n "$id" ]] || continue
  DATA="$(gql 'mutation($id: String!) { issueRelationDelete(id: $id) { success } }' \
              "$(jq -nc --arg id "$id" '{id: $id}')")" \
    && [[ "$(printf '%s' "$DATA" | jq -r '.issueRelationDelete.success // false')" == "true" ]] \
    && echo "$id" \
    || { echo "warning: failed to delete relation $id" >&2; rc=3; }
done <<< "$all_ids"
exit $rc
