# Deterministic checks for the eng-review ai-feature-no-ai-test-plan eval. Assert
# the review ran and flagged the missing §3.2 AI test plan on an AI feature. The
# finding-type string can drift, so accept the stable token `ai-testplan-missing`
# OR the phrase "AI test plan" near a missing/absent word. The recommendation is
# the rubric's call. Sourced with $SANDBOX, $TRANSCRIPT, PASS/FAIL in scope.

t="$TRANSCRIPT"
assert "eng-review" "review produced output" "$([[ -s "$t" ]] && echo yes || echo no)" "yes"

# Planted defect — §3.2 AI test plan absent on an AI feature.
assert "eng-review" "flagged the missing AI test plan" \
  "$([[ "$(grep -ciE 'ai-testplan-missing|ai test plan' "$t")" -ge 1 ]] && echo yes || echo no)" "yes"

# It must not declare the spec clean (there is a real finding).
assert "eng-review" "did not emit the clean sentinel" \
  "$([[ "$(grep -ciE 'no findings against guidelines' "$t")" -eq 0 ]] && echo yes || echo no)" "yes"
