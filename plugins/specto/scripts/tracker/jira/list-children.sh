#!/usr/bin/env bash
# List the child work items of an epic as a normalized JSON array:
#   [{"key": "ABC-12", "summary": "...", "status": "...", "type": "Task"}, …]
#
# Replaces the previous inline `acli jira workitem search --jql "parent = KEY"`
# calls in dod-check / the dod agent, so no skill or agent prose names the
# vendor CLI (docs/contracts.md single-vetted-entry-point rule).
#
# Usage:
#   list-children.sh <EPIC-KEY>                       # live: calls acli
#   list-children.sh <EPIC-KEY> --from-fixture <path> # test: reads a JSON file
#
# Fixture / acli JSON shape: a search response — either a bare array of work
# items or an object with a top-level array under .results/.issues/.workItems —
# each item carrying .key and .fields.{summary,status.name,issuetype.name}.
#
# Output: the normalized JSON array on stdout (possibly []). Warnings to stderr.
# Exit:
#   0 — array printed
#   1 — JSON unparseable / no recognizable work-item array
#   2 — bad usage
#   3 — acli not on PATH, or acli call failed

set -u
set -o pipefail

usage() {
  echo "usage: list-children.sh <EPIC-KEY> [--from-fixture <path>]" >&2
  exit 2
}

[[ $# -lt 1 ]] && usage
EPIC="$1"
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

if [[ -n "$FIXTURE" ]]; then
  [[ -f "$FIXTURE" ]] || { echo "fixture not found: $FIXTURE" >&2; exit 3; }
  JSON="$(cat "$FIXTURE")"
else
  if ! command -v acli >/dev/null; then
    echo "acli not on PATH; install Atlassian CLI" >&2
    exit 3
  fi
  JSON="$(acli jira workitem search --jql "parent = $EPIC" --json 2>/dev/null)" || {
    echo "acli search failed (auth? key? network?); run 'acli auth' to verify" >&2
    exit 3
  }
fi

echo "$JSON" | jq . >/dev/null 2>&1 || { echo "JSON unparseable for children of $EPIC" >&2; exit 1; }

# Accept a bare array or the common wrapper keys acli/Jira use.
echo "$JSON" | jq -e '
  (if type == "array" then . else (.results // .issues // .workItems // null) end)
  | if type == "array" then
      map({key: .key,
           summary: (.fields.summary // ""),
           status: (.fields.status.name // ""),
           type: (.fields.issuetype.name // "")})
    else error("no work-item array") end
' 2>/dev/null || { echo "no recognizable work-item array for children of $EPIC" >&2; exit 1; }
