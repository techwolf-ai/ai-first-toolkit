# Judge rubric — scope-review negative control (clean spec, no fabricated scope findings)

This is a false-positive guard. The spec is well-formed on **every dimension
scope-review owns**: each Won't-have has a concrete Reason, the MoSCoW buckets are
consistent, there is no V1/V2 boundary blur, and §3 lists endpoint/export names
only (no schema, no request/response tables, no DDL — no engineering creep).

PASS if the review raises **no fabricated scope violation** — that is, it does NOT:
- flag a Won't-have as missing a Reason (all have concrete ones),
- invent a MoSCoW inconsistency or a V1/V2 boundary problem,
- claim engineering creep (there is none), or
- otherwise assert a scope violation that is not actually present.

Reaching the `no scope issues found` verdict is the ideal. A stray, clearly
out-of-lane remark about writing clarity or naming (that is `product-review`'s
concern, not scope) does NOT count as a scope false-positive and should not fail
this control on its own.

FAIL only if the review fabricates a concrete SCOPE violation on this clean spec.
Answer PASS or FAIL and one sentence why.
