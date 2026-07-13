#!/usr/bin/env bash
# Read a Jira work item's parent key. Tries `.fields.parent.key` first, then
# falls back to the first inward `Relates` link (the convention create-ticket
# adopts when the would-be-parent is a Task). Prints
# the parent key on stdout, nothing if no parent / relates link is found.
# Sibling of get-ticket-summary.sh / get-ticket-type.sh.
#
# Used by create-test-plan to mirror the implementation ticket's parent onto the
# Test Plan, regardless of whether the parent was wired via --parent (Epic) or
# Relates (Task-as-epic).
#
# Usage:
#   get-ticket-parent.sh <KEY>                       # live: calls acli
#   get-ticket-parent.sh <KEY> --from-fixture <path> # test: reads a JSON file
#
# Fixture / acli JSON shape: a work-item object with `.fields.parent.key` and/or
# `.fields.issuelinks` (Jira's standard shapes).
#
# Output: the parent key on stdout, newline-terminated (nothing if no parent).
# A second tab-separated column reports the link mechanism so callers know how
# to mirror it: `<KEY>\tparent` for a real `--parent` link, `<KEY>\trelates`
# for a Relates-based fallback.
# Exit:
#   0 — parent printed, OR no parent (clean exit, empty stdout)
#   1 — JSON unparseable
#   2 — bad usage
#   3 — acli not on PATH, or acli call failed

set -u
set -o pipefail

usage() {
  echo "usage: get-ticket-parent.sh <KEY> [--from-fixture <path>]" >&2
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

if [[ -n "$FIXTURE" ]]; then
  [[ -f "$FIXTURE" ]] || { echo "fixture not found: $FIXTURE" >&2; exit 3; }
  JSON="$(cat "$FIXTURE")"
else
  if ! command -v acli >/dev/null; then
    echo "acli not on PATH; install Atlassian CLI" >&2
    exit 3
  fi
  JSON="$(acli jira workitem view "$KEY" --json --fields 'parent,issuelinks' 2>/dev/null)" || {
    echo "acli failed (auth? key? network?); run 'acli auth' to verify" >&2
    exit 3
  }
fi

echo "$JSON" | jq . >/dev/null 2>&1 || { echo "JSON unparseable for $KEY" >&2; exit 1; }

# Prefer `.fields.parent.key` (real Epic / sub-task parent). Fall back to the
# first inward `Relates` link (the Task-as-epic convention). The link's outward
# key is the "parent" the original ticket relates TO, regardless of which side
# the link was created on.
PARENT="$(echo "$JSON" | jq -r '.fields.parent.key // empty')"
if [[ -n "$PARENT" ]]; then
  printf '%s\tparent\n' "$PARENT"
  exit 0
fi

# Walk issuelinks. We want a Relates link whose outwardIssue is the "parent"
# pointer. If multiple Relates exist, prefer the first stable one — callers can
# inspect the rest themselves if needed.
RELATES_PARENT="$(echo "$JSON" | jq -r '
  [.fields.issuelinks[]?
    | select(.type.name == "Relates")
    | (.outwardIssue.key // .inwardIssue.key)
  ] | map(select(. != null)) | first // empty
')"
if [[ -n "$RELATES_PARENT" ]]; then
  printf '%s\trelates\n' "$RELATES_PARENT"
  exit 0
fi

exit 0
