#!/usr/bin/env bash
# Set (re-attach) the parent of a Jira work item via `acli jira workitem edit
# --parent`. Used by create-test-plan to mirror the implementer's epic onto the
# paired Test Plan. Some acli versions don't support `edit --parent`; that's a
# soft failure (exit 3) so the caller can fall back to a `Relates` link.
#
# Usage:
#   set-parent.sh <KEY> <PARENT_KEY>                       # live
#   set-parent.sh <KEY> <PARENT_KEY> --from-fixture <path> # test (no acli, no network)
#
# Output: nothing on stdout on success; warnings/errors to stderr.
# Exit:
#   0 — parent set
#   2 — bad usage
#   3 — acli not on PATH, or `edit --parent` failed / is unsupported
set -u
set -o pipefail

usage() {
  echo "usage: set-parent.sh <KEY> <PARENT_KEY> [--from-fixture <path>]" >&2
  exit 2
}

[[ $# -lt 2 ]] && usage
KEY="$1"
PARENT_KEY="$2"
shift 2

FIXTURE=""
if [[ $# -gt 0 ]]; then
  if [[ "$1" == "--from-fixture" && $# -ge 2 ]]; then
    FIXTURE="$2"
    shift 2
  else
    usage
  fi
fi
[[ $# -gt 0 ]] && usage

if [[ -n "$FIXTURE" ]]; then
  [[ -f "$FIXTURE" ]] || { echo "fixture not found: $FIXTURE" >&2; exit 3; }
  exit 0
fi

if ! command -v acli >/dev/null; then
  echo "acli not on PATH; install Atlassian CLI" >&2
  exit 3
fi

if ! acli jira workitem edit --key "$KEY" --parent "$PARENT_KEY" --yes >/dev/null 2>&1; then
  echo "acli edit --parent failed on $KEY -> $PARENT_KEY (unsupported acli version? auth? key?)" >&2
  exit 3
fi
