# Deterministic checks for the product-review NEGATIVE CONTROL. A real reviewer
# raises minor in-lane nits even on a well-formed spec, so demanding the exact
# clean sentinel + zero bullets is unwinnable (the !76 calibration lesson,
# mis-applied in the first cut). The deterministic guard is narrow: product-review
# must not demand eng-spec-style endpoint request/response tables on a product
# spec (the specific over-flag the calibration surfaced, fixed in the agent). The
# broader false-positive judgement is the rubric's. Sourced with $SANDBOX,
# $TRANSCRIPT, PASS/FAIL in scope.

t="$TRANSCRIPT"
assert "clean-product" "review produced output" "$([[ -s "$t" ]] && echo yes || echo no)" "yes"

# §3.2 endpoints in a product spec are names + one-line behaviour only; demanding
# request/response/param tables is eng-review §2.6's lane, not product-review's.
assert "clean-product" "did not demand eng-spec endpoint tables" \
  "$([[ "$(grep -ciE 'endpoint-naming|request/response table|request.body.*response.*(table|schema)|missing.*(request|response).*table' "$t")" -eq 0 ]] && echo yes || echo no)" "yes"
