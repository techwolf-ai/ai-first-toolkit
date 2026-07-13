#!/usr/bin/env bash
# Persistent key-value config for the specto plugin. Stores user-specific
# defaults (Jira project, board id, GitLab user) so skills don't have to ask
# the user repeatedly. Config survives plugin updates.
#
# Storage location:
#   $CLAUDE_PLUGIN_DATA/config.env   (set by Claude Code when the plugin runs)
#   ~/.claude/plugin-data/specto/config.env   (fallback for direct invocations)
#
# Known keys (just convention; the helper itself doesn't validate keys):
#   jira_project    - default Jira project key (e.g. APP, PROJ)
#   jira_board_id   - default Jira board id (used by active-sprint.sh)
#   gitlab_user     - cached GitLab username (used when @me doesn't resolve)
#
# Usage:
#   plugin-config.sh get <key>            # print value; exit 1 if unset
#   plugin-config.sh set <key> <value>    # store; overwrites existing
#   plugin-config.sh has <key>            # exit 0 if set, 1 if not; no output
#   plugin-config.sh list                 # print all `key=value` lines
#   plugin-config.sh delete <key>         # remove a key (no-op if absent)
#
# Output: per-action (above). Warnings/errors to stderr.
# Exit:
#   0 — success (or `has` says yes)
#   1 — `get` for an unset key, or `has` says no
#   2 — bad usage

set -u
set -o pipefail

usage() {
  echo "usage: plugin-config.sh <get|set|has|list|delete> <key> [value]" >&2
  exit 2
}

[[ $# -lt 1 ]] && usage
ACTION="$1"
KEY="${2:-}"
VALUE="${3:-}"

CONFIG_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugin-data/specto}"
CONFIG_FILE="$CONFIG_DIR/config.env"

mkdir -p "$CONFIG_DIR"
touch "$CONFIG_FILE"

# All reads/writes match `key=…` exactly via awk field comparison, so a key
# containing regex metacharacters (`.`, `[`, `*`, `^`, `$`, `\`) can never
# match a different key by accident. Previous versions used `grep "^${KEY}="`
# which silently matched / dropped wrong lines on dotted or bracketed keys.
case "$ACTION" in
  get)
    [[ -n "$KEY" ]] || usage
    value="$(awk -F= -v k="$KEY" '$1 == k { sub(/^[^=]*=/, ""); v=$0 } END { if (v != "") print v }' "$CONFIG_FILE")"
    [[ -n "$value" ]] || exit 1
    printf '%s\n' "$value"
    ;;
  set)
    [[ -n "$KEY" && -n "$VALUE" ]] || usage
    tmp="$(mktemp -t specto-config.XXXXXX)"
    awk -F= -v k="$KEY" '$1 != k' "$CONFIG_FILE" > "$tmp"
    printf '%s=%s\n' "$KEY" "$VALUE" >> "$tmp"
    mv "$tmp" "$CONFIG_FILE"
    ;;
  has)
    [[ -n "$KEY" ]] || usage
    awk -F= -v k="$KEY" 'BEGIN { rc=1 } $1 == k { rc=0 } END { exit rc }' "$CONFIG_FILE"
    ;;
  list)
    cat "$CONFIG_FILE" 2>/dev/null || true
    ;;
  delete)
    [[ -n "$KEY" ]] || usage
    tmp="$(mktemp -t specto-config.XXXXXX)"
    awk -F= -v k="$KEY" '$1 != k' "$CONFIG_FILE" > "$tmp"
    mv "$tmp" "$CONFIG_FILE"
    ;;
  *)
    usage
    ;;
esac
