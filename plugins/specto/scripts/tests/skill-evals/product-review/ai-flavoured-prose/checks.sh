# Deterministic checks for the product-review ai-flavoured-prose eval. Assert the
# review ran and flagged at least one of the two planted product-review-owned
# defects — the AI-flavoured/marketing prose or the unexplained codename
# (cold-reader-gap). The finding-type vocabulary is open, so accept the stable
# category tokens; WHICH one and the fix are the rubric's call. Sourced with
# $SANDBOX, $TRANSCRIPT, PASS/FAIL in scope.

t="$TRANSCRIPT"
assert "product-review" "review produced output" "$([[ -s "$t" ]] && echo yes || echo no)" "yes"

# At least one planted defect flagged: AI-flavoured prose OR the cold-reader
# unexplained-codename gap.
assert "product-review" "flagged AI-flavoured prose or the cold-reader codename gap" \
  "$([[ "$(grep -ciE 'ai-flavou?red|ai-generated|marketing[ -]?(prose|language|speak)|flowery|filler prose|cold-reader|unexplained (codename|internal|context)|codename|cormorant' "$t")" -ge 1 ]] && echo yes || echo no)" "yes"

# It must not declare the spec clean (there are real findings).
assert "product-review" "did not emit the clean sentinel" \
  "$([[ "$(grep -ciE 'no findings against guidelines' "$t")" -eq 0 ]] && echo yes || echo no)" "yes"
