# Judge rubric — product-review catches AI-flavoured prose + an unexplained codename

Given the product-review run over `product-spec.md`, PASS only if it flags **at
least one** of the two planted product-review-owned defects (ideally both):

1. **AI-flavoured prose.** The §1.1 problem statement is flowery, marketing-toned
   filler ("game-changing… empowers… seamless, best-in-class… delight customers at
   scale… transformative operational synergies") that states no concrete problem —
   the "AI-flavoured prose" anti-pattern. The review flags it and recommends a
   concrete rewrite.
2. **Cold-reader gap.** "This ships as part of Project Cormorant" references an
   unexplained internal codename a reader without the author's context cannot
   follow — a `cold-reader-gap`. The review flags it and asks for a one-line
   explanation or removal.

Both are product-review's lane (anti-patterns table + cold-reader check), not
scope-review's or OKR's. Tolerate other in-lane findings. FAIL if it flagged
neither planted defect, or reached the "no findings" sentinel on this spec. Answer
PASS or FAIL and one sentence why.
