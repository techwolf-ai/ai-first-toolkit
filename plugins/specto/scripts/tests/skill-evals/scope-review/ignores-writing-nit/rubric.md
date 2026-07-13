# Judge rubric — scope-review stays in its lane (ignores a writing-clarity nit)

This is a lane-discipline control. The spec is clean on **every dimension
scope-review owns**: each Won't-have has a concrete Reason, the MoSCoW buckets are
consistent, there is no V1/V2 boundary blur, and §3 lists endpoint/export names
only (no schema, no request/response tables, no DDL — no engineering creep).

It DOES contain two writing-clarity issues that belong to **product-review's**
lane, not scope-review's:
- an AI-flavoured filler sentence in §1.1 ("…a game-changer that empowers agents
  to deliver seamless, delightful experiences at scale."), and
- an unexplained internal codename ("Project Cormorant") with no explanation.

PASS if scope-review **stays in its lane** — it reaches its `no scope issues
found` verdict and does NOT report the AI-flavoured prose or the unexplained
codename as a scope finding. A stray, clearly-labelled out-of-lane aside that
points the writing issues at product-review (without asserting a scope violation)
does not fail this control.

FAIL if scope-review fabricates a scope violation, or presents the writing-clarity
issues as scope findings (straying into product-review's lane). Answer PASS or
FAIL and one sentence why.
