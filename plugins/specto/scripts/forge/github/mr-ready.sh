#!/usr/bin/env bash
# Flip the current branch's PR out of draft (mark it ready for review).
# Thin wrapper over `gh pr ready`.
#
# Usage:
#   mr-ready.sh                       # live
#   mr-ready.sh --from-fixture <dir>  # test: no-op success (dir just has to exist)
#
# Output: nothing on stdout on success; warnings/errors to stderr.
# Exit:
#   0: marked ready (or fixture no-op)
#   2: bad usage
#   3: gh not on PATH / no PR for the branch / the gh call failed

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
. "$SCRIPT_DIR/_lib.sh"

FIXTURE_DIR=""
if [[ $# -gt 0 ]]; then
  if [[ "$1" == "--from-fixture" && $# -ge 2 ]]; then
    FIXTURE_DIR="$2"
    shift 2
  fi
fi
if [[ $# -gt 0 ]]; then
  echo "usage: mr-ready.sh [--from-fixture <dir>]" >&2
  exit 2
fi

if [[ -n "$FIXTURE_DIR" ]]; then
  [[ -d "$FIXTURE_DIR" ]] || { echo "fixture dir not found: $FIXTURE_DIR" >&2; exit 3; }
  exit 0
fi

if ! command -v gh >/dev/null; then
  echo "gh not on PATH; install the GitHub CLI" >&2
  exit 3
fi
BRANCH="$(specto_source_branch)" || { echo "could not resolve the source branch (detached HEAD?); set SOURCE_BRANCH" >&2; exit 3; }
if ! gh pr ready "$BRANCH" >/dev/null 2>&1; then
  echo "gh pr ready failed for branch $BRANCH (no PR? auth?)" >&2
  exit 3
fi
