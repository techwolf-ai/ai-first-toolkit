# Judge rubric — value-first drafting

Given the drafted `product-spec.md` and the run transcript, PASS only if BOTH hold:

1. **Value case in stakeholder language.** Section 1 states the problem, who it is
   for, and the value it brings, in language a PM/EM understands — no engineering
   detail (no schema, endpoints, algorithms, storage).
2. **Value leads.** The spec opens with the value case (§1) before user stories /
   functional requirements — the reader meets *why* before *what*.

FAIL if §1 is thin/placeholder, carries engineering detail, or the spec leads
with requirements before establishing value. Answer PASS or FAIL and one sentence.

> Note: the interactive *gate* (drafting §1, then stopping to confirm before §2/§3)
> cannot be observed in a headless run — there is no user to confirm, so the skill
> drafts in one pass. Gating behaviour is validated by interactive testing, not
> this eval. This rubric judges the value-first *quality* that a headless run can show.
