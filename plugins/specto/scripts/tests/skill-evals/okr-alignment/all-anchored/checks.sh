# Deterministic checks for the okr-alignment NEGATIVE CONTROL. Every §1.3
# objective anchors to a real KR, so the false-positive guard is the clean
# sentinel plus the absence of finding bullets. Sourced with $SANDBOX,
# $TRANSCRIPT, PASS/FAIL in scope.

t="$TRANSCRIPT"
assert "all-anchored" "review produced output" "$([[ -s "$t" ]] && echo yes || echo no)" "yes"

# The clean sentinel — okr-alignment prints this when every objective anchors.
assert "all-anchored" "emitted the clean sentinel" \
  "$([[ "$(grep -ciE '\[specto:okr-alignment-review\] all §1.3 objectives anchor to OKRs in' "$t")" -ge 1 ]] && echo yes || echo no)" "yes"

# No collect-format finding bullets emitted.
assert "all-anchored" "emitted no finding bullets" \
  "$([[ "$(grep -cE '^-[[:space:]]+\*\*\[[a-z-]+\]' "$t")" -eq 0 ]] && echo yes || echo no)" "yes"
