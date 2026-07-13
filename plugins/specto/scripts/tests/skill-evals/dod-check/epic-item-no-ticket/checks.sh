# Deterministic checks for the dod epic-creation coverage eval. Assert the
# epic-creation report ran and flagged at least one uncovered checklist item (the
# "Write enablement docs" item that no child ticket references). WHICH item and
# the covered/uncovered nuance for "Add unit tests" are the rubric's call. Sourced
# with $SANDBOX, $TRANSCRIPT, PASS/FAIL in scope.

t="$TRANSCRIPT"
assert "dod-epic" "review produced output" "$([[ -s "$t" ]] && echo yes || echo no)" "yes"

# The epic-creation report marker (tolerate the main agent relaying it in prose).
assert "dod-epic" "emitted an epic-creation coverage report" \
  "$([[ "$(grep -ciE 'epic-creation dod coverage|dod coverage for epic|epic-creation dod' "$t")" -ge 1 ]] && echo yes || echo no)" "yes"

# The epic Issue Checklist source was actually read (stub returned it).
assert "dod-epic" "read the epic Issue Checklist source" \
  "$([[ "$(grep -ciE 'issue checklist|checklist|enablement docs' "$t")" -ge 1 ]] && echo yes || echo no)" "yes"

# At least one uncovered checklist item flagged (✗ marker or its prose equivalent).
assert "dod-epic" "flagged at least one uncovered item" \
  "$([[ "$(grep -cE '✗' "$t")" -ge 1 || "$(grep -ciE 'no ticket references this|uncovered|not covered'  "$t")" -ge 1 ]] && echo yes || echo no)" "yes"
