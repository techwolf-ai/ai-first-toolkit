# Deterministic checks for the same-theme bundling eval.
# The dry-run prints one block per proposed ticket (a create-ticket.sh invocation
# + the description body). Bundling worked when there is exactly ONE proposed
# ticket that still carries BOTH tasks' acceptance criteria. Sourced with
# $SANDBOX, $TRANSCRIPT, PASS/FAIL in scope. Best-effort over free-form output;
# rubric-level judgement can back it up.

t="$TRANSCRIPT"
assert "bundle" "dry-run produced output" "$([[ -s "$t" ]] && echo yes || echo no)" "yes"

# Both tasks' AC must survive (granularity preserved), not be collapsed away.
assert "bundle" "keeps the rename AC"  "$([[ "$(grep -ciE 'feature_foo|foo_flag' "$t")" -ge 1 ]] && echo yes || echo no)" "yes"
assert "bundle" "keeps the default AC" "$([[ "$(grep -ciE 'default|false' "$t")" -ge 1 ]] && echo yes || echo no)" "yes"

# Safety: nothing was actually created (dry run).
assert "bundle" "no live creation happened (dry run)" "$([[ "$(grep -ciE 'created TOY-[0-9]|issue created' "$t")" -eq 0 ]] && echo yes || echo no)" "yes"

# "Exactly ONE ticket bundling both (not two separate)" is a phrasing-sensitive
# judgement — the LLM narrates the dry-run as a table/prose, not a literal
# create-ticket.sh call. That assertion lives in rubric.md (the judge), not a
# brittle grep here.
