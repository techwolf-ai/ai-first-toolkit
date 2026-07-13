#!/usr/bin/env bash
# Shared assertion helpers for Specto's bash test suites.
#
# Source this after computing the suite's own paths, then use `assert` /
# `assert_exit`, and (optionally) end with `assert_summary`. It defines the
# PASS / FAIL counters, so the sourcing suite must not redeclare them.
#
#   source "<path>/tests/lib/assert.sh"
#   assert "label" "condition" "$actual" "$expected"
#   assert_exit 0 "$rc" "helper succeeds"
#   assert_summary        # prints "Total: N passed, M failed"; returns non-zero if any failed

PASS=0
FAIL=0

# Value-equality assertion. Output is intentionally stable across suites:
#   "  PASS: <label> — <condition>"  /  "  FAIL: <label> — <condition> (expected: …; got: …)"
assert() {
  local label="$1" condition_label="$2" actual="$3" expected="$4"
  if [[ "$actual" == "$expected" ]]; then
    echo "  PASS: $label — $condition_label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — $condition_label (expected: $expected; got: $actual)"
    FAIL=$((FAIL + 1))
  fi
}

# Exit-code assertion: assert_exit <expected> <actual> <label>.
assert_exit() {
  local expected="$1" actual="$2" label="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label (expected exit $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

# Print the tally and return success only if nothing failed. Optional first arg
# overrides the "Total" label (e.g. a suite name).
assert_summary() {
  local prefix="${1:-Total}"
  echo
  echo "$prefix: $PASS passed, $FAIL failed"
  [[ "$FAIL" -eq 0 ]]
}
