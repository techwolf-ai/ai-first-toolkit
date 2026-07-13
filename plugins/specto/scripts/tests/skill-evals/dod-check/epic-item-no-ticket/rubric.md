# Judge rubric — dod (epic-creation) catches an uncovered checklist item

Given the `dod-check --mode=epic-creation` run over epic TOY-1 (Issue Checklist
supplied via the acli stub; child tickets TOY-2 / TOY-3 supplied via the acli
`workitem search` stub), PASS only if:

1. **Read both sources.** The report reflects the epic Issue Checklist (source #1)
   and surveys the epic's child tickets (TOY-2, TOY-3) — it did not silently skip
   the checklist read.
2. **Caught the gap.** It marks the "Write enablement docs under docs/" checklist
   item as **uncovered** — no child ticket references it (TOY-2 is the insert
   endpoint, TOY-3 is unit tests; neither mentions enablement docs).
3. **Correct on the covered item.** It marks "Add unit tests for the changed
   code" as **covered** by TOY-3 (whose summary/description reference unit tests),
   not uncovered.
4. **Report-only.** It does not create or edit any ticket; it recommends adding a
   ticket / extending an AC / noting the exception on the epic.

FAIL if it reported full coverage, claimed the checklist was unreadable, or marked
the covered unit-tests item as uncovered. Answer PASS or FAIL and one sentence why.
