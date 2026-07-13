# Deterministic checks for the product-review lane-discipline control. The spec is
# clean on product-review's axes but carries a V1/V2 scope-bucket blur (a Must item
# also listed as a Won't-have) — scope-review's lane. product-review legitimately
# raises its OWN in-lane nits here, so we must NOT assert its clean sentinel or
# zero-bullets (that fails on a normal in-lane finding — the !76 calibration
# lesson, mis-applied in the first cut). Asserting a *silence* is rubric-heavy by
# design: checks.sh only guards that product-review did not adopt scope-review's
# finding vocabulary; the rubric judges non-straying. Sourced with $SANDBOX,
# $TRANSCRIPT, PASS/FAIL in scope.

t="$TRANSCRIPT"
assert "lane-product" "review produced output" "$([[ -s "$t" ]] && echo yes || echo no)" "yes"

# It must not raise the scope blur as a FINDING (its neighbour's lane). Match a
# collect-format finding bullet whose type is scope-flavoured — NOT any prose
# mention (the model legitimately narrates "I decline to flag this as scope-creep",
# which must not trip the guard). The broader "did it stray" call is the rubric's.
assert "lane-product" "did not raise the scope blur as a finding bullet" \
  "$([[ "$(grep -ciE '^-[[:space:]]*\*\*\[[^]]*(scope|moscow|wonthave|v1.?v2)' "$t")" -eq 0 ]] && echo yes || echo no)" "yes"
