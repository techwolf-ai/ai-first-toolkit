# Deterministic checks for the change-classification drift eval. Assert the review
# ran, read the epic (via the acli stub), and flagged the spec-vs-epic
# classification drift (header says Standard, epic Q1=Yes). The exact wording of
# the correct classification is the rubric's call. Sourced with $SANDBOX,
# $TRANSCRIPT, PASS/FAIL in scope.

t="$TRANSCRIPT"
assert "classification" "review produced output" "$([[ -s "$t" ]] && echo yes || echo no)" "yes"

# The epic source was actually read (stub returned Q1=Yes), so the review should
# reference the classification not being consistent — not skip the source.
assert "classification" "did not skip the epic source" \
  "$([[ "$(grep -ciE 'acli unavailable|not readable|classification skipped|no epic linked' "$t")" -eq 0 ]] && echo yes || echo no)" "yes"

# Planted defect — the classification drift between spec header and epic.
assert "classification" "flagged the classification drift" \
  "$([[ "$(grep -ciE 'classification-drift|non-standard \(?q1|Q1.?=.?Yes|should (be|read) .*non-standard' "$t")" -ge 1 ]] && echo yes || echo no)" "yes"

# It must not declare the classification consistent (there is real drift).
assert "classification" "did not emit the consistent sentinel" \
  "$([[ "$(grep -ciE 'classification consistent with epic' "$t")" -eq 0 ]] && echo yes || echo no)" "yes"
