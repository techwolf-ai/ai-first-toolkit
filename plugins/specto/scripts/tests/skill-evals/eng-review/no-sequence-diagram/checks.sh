# Deterministic checks for the eng-review no-sequence-diagram eval. Assert the
# review ran and flagged the missing sequence diagram. The exact finding-type
# string can drift (open finding vocabulary), so accept the stable token
# `no-sequence-diagram` OR the phrase "sequence diagram". WHICH flow / line and
# the recommendation are the rubric's call. Sourced with $SANDBOX, $TRANSCRIPT,
# PASS/FAIL in scope.

t="$TRANSCRIPT"
assert "eng-review" "review produced output" "$([[ -s "$t" ]] && echo yes || echo no)" "yes"

# Planted defect — the prose-only multi-actor flow with no sequenceDiagram.
assert "eng-review" "flagged the missing sequence diagram" \
  "$([[ "$(grep -ciE 'no-sequence-diagram|sequence[ -]?diagram' "$t")" -ge 1 ]] && echo yes || echo no)" "yes"

# It must not declare the spec clean (there is a real finding).
assert "eng-review" "did not emit the clean sentinel" \
  "$([[ "$(grep -ciE 'no findings against guidelines' "$t")" -eq 0 ]] && echo yes || echo no)" "yes"
