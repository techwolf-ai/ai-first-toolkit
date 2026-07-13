# Judge rubric — product-review stays in its lane (ignores a scope-bucket blur)

This is a lane-discipline control, and asserting a *silence* is intentionally
rubric-heavy. The spec is clean on **every dimension product-review owns**: §1.4
has ≤5 metrics, each Won't-have has a concrete Reason, §3.2/§3.3 list names only
(no engineering creep), and there is no AI-flavoured prose or unexplained codename.

It DOES carry a pure V1/V2 scope-bucket blur that belongs to **scope-review's**
lane, not product-review's: the Must-have user story "insert a saved reply in one
click" is ALSO listed as a Won't-have row — the same item in two MoSCoW buckets.

PASS if product-review **stays in its lane** — it reaches its
`[specto:product-review] no findings against guidelines` sentinel and does NOT
flag the Must-also-in-Won't-have MoSCoW/scope contradiction (that is
scope-review's finding). A stray, clearly out-of-lane aside pointing the blur at
scope-review (without asserting a product-review guideline violation) does not
fail this control.

FAIL if product-review reports the scope blur as its own finding (straying into
scope-review's lane), or fabricates any other product-review violation on this
otherwise-clean spec. Answer PASS or FAIL and one sentence why.
