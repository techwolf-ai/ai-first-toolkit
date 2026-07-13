#!/usr/bin/env bash
# Add a Jira work item to a sprint via the Jira Agile REST API.
#
# Why a dedicated helper instead of the `create-ticket.sh --sprint-id` path:
# the `acli jira workitem edit --from-json` follow-up that `create-ticket.sh`
# emits for `additionalAttributes` fails on several `acli` versions with
# `if any flags in the group [key jql filter generate-json from-json] are set
# none of the others can be` (`acli` rejects combining `--key` with
# `--from-json`). The result is a silent backlog drop — the ticket is
# created, the warning is logged, but the sprint placement never lands.
# Several tickets hit this in practice (silent backlog drops). The Agile
# REST endpoint (`POST /rest/agile/1.0/sprint/<id>/issue`) bypasses `acli`
# entirely and is the canonical sprint-add path Jira's own UI uses.
#
# Auth: the Jira REST API needs the user's email + API token. Both come from
# the same two env vars — JIRA_EMAIL and JIRA_API_TOKEN. Each value may be
# either a literal (e.g. you@example.com / your-api-token) OR a 1Password
# secret reference of the form `op://<vault>/<item>/<field>`, in which case
# the helper resolves it via `op read` (requires the 1Password CLI on PATH).
# This matches the standard 1Password pattern used by `op inject` / `op run`:
# one env var per secret. acli's own stored config is not extracted (acli does
# not expose its token to other tools).
# JIRA_SITE resolution: env var > tenant profile (.specto/tracker-jira.yml
# `site`) > plugin-config `jira_site` > exit 3 with setup guidance.
#
# Usage:
#   add-to-sprint.sh <SPRINT_ID> <KEY>                       # live REST API
#   add-to-sprint.sh <SPRINT_ID> <KEY> --from-fixture <path> # test
#   add-to-sprint.sh <KEY>                                   # legacy stub form
#                                                            # (one-arg) preserved
#                                                            # for backwards compat
#
# Fixture file shape (test mode only):
#   {"status": "ok"}                       # success
#   {"status": "error", "error": "..."}    # simulated failure
# OR the legacy active-sprint fixture shape, for backwards compat with
# active-sprint.sh's fixtures:
#   {"board_id": 12, "active_sprint": {"id": 34, "name": "Sprint 7"}}
#   {"board_id": 12, "active_sprint": null}      # no active sprint -> no-op
#
# Output: nothing on stdout; warnings to stderr.
# Exit:
#   0 — added (or fixture says success, or no-op)
#   2 — bad usage
#   3 — REST API call failed, OR auth env vars missing

set -u
set -o pipefail

usage() {
  echo "usage: add-to-sprint.sh <SPRINT_ID> <KEY> [--from-fixture <path>]" >&2
  echo "       add-to-sprint.sh <KEY> [--from-fixture <path>]    # legacy one-arg form (no sprint id resolution)" >&2
  exit 2
}

[[ $# -lt 1 ]] && usage

# Disambiguate the two usage forms. The new two-positional form takes
# <SPRINT_ID> <KEY>; the legacy one-positional form takes <KEY> only. We tell
# them apart by checking if the second positional looks like a Jira key
# (PROJ-NNN).
SPRINT_ID=""
KEY=""
if [[ $# -ge 2 && "$2" =~ ^[A-Z][A-Z0-9]+-[0-9]+$ ]]; then
  SPRINT_ID="$1"
  KEY="$2"
  shift 2
else
  KEY="$1"
  shift
fi

FIXTURE=""
if [[ $# -gt 0 ]]; then
  if [[ "$1" == "--from-fixture" && $# -ge 2 ]]; then
    FIXTURE="$2"
    shift 2
  else
    usage
  fi
fi

# Fixture mode: handle both the new {"status": ...} shape and the legacy
# active-sprint fixture shape ({"board_id", "active_sprint"}).
if [[ -n "$FIXTURE" ]]; then
  [[ -f "$FIXTURE" ]] || { echo "fixture not found: $FIXTURE" >&2; exit 3; }
  data="$(cat "$FIXTURE")"
  echo "$data" | jq . >/dev/null 2>&1 || { echo "fixture JSON unparseable: $FIXTURE" >&2; exit 3; }
  status="$(echo "$data" | jq -r '.status // empty')"
  if [[ -n "$status" ]]; then
    case "$status" in
      ok)    exit 0 ;;
      error) echo "fixture: $(echo "$data" | jq -r '.error // "REST API failed"')" >&2; exit 3 ;;
      *)     echo "fixture: unknown status: $status" >&2; exit 3 ;;
    esac
  fi
  # Legacy shape: active-sprint fixture. Treat absent active_sprint as no-op.
  active="$(echo "$data" | jq -r '.active_sprint // empty')"
  if [[ -z "$active" || "$active" == "null" ]]; then
    echo "no active sprint for $KEY's board (fixture); no-op" >&2
    exit 0
  fi
  echo "would add $KEY to active sprint $(echo "$data" | jq -r '.active_sprint.name // .active_sprint.id')" >&2
  exit 0
fi

# Legacy one-arg form had no way to know the sprint id and exited 0 with a
# stub warning. Preserve that behaviour so older callers don't break.
if [[ -z "$SPRINT_ID" ]]; then
  echo "add-to-sprint.sh: called without a SPRINT_ID — cannot place $KEY. Pass <SPRINT_ID> <KEY>." >&2
  exit 0
fi

# ---- live mode: Jira Agile REST API ----
if [[ -z "${JIRA_SITE:-}" ]]; then
  HERE_CFG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  . "$HERE_CFG/../../lib/config.sh"
  repo="$(specto_repo_dir)"
  [[ -n "$repo" && -f "$repo/.specto/tracker-jira.yml" ]] && JIRA_SITE="$(specto_yaml_get "$repo/.specto/tracker-jira.yml" site)"
  [[ -z "${JIRA_SITE:-}" ]] && JIRA_SITE="$("$HERE_CFG/../../plugin-config.sh" get jira_site 2>/dev/null || true)"
fi
if [[ -z "${JIRA_SITE:-}" ]]; then
  echo "no Jira site configured. Set JIRA_SITE, or 'site' in .specto/tracker-jira.yml, or scripts/plugin-config.sh set jira_site <host>. Run /specto:setup for guided config." >&2
  exit 3
fi

# Resolve email + token. Each var may hold a literal value or an `op://...`
# 1Password reference — in the latter case, we shell out to `op read`.
EMAIL="${JIRA_EMAIL:-}"
TOKEN="${JIRA_API_TOKEN:-}"
if [[ "$EMAIL" == op://* ]]; then
  if command -v op >/dev/null; then
    EMAIL="$(op read "$EMAIL" 2>/dev/null || true)"
  else
    echo "add-to-sprint.sh: JIRA_EMAIL is an op:// reference but the 1Password CLI (\`op\`) is not on PATH." >&2
    EMAIL=""
  fi
fi
if [[ "$TOKEN" == op://* ]]; then
  if command -v op >/dev/null; then
    TOKEN="$(op read "$TOKEN" 2>/dev/null || true)"
  else
    echo "add-to-sprint.sh: JIRA_API_TOKEN is an op:// reference but the 1Password CLI (\`op\`) is not on PATH." >&2
    TOKEN=""
  fi
fi

if [[ -z "$EMAIL" || -z "$TOKEN" ]]; then
  cat >&2 <<EOF
add-to-sprint.sh: cannot place $KEY in sprint $SPRINT_ID — auth missing.
Set JIRA_EMAIL and JIRA_API_TOKEN. Each may be a literal value or an
op://<vault>/<item>/<field> 1Password reference (requires the \`op\` CLI).
Get an API token at https://id.atlassian.com/manage-profile/security/api-tokens
Drag $KEY to the sprint manually at
https://${JIRA_SITE}/jira/software/projects/$(echo "$KEY" | cut -d- -f1)/boards
EOF
  exit 3
fi

if ! command -v curl >/dev/null; then
  echo "curl not on PATH; cannot call Jira REST API" >&2
  exit 3
fi

resp_body="$(mktemp -t specto-sprint-resp.XXXXXX)"
trap 'rm -f "$resp_body"' EXIT
http_code="$(curl -sS -w '%{http_code}' -o "$resp_body" \
  -u "${EMAIL}:${TOKEN}" \
  -X POST \
  -H 'Content-Type: application/json' \
  --data "$(jq -nc --arg k "$KEY" '{issues: [$k]}')" \
  "https://${JIRA_SITE}/rest/agile/1.0/sprint/${SPRINT_ID}/issue" 2>/dev/null || true)"

case "$http_code" in
  20[0-9])
    exit 0
    ;;
  401|403)
    echo "add-to-sprint.sh: auth rejected by Jira (HTTP $http_code) — verify JIRA_EMAIL + JIRA_API_TOKEN." >&2
    exit 3
    ;;
  404)
    echo "add-to-sprint.sh: sprint $SPRINT_ID or issue $KEY not found (HTTP 404). Drag $KEY to the sprint manually." >&2
    exit 3
    ;;
  *)
    body_excerpt="$(head -c 200 "$resp_body" 2>/dev/null || true)"
    echo "add-to-sprint.sh: Jira REST returned HTTP $http_code adding $KEY to sprint $SPRINT_ID. Body: ${body_excerpt}" >&2
    exit 3
    ;;
esac
