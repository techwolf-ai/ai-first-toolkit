# Deterministic checks for the scope-review lane-discipline control. The spec is
# scope-clean but carries writing-clarity issues (AI-flavoured prose + an
# unexplained codename) that belong to product-review's lane. The false-positive
# guard is scope-review's clean sentinel plus the ABSENCE of scope finding
# markers. Whether it strayed into product-review's lane is the rubric's call.
# Sourced with $SANDBOX, $TRANSCRIPT, PASS/FAIL in scope.

t="$TRANSCRIPT"
assert "lane-scope" "review produced output" "$([[ -s "$t" ]] && echo yes || echo no)" "yes"

# scope-review's clean sentinel — the spec has no scope issues.
assert "lane-scope" "emitted the scope clean sentinel" \
  "$([[ "$(grep -ciE 'no scope issues found' "$t")" -ge 1 ]] && echo yes || echo no)" "yes"

# No fabricated Won't-have-reason finding — both rows have concrete Reasons.
assert "lane-scope" "did not fabricate a wonthave-no-reason finding" \
  "$([[ "$(grep -ciE 'wonthave-no-reason' "$t")" -eq 0 ]] && echo yes || echo no)" "yes"

# No collect-format finding bullets emitted (`- **[finding-type] ...`). A clean
# spec should yield the sentinel path, not a list of findings.
assert "lane-scope" "emitted no scope-finding bullets" \
  "$([[ "$(grep -cE '^-[[:space:]]+\*\*\[[a-z-]+\]' "$t")" -eq 0 ]] && echo yes || echo no)" "yes"
