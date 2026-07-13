# Deterministic checks for the dod missing-checklist-item eval. Assert the DoD
# report ran, read the (stubbed) epic Issue Checklist, and flagged at least one
# missing item (✗). WHICH item (enablement docs / rollback path) and the not-pass
# verdict nuance are the rubric's call. Sourced with $SANDBOX, $TRANSCRIPT, PASS/FAIL.

t="$TRANSCRIPT"
assert "dod" "review produced output" "$([[ -s "$t" ]] && echo yes || echo no)" "yes"

# The DoD report marker (tolerate the main agent relaying it in prose).
assert "dod" "emitted a DoD report" \
  "$([[ "$(grep -ciE 'specto:dod|DoD report|definition[- ]of[- ]done' "$t")" -ge 1 ]] && echo yes || echo no)" "yes"

# The epic Issue Checklist source was actually read (stub returned it), so the
# report should reference the checklist — not skip source #1.
assert "dod" "read the epic Issue Checklist source" \
  "$([[ "$(grep -ciE 'issue checklist|checklist' "$t")" -ge 1 ]] && echo yes || echo no)" "yes"

# At least one missing DoD item flagged (✗ marker, or its prose equivalent).
assert "dod" "flagged at least one missing item" \
  "$([[ "$(grep -cE '✗' "$t")" -ge 1 || "$(grep -ciE 'missing|not (yet )?(done|satisfied|covered)|uncovered' "$t")" -ge 1 ]] && echo yes || echo no)" "yes"
