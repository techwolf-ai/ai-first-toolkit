#!/usr/bin/env bash
# Generic lint orchestrator: run every executable check in <checks-dir> against <file>.
#
# Each check is a standalone `check-*.sh` taking one argument (the file to lint),
# exiting 0 on pass and 1 on a violation (2 = bad usage / not-a-file). This script
# iterates the directory in sorted order, runs each check, collects failures, and
# exits 1 if any check failed.
#
# Usage:
#   run-checks.sh <checks-dir> <file>
#
# Output: each failing check's findings (its own stdout) are passed through; a
# one-line summary is printed at the end.
# Exit:
#   0 — every check passed (or the dir has no checks)
#   1 — one or more checks failed
#   2 — bad usage / not a directory / not a file

set -u

if [[ $# -ne 2 ]]; then
  echo "usage: run-checks.sh <checks-dir> <file>" >&2
  exit 2
fi
CHECKS_DIR="$1"
FILE="$2"
if [[ ! -d "$CHECKS_DIR" ]]; then
  echo "not a directory: $CHECKS_DIR" >&2
  exit 2
fi
if [[ ! -f "$FILE" ]]; then
  echo "not a file: $FILE" >&2
  exit 2
fi

fail=0
ran=0
for check in "$CHECKS_DIR"/check-*.sh; do
  # Guard against the no-match glob (set -u-safe; the glob stays literal then).
  [[ -e "$check" ]] || continue
  [[ -x "$check" ]] || continue
  ran=$((ran + 1))
  if ! "$check" "$FILE"; then
    fail=1
  fi
done

if (( ran == 0 )); then
  echo "warning: no executable check-*.sh found in $CHECKS_DIR" >&2
fi

if (( fail == 1 )); then
  echo
  echo "Lint failed. Fix violations before running model-driven review."
  exit 1
fi
echo "Lint passed."
exit 0
