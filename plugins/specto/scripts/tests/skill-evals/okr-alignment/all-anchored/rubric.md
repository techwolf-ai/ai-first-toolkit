# Judge rubric — okr-alignment negative control (all objectives anchor)

This is a false-positive guard. Both §1.3 objectives reference KRs that exist in
the OKR source (`O1.KR1` and `O2.KR2` are both listed in `.specto/okrs.md`).

PASS if the review raises **no fabricated finding** — it reaches the
`[specto:okr-alignment-review] all §1.3 objectives anchor to OKRs in <source>`
sentinel.

FAIL only if it fabricates an `okr-not-found` on an objective whose KR reference
is actually present in the source (e.g. wrongly claims `O2.KR2` is missing).
Answer PASS or FAIL and one sentence why.
