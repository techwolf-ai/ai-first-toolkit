# Judge rubric — resolve-spec-comments clusters + classifies spec-MR feedback

Given the resolve-spec-comments run over the three unresolved threads (read from
`./mrfix/discussions.json`), PASS only if:

1. **Clustered.** It produced a revision plan with the documented per-cluster
   shape — `## Cluster <N>: <section> …` with `Threads:`, `Authors:`, `Crux:`, and
   a `Recommended action:` for each.
2. **Classified into the 7 buckets.** Each thread is placed in exactly one of:
   `suggestion`, `question`, `decision-request`, `disagreement`, `style-nit`,
   `out-of-scope`, `bug`. The three seeded threads should land close to:
   the em-dash/formatting note → `style-nit`; the "adoption threshold needs PM
   sign-off" note → `decision-request`; the "factually wrong … fix the statement"
   note → `bug`. Minor bucket disagreement is tolerable; wholesale
   misclassification (e.g. calling the factual error a style-nit) is not.
3. **Advisory only.** It did NOT resolve any thread and did NOT edit the spec file
   — it produced a plan/recommendations for the author to execute selectively.

FAIL if it skipped clustering, produced no classification, or took an action
(resolved a thread / edited the spec) that the advisory-only default forbids.
Answer PASS or FAIL and one sentence why.
