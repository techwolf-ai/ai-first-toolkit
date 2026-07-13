# Deterministic checks for the code-mr-review spec-adherence + ac-coverage eval.
# code-mr-review's collect format groups findings under `### <axis>` headings and
# namespaces finding-types (`spec-adherence-*`, `ac-coverage-*`). Assert the two
# planted axes fired; leave "flagged the RIGHT divergence / the RIGHT missing AC"
# to the rubric (the model narrates the specifics in variable prose). Findings may
# also be routed to .md-review/comments.json — grep both the transcript and that
# sidecar. Sourced with $SANDBOX, $TRANSCRIPT, PASS/FAIL in scope.

t="$TRANSCRIPT"
sink="$SANDBOX/.md-review/comments.json"
both() { grep -ciE "$1" "$t" 2>/dev/null; [[ -f "$sink" ]] && grep -ciE "$1" "$sink" 2>/dev/null; }
hit()  { [[ "$( { both "$1"; } | awk '{s+=$1} END{print s+0}' )" -ge 1 ]] && echo yes || echo no; }

assert "review-mr" "review produced output" "$([[ -s "$t" ]] && echo yes || echo no)" "yes"

# Planted defect #1 — the fixed-storage-decision divergence (new column vs §2.3).
assert "review-mr" "emitted a spec-adherence finding" "$(hit 'spec-adherence')" "yes"

# Planted defect #2 — the uncovered AC (closed-ticket guard).
assert "review-mr" "emitted an ac-coverage finding"   "$(hit 'ac-coverage')" "yes"

# It must not declare the branch clean.
assert "review-mr" "did not declare no findings" \
  "$([[ "$(grep -ciE 'no findings on' "$t")" -eq 0 ]] && echo yes || echo no)" "yes"
