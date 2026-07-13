#!/usr/bin/env bash
# Delete Jira issue links across one or more work items — the missing inverse of
# link-tickets.sh. Used to clean links up (e.g. before rebuilding a dependency
# graph). Collects every issuelink id on the given tickets (de-duped, since a
# link appears on BOTH endpoints) and deletes each via acli.
#
# Usage:
#   delete-links.sh <KEY> [<KEY>...] [--type <Name>] [--dry-run]
#   delete-links.sh <KEY> [<KEY>...] --from-fixture <issuelinks.json>   # test mode (no acli)
#
#   --type <Name>   only delete links of this type (e.g. Blocks); default: all types
#   --dry-run       print the link ids that would be deleted; delete nothing
#   --from-fixture  read issuelinks from the file instead of acli (lists the de-duped
#                   ids it would delete; no network, no deletes) — used by the tests
#
# acli has no "delete by issue" — only by link id — so we read each issue's
# issuelinks (`--fields=issuelinks`), pull `.id`, de-dupe, and delete each.
#
# Output: the deleted (or, with --dry-run/--from-fixture, the candidate) link ids,
#   one per line, on stdout; warnings/errors to stderr.
# Exit:
#   0 — links deleted (or dry-run/fixture listed)
#   2 — bad usage
#   3 — acli/jq not on PATH, or a delete call failed

set -u
set -o pipefail

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

# Extract issuelink ids from a `--fields=issuelinks --json` document, optionally
# filtered by link-type name.
jq_ids() {
  if [[ -n "$TYPE" ]]; then
    jq -r --arg t "$TYPE" '.fields.issuelinks[]? | select(.type.name == $t) | .id'
  else
    jq -r '.fields.issuelinks[]? | .id'
  fi
}

# Fixture mode: read links from the file (no acli), list de-duped ids, exit. Lets
# the test suite assert id-collection + type filtering without a network call.
if [[ -n "$FIXTURE" ]]; then
  [[ -f "$FIXTURE" ]] || { echo "fixture not found: $FIXTURE" >&2; exit 3; }
  jq_ids < "$FIXTURE" | sort -u
  exit 0
fi

command -v acli >/dev/null || { echo "acli not on PATH; install Atlassian CLI" >&2; exit 3; }
command -v jq   >/dev/null || { echo "jq not on PATH" >&2; exit 3; }

# Collect every link id across all keys, de-duped via `sort -u` (a link appears on
# both endpoints). Portable: no associative arrays — macOS ships bash 3.2.
collect() {
  local k json
  for k in "${KEYS[@]}"; do
    json="$(acli jira workitem view "$k" --json --fields issuelinks 2>/dev/null)" \
      || { echo "warning: could not read links for $k" >&2; continue; }
    printf '%s' "$json" | jq_ids
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
  if acli jira workitem link delete --id "$id" --yes >/dev/null 2>&1; then
    echo "$id"
  else
    echo "warning: failed to delete link $id" >&2
    rc=3
  fi
done <<< "$all_ids"
exit $rc
