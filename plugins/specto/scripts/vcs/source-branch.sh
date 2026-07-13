#!/usr/bin/env bash
# Print the source branch for the current checkout (git + jj colocated).
# Thin wrapper over vcs/_lib.sh specto_source_branch.
#
# Usage:
#   source-branch.sh                       # live
#   source-branch.sh --from-fixture <dir>  # test: prints <dir>/source-branch.txt
#
# Output: the branch name on stdout; warnings/errors to stderr.
# Exit:
#   0 — resolved
#   1 — fixture dir exists but has no source-branch.txt
#   2 — bad usage
#   3 — no branch resolvable (detached HEAD, no bookmark/ref) / fixture dir missing
set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
. "$SCRIPT_DIR/_lib.sh"

usage() {
  echo "usage: source-branch.sh [--from-fixture <dir>]" >&2
  exit 2
}

FIXTURE_DIR=""
if [[ $# -gt 0 && "$1" == "--from-fixture" ]]; then
  [[ $# -ge 2 ]] || usage
  FIXTURE_DIR="$2"
  shift 2
fi
[[ $# -eq 0 ]] || usage

if [[ -n "$FIXTURE_DIR" ]]; then
  [[ -d "$FIXTURE_DIR" ]] || { echo "fixture dir not found: $FIXTURE_DIR" >&2; exit 3; }
  [[ -f "$FIXTURE_DIR/source-branch.txt" ]] || { echo "fixture missing source-branch.txt: $FIXTURE_DIR" >&2; exit 1; }
  cat "$FIXTURE_DIR/source-branch.txt"
  exit 0
fi

specto_source_branch && exit 0
echo "could not resolve the source branch (detached HEAD?); set SOURCE_BRANCH" >&2
exit 3
