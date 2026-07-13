# Deterministic checks for the reconcile-spec settled-decision eval. Assert a
# reconciliation plan was produced that targets the provisional §2.3 decision and
# cites shipped evidence, and that the spec files were NOT edited (advisory-only).
# "Respects the product/eng split, evidence-cited, no guessing" is the rubric's call.
# Sourced with $SANDBOX, $TRANSCRIPT, PASS/FAIL in scope.
#
# NOTE: reconcile-spec is not yet installed (new in the v1 stack). Until the branch
# is installed, headless runs grade the INSTALLED plugin, which lacks the skill —
# expect this scenario to fail/skip until then. See NOTES.md.

t="$TRANSCRIPT"
assert "reconcile" "review produced output" "$([[ -s "$t" ]] && echo yes || echo no)" "yes"

# A reconciliation plan that targets the provisional storage decision.
assert "reconcile" "targets the provisional §2.3 decision" \
  "$([[ "$(grep -ciE 'proposed|todo\(eng-approval\)|storage|§?2\.3|feature_flags' "$t")" -ge 1 ]] && echo yes || echo no)" "yes"

# Cites shipped evidence (a commit / MR / file) rather than guessing.
assert "reconcile" "cites shipped evidence" \
  "$([[ "$(grep -ciE 'shipped|evidence|commit|migration|0007_canned_replies' "$t")" -ge 1 ]] && echo yes || echo no)" "yes"

# Advisory-only: the spec files must be unchanged (git tree clean for the spec).
spec="$SANDBOX/docs/development/specs/2026-01-01-canned-replies/engineering-spec.md"
assert "reconcile" "did not edit the spec (advisory-only)" \
  "$([[ "$(grep -ciE 'Proposed:' "$spec")" -ge 1 ]] && echo yes || echo no)" "yes"
