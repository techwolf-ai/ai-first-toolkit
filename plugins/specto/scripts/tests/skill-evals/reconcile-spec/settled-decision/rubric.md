# Judge rubric — reconcile-spec turns a settled decision into a cited fact

Given the reconcile-spec run over a spec whose §2.3 storage decision is still
`Proposed` / `TODO(eng-approval)` while the branch has shipped the `feature_flags`
approach, PASS only if:

1. **Found the drift.** The plan identifies the §2.3 provisional storage decision
   as stale — it is now settled by the shipped commit.
2. **Proposed the reconciled text.** It proposes turning `Proposed` into a
   settled decision (e.g. "Decision (shipped): `canned_replies_enabled` ships as a
   `feature_flags` JSON entry, no new column"), matching what actually landed.
3. **Evidence-cited, no guessing.** The proposed change cites the shipped evidence
   (the migration commit / file), rather than inventing a resolution. If some item
   had no evidence it would be left open — but this one has clear evidence.
4. **Respects the split & advisory-only.** The engineering fact stays in
   `engineering-spec.md` (not moved to the product spec), and the skill proposes
   the edit for approval rather than rewriting the spec itself.

FAIL if it missed the drift, invented a resolution not backed by the commit, put
the engineering fact in the product spec, or edited the spec without approval.
Answer PASS or FAIL and one sentence why.
