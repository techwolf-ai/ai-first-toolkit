# Deterministic checks for the resolve-spec-comments clustering eval. Assert the
# skill produced a clustered revision plan in the documented per-cluster shape and
# classified into the 7 buckets. Whether each thread landed in the RIGHT bucket and
# whether it stayed advisory (no thread resolved, spec unedited) are the rubric's
# call. Sourced with $SANDBOX, $TRANSCRIPT, PASS/FAIL in scope.

t="$TRANSCRIPT"
assert "resolve-spec" "run produced output" "$([[ -s "$t" ]] && echo yes || echo no)" "yes"

# The per-cluster revision-plan scaffolding.
assert "resolve-spec" "emitted a Cluster block" \
  "$([[ "$(grep -ciE '##[[:space:]]*Cluster ' "$t")" -ge 1 ]] && echo yes || echo no)" "yes"
assert "resolve-spec" "listed Threads / Authors / Crux" \
  "$([[ "$(grep -ciE 'Threads:' "$t")" -ge 1 && "$(grep -ciE 'Authors:' "$t")" -ge 1 && "$(grep -ciE 'Crux:' "$t")" -ge 1 ]] && echo yes || echo no)" "yes"
assert "resolve-spec" "gave a recommended action" \
  "$([[ "$(grep -ciE 'Recommended action' "$t")" -ge 1 ]] && echo yes || echo no)" "yes"

# At least one of the 7 buckets is named (classification happened).
assert "resolve-spec" "classified into a bucket" \
  "$([[ "$(grep -ciE 'style-nit|decision-request|\bbug\b|question|disagreement|suggestion|out-of-scope' "$t")" -ge 1 ]] && echo yes || echo no)" "yes"
