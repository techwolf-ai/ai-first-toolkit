# Per-scenario extra assertions for the 'matching-employees' golden scenario.
# Sourced by ../../run-tests.sh inside the golden loop, where $scen (this
# scenario dir), $name, `assert`, and the inv_* predicates are already in scope.
#
# Ticket-body invariants: every rendered ticket description plan-to-tickets
# produces must carry spec-section traceability, acceptance criteria, and its
# dependency edges.
for _t in "$scen"/tickets/*.md; do
  [[ -f "$_t" ]] || continue
  _tn="$(basename "$_t")"
  assert "golden:$name:ticket" "$_tn carries a spec-section link"   "$(inv_has "$_t" '^> Spec section:'      && echo ok || echo bad)" "ok"
  assert "golden:$name:ticket" "$_tn carries acceptance criteria"   "$(inv_has "$_t" 'Acceptance criteria'    && echo ok || echo bad)" "ok"
  assert "golden:$name:ticket" "$_tn declares Blocks/BlockedBy edges" "$(inv_has "$_t" 'Blocks:|BlockedBy:'   && echo ok || echo bad)" "ok"
done
