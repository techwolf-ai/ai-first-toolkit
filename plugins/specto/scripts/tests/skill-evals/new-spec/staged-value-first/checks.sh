# Deterministic checks for the staged value-first drafting eval.
# Sourced by run-evals.sh in a subshell with $SANDBOX, $TRANSCRIPT, PASS/FAIL,
# and the inv_* predicates in scope. The nuanced "stopped at the value gate"
# judgement is left to rubric.md; here we assert robust structural facts.

spec="$(find "$SANDBOX" -name product-spec.md -print -quit 2>/dev/null)"
assert "staged" "product-spec.md was written" "$([[ -n "$spec" ]] && echo yes || echo no)" "yes"
[[ -n "$spec" ]] || return 0

assert "staged" "§1 Value section present"        "$(inv_has "$spec" '^## 1\.'   && echo ok || echo bad)" "ok"
assert "staged" "§1.1 Problem drafted"            "$(inv_has "$spec" '^### 1\.1'  && echo ok || echo bad)" "ok"
# Value-first ordering, when §2 exists at all.
if inv_has "$spec" '^## 2\.'; then
  assert "staged" "§1 Value before §2 requirements" "$(inv_order_ok "$spec" '^## 1\.' '^## 2\.' && echo ok || echo bad)" "ok"
fi
# The product spec must never carry engineering content.
assert "staged" "no engineering content in product spec" \
  "$(inv_lacks "$spec" '```sql|CREATE TABLE|customfield_[0-9]|^### .*Storage model' && echo ok || echo bad)" "ok"
