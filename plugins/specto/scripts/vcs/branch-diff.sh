#!/usr/bin/env bash
# Print the unified diff of trunk...HEAD (the current branch's own changes).
# Thin wrapper over vcs/_lib.sh specto_branch_diff (jj auto-detected via
# `jj root`; plain git otherwise).
#
# Usage:
#   branch-diff.sh                       # live
#   branch-diff.sh --from-fixture <dir>  # test: prints <dir>/branch-diff.txt
#
# Output: the unified diff on stdout (empty when trunk == HEAD);
# warnings/errors to stderr.
# Exit:
#   0 — diff printed (possibly empty)
#   1 — fixture dir exists but has no branch-diff.txt
#   2 — bad usage
#   3 — no trunk resolvable / the diff command failed / fixture dir missing
set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
. "$SCRIPT_DIR/_lib.sh"

usage() {
  echo "usage: branch-diff.sh [--from-fixture <dir>]" >&2
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
  [[ -f "$FIXTURE_DIR/branch-diff.txt" ]] || { echo "fixture missing branch-diff.txt: $FIXTURE_DIR" >&2; exit 1; }
  cat "$FIXTURE_DIR/branch-diff.txt"
  exit 0
fi

specto_branch_diff && exit 0
echo "could not diff against trunk (trunk unresolvable? not a repo?); set TRUNK" >&2
exit 3
