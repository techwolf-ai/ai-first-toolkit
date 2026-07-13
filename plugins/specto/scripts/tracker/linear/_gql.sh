#!/usr/bin/env bash
# The single GraphQL transport for the Linear tracker backend. Every verb in
# this directory is a thin query/mutation over this helper; no verb talks to
# curl (or any network endpoint) directly.
#
# Auth: LINEAR_API_KEY, which may be either a literal personal API key or a
# 1Password secret reference of the form `op://<vault>/<item>/<field>` (in
# which case it is resolved via `op read`, requiring the 1Password CLI on
# PATH). Linear personal keys go in the `Authorization: <key>` header, bare
# (no "Bearer" prefix).
#
# ps-leakage guard: the API key is NEVER placed on curl's argv. The auth
# header is written to a mode-0600 temp file passed via `curl -K <file>`, and
# the request body travels on stdin (`--data @-`). The test suite asserts the
# key is absent from curl's argv.
#
# Endpoint: https://api.linear.app/graphql, overridable via
# SPECTO_LINEAR_ENDPOINT (the offline test harness points it at a mock).
#
# Usage:
#   _gql.sh <query> [<variables-json>]                        # live POST
#   _gql.sh --from-fixture <file> <query> [<variables-json>]  # canned response
#
# <variables-json> defaults to {}. The fixture file is a raw GraphQL response
# ({"data": ...} and/or {"errors": [...]}), i.e. backend-shaped, exactly what
# the live endpoint would return.
#
# Output: the response's `.data` object on stdout. GraphQL errors[] messages
# go to stderr.
# Exit:
#   0 - .data returned
#   1 - fixture/response JSON unparseable
#   2 - bad usage (no query, or variables not valid JSON)
#   3 - auth missing, curl not on PATH, transport failure, or errors[] present

set -u
set -o pipefail

usage() {
  echo "usage: _gql.sh [--from-fixture <file>] <query> [<variables-json>]" >&2
  exit 2
}

FIXTURE=""
QUERY=""
VARS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from-fixture) [[ $# -ge 2 ]] || usage; FIXTURE="$2"; shift 2 ;;
    -*)             usage ;;
    *)
      if [[ -z "$QUERY" ]]; then QUERY="$1"
      elif [[ -z "$VARS" ]]; then VARS="$1"
      else usage
      fi
      shift ;;
  esac
done
[[ -n "$QUERY" ]] || usage
[[ -z "$VARS" ]] && VARS='{}'
printf '%s' "$VARS" | jq -e . >/dev/null 2>&1 || { echo "variables are not valid JSON" >&2; exit 2; }

if [[ -n "$FIXTURE" ]]; then
  [[ -f "$FIXTURE" ]] || { echo "fixture not found: $FIXTURE" >&2; exit 3; }
  RESP="$(cat "$FIXTURE")"
  printf '%s' "$RESP" | jq -e . >/dev/null 2>&1 || { echo "fixture JSON unparseable: $FIXTURE" >&2; exit 1; }
else
  # ---- live mode ----
  KEY="${LINEAR_API_KEY:-}"
  if [[ "$KEY" == op://* ]]; then
    if command -v op >/dev/null; then
      KEY="$(op read "$KEY" 2>/dev/null || true)"
    else
      echo "LINEAR_API_KEY is an op:// reference but the 1Password CLI (op) is not on PATH" >&2
      KEY=""
    fi
  fi
  if [[ -z "$KEY" ]]; then
    echo "LINEAR_API_KEY not set. Export a Linear personal API key (or an op://<vault>/<item>/<field> reference)." >&2
    exit 3
  fi
  command -v curl >/dev/null || { echo "curl not on PATH" >&2; exit 3; }

  ENDPOINT="${SPECTO_LINEAR_ENDPOINT:-https://api.linear.app/graphql}"
  BODY="$(jq -nc --arg q "$QUERY" --argjson v "$VARS" '{query: $q, variables: $v}')"

  # Auth header via a 0600 curl config file: keeps the key off argv (ps-visible)
  # while the body rides stdin.
  HDR="$(umask 077 && mktemp -t specto-gql.XXXXXX)"
  trap 'rm -f "$HDR"' EXIT
  {
    printf 'header = "Authorization: %s"\n' "$KEY"
    printf 'header = "Content-Type: application/json"\n'
  } > "$HDR"

  RESP="$(printf '%s' "$BODY" | curl -sS --max-time 60 -K "$HDR" -X POST --data @- "$ENDPOINT" 2>/dev/null)" || {
    echo "Linear API request failed (network? endpoint ${ENDPOINT}?)" >&2
    exit 3
  }
  printf '%s' "$RESP" | jq -e . >/dev/null 2>&1 || {
    echo "Linear API returned an unparseable response (auth? endpoint?)" >&2
    exit 3
  }
fi

# GraphQL-level errors: surface every message, exit 3 (external-call failure).
if printf '%s' "$RESP" | jq -e '(.errors // []) | length > 0' >/dev/null 2>&1; then
  printf '%s' "$RESP" | jq -r '.errors[] | "linear API error: \(.message // "unknown error")"' >&2
  exit 3
fi

DATA="$(printf '%s' "$RESP" | jq -e '.data' 2>/dev/null)" || {
  echo "no .data in Linear API response" >&2
  exit 3
}
printf '%s\n' "$DATA"
