#!/usr/bin/env bash
# Aggregate test runner for every Specto helper suite.
#
# Runs the top-level config suite (config-suite.sh) plus every per-domain
# scripts/<domain>/tests/run-tests.sh, reports each suite's pass/fail, and
# exits non-zero if ANY suite fails. This is the single entry point CI runs on
# every MR; the per-domain runners stay independently runnable for local work.
#
# Each suite is expected to exit 0 on all-pass and non-zero on any failure
# (the shared convention: `[[ "$FAIL" -eq 0 ]]` as the last line).

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"   # .../scripts/tests
SCRIPTS="$(cd "$HERE/.." && pwd)"       # .../scripts

# Assemble the suite list: config suite first, then each domain runner in a
# stable (sorted-by-glob) order. Backend impls nest one level deeper
# (scripts/<domain>/<backend>/tests/), so both depths are globbed.
suites=()
[[ -f "$HERE/config-suite.sh" ]] && suites+=("$HERE/config-suite.sh")
for f in "$SCRIPTS"/*/tests/run-tests.sh "$SCRIPTS"/*/*/tests/run-tests.sh; do
  [[ -f "$f" ]] && suites+=("$f")
done
# The end-to-end structural-invariant suite lives under scripts/tests/e2e/ (not a
# scripts/<domain>/tests/ path), so add it explicitly, last.
[[ -f "$HERE/e2e/run-tests.sh" ]] && suites+=("$HERE/e2e/run-tests.sh")

if [[ ${#suites[@]} -eq 0 ]]; then
  echo "run-all: no test suites found under $SCRIPTS" >&2
  exit 2
fi

passed=0
failed_names=()
for s in "${suites[@]}"; do
  rel="${s#"$SCRIPTS"/}"
  echo "############################################################"
  echo "# $rel"
  echo "############################################################"
  if bash "$s"; then
    passed=$((passed + 1))
  else
    failed_names+=("$rel")
  fi
  echo
done

total=${#suites[@]}
echo "============================================================"
echo "Suites: $passed/$total passed"
if [[ ${#failed_names[@]} -gt 0 ]]; then
  printf 'FAILED SUITE: %s\n' "${failed_names[@]}"
  exit 1
fi
echo "All suites passed."
