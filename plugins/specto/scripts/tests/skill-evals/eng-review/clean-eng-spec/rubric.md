# Judge rubric — eng-review negative control (clean eng-spec, no fabricated findings)

This is a false-positive guard. The engineering spec is well-formed on **every
dimension eng-review owns**: §2.1 has both a structural diagram and a
`sequenceDiagram` for the multi-actor flow; §2.3 storage is explicit and anchored
to the `console/AGENTS.md` `feature_flags` convention (no new column → no
convention-conflict, no over-specified decision); §2.6 endpoint contract is
filled; the in-scope test-plan sections are filled and the out-of-scope ones are
one-line `*Not applicable*`; §6 follows the Proposed/Rationale/Open-question/
Decision pattern.

PASS if the review raises **no fabricated finding** — it reaches the
`[specto:eng-review] no findings against guidelines` sentinel (ideal), or at most
makes a clearly out-of-lane aside (scope, classification, or product content —
other agents' lanes) that it does not present as an eng-review guideline
violation.

FAIL only if the review fabricates a concrete eng-review guideline violation on
this clean spec (e.g. claims the sequence diagram is missing, invents a
convention-conflict, or flags a correctly-marked `*Not applicable*` section as a
gap). Answer PASS or FAIL and one sentence why.
