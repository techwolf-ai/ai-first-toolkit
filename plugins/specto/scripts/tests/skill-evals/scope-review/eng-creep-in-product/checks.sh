# Deterministic checks for the scope-review engineering-creep + wonthave-no-reason
# eval. Sourced by run-evals.sh with $SANDBOX, $TRANSCRIPT, PASS/FAIL, and the
# inv_* predicates in scope. Keep asserts to STABLE markers — the crisp planted
# defect (the Won't-have with no Reason) and the collect-format structure. The
# nuanced "also caught the engineering creep, and no bogus findings" judgement is
# the rubric's job (phrasing varies: schema/DDL/endpoint-table/belongs-in-eng-spec).

t="$TRANSCRIPT"
assert "scope-creep" "review produced output" "$([[ -s "$t" ]] && echo yes || echo no)" "yes"

# The scope-review guardian emits structured findings (collect format: a `### §`
# group with `- **[finding-type] line N**` bullets). Tolerate light phrasing drift.
assert "scope-creep" "emitted structured scope findings" \
  "$([[ "$(grep -cE '###[[:space:]]*§|-[[:space:]]+\*\*\[[a-z-]+\]' "$t")" -ge 1 ]] && echo yes || echo no)" "yes"

# Planted defect #1 — the empty-Reason Won't-have. This is the crisp, stable
# category the agent names verbatim in its collect example.
assert "scope-creep" "flagged the Won't-have with no Reason" \
  "$([[ "$(grep -ciE 'wonthave-no-reason|no reason' "$t")" -ge 1 ]] && echo yes || echo no)" "yes"

# It must NOT declare the spec clean (there are real violations).
assert "scope-creep" "did not emit the clean sentinel" \
  "$([[ "$(grep -ciE 'no scope issues found' "$t")" -eq 0 ]] && echo yes || echo no)" "yes"

# Planted defect #2 (engineering creep) is judged by rubric.md, not grepped here.
