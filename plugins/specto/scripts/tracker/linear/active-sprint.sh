#!/usr/bin/env bash
# Resolve the active cycle(s) for a Linear team (sprints map 1:1 onto Linear
# cycles). Pairs with create-ticket.sh's --sprint-id flag: the caller fetches
# the active cycle here, then places a new issue into it. Mirrors the jira
# counterpart's argv; the positional is the LINEAR TEAM KEY where jira takes a
# board id. Pass "-" to fall back to config (`project`, then `linear_team`).
#
# Linear teams normally run one cycle at a time, but cooldown overlaps can
# surface more than one active cycle; all are emitted, one per line.
#
# Usage:
#   active-sprint.sh <team-key>                       # live
#   active-sprint.sh <team-key> --from-fixture <path> # test: canned response
#
# --from-fixture <path>: the raw GraphQL response:
#   {"data":{"teams":{"nodes":[{"id":..,"key":..,"cycles":{"nodes":[{"id":..,"name":..,"number":..}]}}]}}}
#
# Output: one TAB-separated `<id>\t<name>` per active cycle on stdout (a
# nameless cycle renders as "Cycle <number>"); nothing if no active cycle.
# Exit:
#   0 - fetched (zero or more active cycles; the empty case is NOT an error,
#       it just means "no active cycle, issue goes to backlog")
#   1 - no team with the given key
#   2 - bad usage
#   3 - auth/transport failure, or no team key configured for "-"

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GQL="$HERE/_gql.sh"

usage() {
  echo "usage: active-sprint.sh <team-key> [--from-fixture <path>]" >&2
  exit 2
}

[[ $# -lt 1 ]] && usage
TEAM_KEY="$1"
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

Q='query($key: String!) { teams(filter: {key: {eq: $key}}) { nodes { id key cycles(filter: {isActive: {eq: true}}) { nodes { id name number } } } } }'
if [[ -n "$FIXTURE" ]]; then
  DATA="$(bash "$GQL" --from-fixture "$FIXTURE" "$Q" '{}')" || exit $?
else
  # "-" falls back to config, same chain as create-ticket.sh.
  if [[ "$TEAM_KEY" == "-" ]]; then
    . "$HERE/../../lib/config.sh"
    TEAM_KEY="$(specto_config_get project)"
    [[ -z "$TEAM_KEY" ]] && TEAM_KEY="$(specto_config_get linear_team)"
    if [[ -z "$TEAM_KEY" ]]; then
      echo "specto: no Linear team configured. Pass the team key positionally, or set 'project' in .specto/config.yml / 'linear_team' via scripts/plugin-config.sh." >&2
      exit 3
    fi
  fi
  DATA="$(bash "$GQL" "$Q" "$(jq -nc --arg key "$TEAM_KEY" '{key: $key}')")" || exit $?
fi

printf '%s' "$DATA" | jq -e '.teams.nodes[0]' >/dev/null 2>&1 || {
  echo "no Linear team with key '$TEAM_KEY'" >&2
  exit 1
}

printf '%s' "$DATA" | jq -r '
  .teams.nodes[0].cycles.nodes[]?
  | "\(.id)\t\(.name // ("Cycle " + ((.number // 0) | tostring)))"
'
