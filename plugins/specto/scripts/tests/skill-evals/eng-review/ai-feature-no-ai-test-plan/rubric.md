# Judge rubric — eng-review catches a missing AI test plan on an AI feature

Given the eng-review run over `engineering-spec.md`, PASS only if:

1. **Caught the defect.** The review flags that the spec header declares this an
   AI feature (**AI feature = YES**) but §3.2 (AI test plan) is absent — the
   applicability matrix requires it to be filled (eval set, accuracy threshold,
   regression gate). It recommends filling §3.2, not marking it not-applicable.
This is a **detection** scenario, not a false-positive control (its paired
`clean-eng-spec` control owns that). So judge it on the core catch above and
**tolerate incidental additional findings** — the review may also raise other
eng-review notes (e.g. on §2.3 storage), and that does not fail this scenario as
long as the missing AI test plan is caught and correctly attributed.

FAIL only if it missed the missing AI test plan, or wrongly accepted the AI
feature as needing no §3.2. Answer PASS or FAIL and one sentence why.
