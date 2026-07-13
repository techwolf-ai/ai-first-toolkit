# Deterministic checks for the test-critic uncovered-edge-case eval. Assert the
# report shape and that AT LEAST ONE uncovered case was flagged; WHICH gap (the
# None/boundary/error paths) is the rubric's call. Tolerate phrasing drift — the
# ✗ marker is the stable signal, with an "uncovered / no test asserts" fallback.
# Sourced with $SANDBOX, $TRANSCRIPT, PASS/FAIL in scope.

t="$TRANSCRIPT"
assert "test-critic" "review produced output" "$([[ -s "$t" ]] && echo yes || echo no)" "yes"

# The test-critic report marker. Robust across renderings — the main agent may
# relay it as `[specto:test-critic]` or as a `## Test-critic report` heading; the
# `test-critic` token appears either way.
assert "test-critic" "emitted a test-critic report" \
  "$([[ "$(grep -ciE 'test-critic' "$t")" -ge 1 ]] && echo yes || echo no)" "yes"

# At least one uncovered case (✗ marker, or its prose equivalent).
assert "test-critic" "flagged at least one uncovered case" \
  "$([[ "$(grep -cE '✗' "$t")" -ge 1 || "$(grep -ciE 'no test asserts|uncovered' "$t")" -ge 1 ]] && echo yes || echo no)" "yes"

# The report carries its Summary tally line.
assert "test-critic" "emitted a Summary line" \
  "$([[ "$(grep -ciE 'summary:' "$t")" -ge 1 ]] && echo yes || echo no)" "yes"
