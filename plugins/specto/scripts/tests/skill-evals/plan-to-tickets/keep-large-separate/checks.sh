# Deterministic checks for the keep-large-separate eval. Assert the dry-run ran,
# both workstreams' AC survive, and nothing was created live. "Exactly TWO tickets,
# not over-bundled into one" is a phrasing-sensitive judgement (the model narrates
# the dry-run as a table/prose) and lives in rubric.md. Sourced with $SANDBOX,
# $TRANSCRIPT, PASS/FAIL in scope.

t="$TRANSCRIPT"
assert "separate" "dry-run produced output" "$([[ -s "$t" ]] && echo yes || echo no)" "yes"

# Both workstreams' AC must survive.
assert "separate" "keeps the ingestion AC" \
  "$([[ "$(grep -ciE 'index|ingest|broker' "$t")" -ge 1 ]] && echo yes || echo no)" "yes"
assert "separate" "keeps the query-API AC" \
  "$([[ "$(grep -ciE 'query|/search|401|paginat' "$t")" -ge 1 ]] && echo yes || echo no)" "yes"

# Safety: nothing was actually created (dry run).
assert "separate" "no live creation happened (dry run)" \
  "$([[ "$(grep -ciE 'created TOY-[0-9]|issue created' "$t")" -eq 0 ]] && echo yes || echo no)" "yes"
