#!/usr/bin/env bash
# Flip the current branch's MR out of draft (mark it ready for review).
# Thin wrapper over `glab mr update --ready`.
#
# Usage:
#   mr-ready.sh                       # live
#   mr-ready.sh --from-fixture <dir>  # test: no-op success (dir just has to exist)
#
# Output: nothing on stdout on success; warnings/errors to stderr.
# Exit:
#   0 — marked ready (or fixture no-op)
#   2 — bad usage
#   3 — glab not on PATH / no MR for the branch / the glab call failed

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

if ! command -v glab >/dev/null; then
  echo "glab not on PATH; install the GitLab CLI" >&2
  exit 3
fi
BRANCH="$(specto_source_branch)" || { echo "could not resolve the source branch (detached HEAD?); set SOURCE_BRANCH" >&2; exit 3; }
if ! glab mr update "$BRANCH" --ready >/dev/null 2>&1; then
  echo "glab mr update --ready failed for branch $BRANCH (no MR? auth?)" >&2
  exit 3
fi
