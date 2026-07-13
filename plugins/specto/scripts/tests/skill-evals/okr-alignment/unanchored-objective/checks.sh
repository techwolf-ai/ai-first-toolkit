# Deterministic checks for the okr-alignment unanchored-objective eval. Assert the
# review ran and flagged the objective referencing O4.KR1 (absent from the OKR
# source). WHICH row / the recommendation is the rubric's call. Sourced with
# $SANDBOX, $TRANSCRIPT, PASS/FAIL in scope.

t="$TRANSCRIPT"
assert "okr" "review produced output" "$([[ -s "$t" ]] && echo yes || echo no)" "yes"

# Planted defect — the O4.KR1 objective does not anchor to any KR in okrs.md.
assert "okr" "flagged the unanchored objective" \
  "$([[ "$(grep -ciE 'okr-not-found|not found|O4\.KR1' "$t")" -ge 1 ]] && echo yes || echo no)" "yes"

# It must not declare all objectives anchored (there is a real finding).
assert "okr" "did not emit the clean sentinel" \
  "$([[ "$(grep -ciE 'all §1.3 objectives anchor' "$t")" -eq 0 ]] && echo yes || echo no)" "yes"
