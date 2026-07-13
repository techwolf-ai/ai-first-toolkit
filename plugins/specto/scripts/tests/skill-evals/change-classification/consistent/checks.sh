# Deterministic checks for the change-classification NEGATIVE CONTROL. Header says
# Standard, epic answers all No — consistent. False-positive guard: the consistent
# sentinel plus no fabricated drift finding. Sourced with $SANDBOX, $TRANSCRIPT,
# PASS/FAIL in scope.

t="$TRANSCRIPT"
assert "consistent" "review produced output" "$([[ -s "$t" ]] && echo yes || echo no)" "yes"

# The consistent sentinel — printed when the header matches the epic.
assert "consistent" "emitted the consistent sentinel" \
  "$([[ "$(grep -ciE 'classification consistent with epic' "$t")" -ge 1 ]] && echo yes || echo no)" "yes"

# No fabricated classification-drift finding on a consistent spec.
assert "consistent" "did not fabricate a classification-drift finding" \
  "$([[ "$(grep -ciE 'classification-drift' "$t")" -eq 0 ]] && echo yes || echo no)" "yes"
