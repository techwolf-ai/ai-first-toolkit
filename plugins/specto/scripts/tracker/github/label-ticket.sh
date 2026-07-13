#!/usr/bin/env bash
# Add one or more labels to an existing GitHub issue. `gh issue edit
# --add-label` is additive (it never clobbers existing labels). Unlike Jira's
# freeform labels, gh rejects labels that do not exist in the repo, so a
# rejected edit gets one retry after best-effort `gh label create` per label.
#
# Usage (identical to the jira counterpart):
#   label-ticket.sh <KEY> <label> [<label>...]
#   label-ticket.sh <KEY> <label>... --from-fixture <path>   # test mode (no write)
#
# Output: nothing on stdout on success; warnings/errors to stderr.
# Exit:
#   0 - labels applied (or test-mode fixture)
#   2 - bad usage
#   3 - gh not on PATH, or the edit failed

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/_lib.sh"

usage() {
  echo "usage: label-ticket.sh <KEY> <label> [<label>...] [--from-fixture <path>]" >&2
  exit 2
}

[[ $# -lt 2 ]] && usage
KEY="$1"
shift

LABELS=()
FIXTURE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from-fixture) [[ $# -ge 2 ]] || usage; FIXTURE="$2"; shift 2 ;;
    *) LABELS+=("$1"); shift ;;
  esac
done

[[ ${#LABELS[@]} -ge 1 ]] || usage

if [[ -n "$FIXTURE" ]]; then
  [[ -f "$FIXTURE" ]] || { echo "fixture not found: $FIXTURE" >&2; exit 3; }
  exit 0
fi

specto_require_gh

edit_args=(issue edit "$KEY")
for l in "${LABELS[@]}"; do edit_args+=(--add-label "$l"); done

if ! gh "${edit_args[@]}" >/dev/null 2>&1; then
  for l in "${LABELS[@]}"; do
    gh label create "$l" --color ededed --description "created by specto" >/dev/null 2>&1 || true
  done
  if ! gh "${edit_args[@]}" >/dev/null 2>&1; then
    echo "warning: could not apply labels to #$KEY: ${LABELS[*]}" >&2
    exit 3
  fi
fi
