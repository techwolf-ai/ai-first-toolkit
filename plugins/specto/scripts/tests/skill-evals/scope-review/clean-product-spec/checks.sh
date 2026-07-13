# Deterministic checks for the scope-review NEGATIVE CONTROL. The spec is clean,
# so the false-positive guard is the ABSENCE of concrete finding markers — the
# guardian must not invent the crisp categories it would emit on a dirty spec.
# The nuanced "declared clean / at most trivial notes" judgement is the rubric's.
# Sourced with $SANDBOX, $TRANSCRIPT, PASS/FAIL in scope.

t="$TRANSCRIPT"
assert "clean" "review produced output" "$([[ -s "$t" ]] && echo yes || echo no)" "yes"

# No fabricated Won't-have-reason finding — every row here has a concrete Reason.
assert "clean" "did not fabricate a wonthave-no-reason finding" \
  "$([[ "$(grep -ciE 'wonthave-no-reason' "$t")" -eq 0 ]] && echo yes || echo no)" "yes"

# No collect-format finding bullets emitted (`- **[finding-type] ...`). A clean
# spec should yield the "no scope issues found" path, not a list of findings.
assert "clean" "emitted no scope-finding bullets" \
  "$([[ "$(grep -cE '^-[[:space:]]+\*\*\[[a-z-]+\]' "$t")" -eq 0 ]] && echo yes || echo no)" "yes"
