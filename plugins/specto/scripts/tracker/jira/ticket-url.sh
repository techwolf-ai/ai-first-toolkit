#!/usr/bin/env bash
# Print the canonical browse URL for a Jira work item:
#   https://<site>/browse/<KEY>
#
# The site is never hardcoded: JIRA_SITE env var wins, then the `jira_site`
# config key (repo .specto/config.yml, then plugin-config machine default).
# Skills/templates call this instead of baking a tenant URL into prose.
#
# Usage:
#   ticket-url.sh <KEY>
#
# Output: the URL on stdout, newline-terminated.
# Exit:
#   0 — URL printed
#   2 — bad usage
#   3 — no site configured (guidance on stderr)

set -u
set -o pipefail

usage() {
  echo "usage: ticket-url.sh <KEY>" >&2
  exit 2
}

[[ $# -ne 1 ]] && usage
KEY="$1"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../lib/config.sh"

SITE="${JIRA_SITE:-}"
[[ -z "$SITE" ]] && SITE="$(specto_config_get jira_site)"
if [[ -z "$SITE" ]]; then
  echo "specto: no Jira site configured. Set JIRA_SITE, or 'jira_site' via .specto/config.yml / scripts/plugin-config.sh set jira_site <host>." >&2
  exit 3
fi
SITE="${SITE#https://}"; SITE="${SITE%/}"
printf 'https://%s/browse/%s\n' "$SITE" "$KEY"
