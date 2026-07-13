# Judge rubric — code-mr-review respects an implementer's-choice harness

This is a negative control for guidelines principle 9 ("respect granted freedom").
Spec §2.4 marks the reply-text cache an `*Implementer's choice — must satisfy:*`
harness with three verifiable criteria: (a) correct text by id, (b) invalidated on
edit, (c) no new DB table/column. The diff picks a valid but different
implementation — an in-process LRU keyed by reply id, cleared on edit, no new
table — that MEETS all three, with a test asserting (a) and (b).

PASS only if code-mr-review:

1. **Verified the criteria, did not litigate the choice.** It treats §2.4 as a
   granted implementer's choice, checks that the diff satisfies criteria (a)/(b)/(c),
   and raises **no spec-adherence finding** faulting the chosen LRU implementation
   for being "different from the spec" — the spec fixed criteria, not a mechanism.

FAIL if it raises a spec-adherence finding litigating the implementation (e.g.
"the spec didn't specify an LRU" / "should use a different cache"), i.e. an "I'd
have built it differently" finding. Minor unrelated notes do not fail it, as long
as the implementation choice itself is not faulted. Answer PASS or FAIL and one
sentence why.
