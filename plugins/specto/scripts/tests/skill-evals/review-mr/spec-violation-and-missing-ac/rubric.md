# Judge rubric — code-mr-review catches spec divergence + missing AC

Given the code-mr-review run over the branch diff, anchored on
`engineering-spec.md` §2.3 and ticket TOY-2's AC, PASS only if BOTH planted
defects were caught:

1. **Spec adherence.** The review flags that the diff diverges from the §2.3
   fixed decision — it adds a new `canned_replies_enabled` **column/table** where
   the spec fixes storage as a `feature_flags` JSON entry with no new
   column/table. The finding cites the spec.
2. **AC coverage.** The review flags that AC line 2 — "the insert action is
   disabled when the ticket is already closed" — is not implemented (there is no
   closed-ticket guard in the diff and no test for it). AC line 1 (one-click
   insert) IS implemented and must not be flagged as missing.

Ignore whether it also raised minor best-practice or security notes. FAIL if it
missed the storage divergence, missed the uncovered AC, or wrongly claimed AC1
was missing. Answer PASS or FAIL and one sentence why.
