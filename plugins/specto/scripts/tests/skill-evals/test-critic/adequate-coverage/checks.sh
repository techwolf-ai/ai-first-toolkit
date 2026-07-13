# Deterministic checks for the test-critic NEGATIVE CONTROL. The diff covers every
# edge case the spec §2.1 NAMES (None, negative, 0/below, 1 and 100 boundaries,
# 101/above, non-integer). test-critic is adversarial by design, so it may still
# raise a BEYOND-spec extra (empty string, whitespace, overflow) as ✗/? — that is
# its prerogative, not a false positive. So the deterministic layer only asserts
# the report ran and produced its tally; the real false-positive guard ("no
# IN-SCOPE, spec-named case flagged uncovered") is a judgement call and lives in
# rubric.md. Sourced with $SANDBOX, $TRANSCRIPT, PASS/FAIL in scope.

t="$TRANSCRIPT"
assert "adequate" "review produced output" "$([[ -s "$t" ]] && echo yes || echo no)" "yes"

# The report ran (robust across `[specto:test-critic]` / `## Test-critic report`).
assert "adequate" "emitted a test-critic report" \
  "$([[ "$(grep -ciE 'test-critic' "$t")" -ge 1 ]] && echo yes || echo no)" "yes"

# It carries its Summary tally line.
assert "adequate" "emitted a Summary line" \
  "$([[ "$(grep -ciE 'summary:' "$t")" -ge 1 ]] && echo yes || echo no)" "yes"
