# Judge rubric — dod catches a missing epic-checklist item

Given the dod-check ticket-level run over branch `f-canned-replies` (epic TOY-1's
Issue Checklist supplied via the acli stub), PASS only if:

1. **Read the checklist.** The report reflects the epic Issue Checklist source —
   it did not silently skip source #1 (the stub returned it, so a
   "checklist not readable" note would be wrong here).
2. **Caught the gap.** It marks at least one checklist item as missing/unsatisfied
   — specifically the "enablement docs written under docs/" item and/or the
   "rollback / downgrade path documented" item, neither of which the branch diff
   satisfies. The "unit tests added" item IS satisfied (the diff adds a test) and
   should be marked done, not missing.
3. **Not-done verdict.** The overall conclusion is that the branch is NOT yet
   done / not ready for review (there are outstanding DoD items), rather than a
   clean pass.

FAIL if it reported a clean pass, claimed the checklist was unreadable, or marked
the satisfied unit-tests item as missing. Answer PASS or FAIL and one sentence why.
