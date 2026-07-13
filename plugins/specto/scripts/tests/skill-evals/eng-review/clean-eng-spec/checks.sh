# Deterministic checks for the eng-review NEGATIVE CONTROL. A real reviewer raises
# minor in-lane nits even on a well-formed spec, so demanding the exact clean
# sentinel + zero bullets is unwinnable (the !76 calibration lesson, mis-applied
# in the first cut). The deterministic guard is therefore narrow: it must not
# fabricate the SIBLING detection defects this control pairs with. The broader
# false-positive judgement ("no fabricated guideline violation") is the rubric's.
# Sourced with $SANDBOX, $TRANSCRIPT, PASS/FAIL in scope.

t="$TRANSCRIPT"
assert "clean-eng" "review produced output" "$([[ -s "$t" ]] && echo yes || echo no)" "yes"

# The spec HAS a sequenceDiagram and is NOT an AI feature, so neither planted
# detection defect exists here — fabricating either is a false positive.
assert "clean-eng" "did not fabricate a missing-sequence-diagram finding" \
  "$([[ "$(grep -ciE 'no-sequence-diagram' "$t")" -eq 0 ]] && echo yes || echo no)" "yes"
assert "clean-eng" "did not fabricate a missing-AI-test-plan finding" \
  "$([[ "$(grep -ciE 'ai-testplan-missing' "$t")" -eq 0 ]] && echo yes || echo no)" "yes"
