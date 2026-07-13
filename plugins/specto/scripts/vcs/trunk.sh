#!/usr/bin/env bash
# Print the default branch ("trunk") for the current checkout (git + jj).
# Thin wrapper over vcs/_lib.sh specto_trunk.
#
# Usage:
#   trunk.sh                       # live
#   trunk.sh --from-fixture <dir>  # test: prints <dir>/trunk.txt
#
# Output: the branch name on stdout; warnings/errors to stderr.
# Exit:
#   0 — resolved
#   1 — fixture dir exists but has no trunk.txt
#   2 — bad usage
#   3 — no trunk resolvable / fixture dir missing
set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
. "$SCRIPT_DIR/_lib.sh"

usage() {
  echo "usage: trunk.sh [--from-fixture <dir>]" >&2
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
  [[ -f "$FIXTURE_DIR/trunk.txt" ]] || { echo "fixture missing trunk.txt: $FIXTURE_DIR" >&2; exit 1; }
  cat "$FIXTURE_DIR/trunk.txt"
  exit 0
fi

specto_trunk && exit 0
echo "could not resolve the trunk branch (no origin/HEAD, no origin main/master); set TRUNK" >&2
exit 3
