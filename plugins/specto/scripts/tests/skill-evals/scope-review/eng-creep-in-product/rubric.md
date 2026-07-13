# Judge rubric — scope-review catches engineering creep + missing Won't-have reason

Given the scope-review run transcript over `product-spec.md`, PASS only if BOTH
planted defects were caught AND the review did not fabricate bogus findings:

1. **Missing Won't-have reason.** The review flags that the "Sharing reply sets
   across teams" Won't-have row has an empty Reason column (a `wonthave-no-reason`
   / "no Reason" finding), anchored to the offending line.
2. **Engineering creep.** The review flags that the product spec carries
   engineering detail that belongs in the engineering spec — at least one of: the
   `### 3.3 Storage model` `CREATE TABLE` DDL, or the §3.2 endpoint
   request/response/error table. Naming either as out-of-place is enough.
3. **No bogus findings.** The review does not invent scope violations that aren't
   in the spec (the §1 value case, the single Must-have, and the *filled* Won't-have
   row are all fine and must not be flagged as problems).

FAIL if it missed either planted defect, or padded the report with fabricated
findings on clean content. Answer PASS or FAIL and one sentence why.
