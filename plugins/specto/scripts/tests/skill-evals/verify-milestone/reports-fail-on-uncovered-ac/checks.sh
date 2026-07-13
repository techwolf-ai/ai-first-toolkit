# Deterministic checks for the verify-milestone uncovered-AC eval. Assert the
# verdict came back `fail` and named M1-AC2 as the blocker. The exact JSON layout
# (spacing, key order) can vary in the model's narration, so tolerate whitespace
# around the "overall":"fail" pair. That M1-AC1 is correctly marked covered is the
# rubric's call. Sourced with $SANDBOX, $TRANSCRIPT, PASS/FAIL in scope.

t="$TRANSCRIPT"
assert "verify-ms" "run produced output" "$([[ -s "$t" ]] && echo yes || echo no)" "yes"

# Overall verdict is fail (uncovered AC blocks pass even though the suite is green).
assert "verify-ms" "verdict overall is fail" \
  "$([[ "$(grep -ciE '\"overall\"[[:space:]]*:[[:space:]]*\"fail\"' "$t")" -ge 1 ]] && echo yes || echo no)" "yes"

# M1-AC2 is named as the uncovered/failed criterion.
assert "verify-ms" "named M1-AC2 as uncovered/failed" \
  "$([[ "$(grep -ciE 'M1-AC2' "$t")" -ge 1 ]] && echo yes || echo no)" "yes"
