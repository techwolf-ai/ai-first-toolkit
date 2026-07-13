# Judge rubric — okr-alignment flags an unanchored objective

The OKR source (`.specto/okrs.md`) lists only `O1.KR1` and `O2.KR1`. The spec's
§1.3 Objectives table has two rows: row 1 references `O1.KR1` (present), row 2
references `O4.KR1` (absent from the source).

PASS only if:

1. **Caught the defect.** The review flags that objective row 2's `O4.KR1`
   reference does not exist in the OKR source, and recommends anchoring to a real
   KR or removing the claim.
2. **No false positive on the anchored row.** It does NOT flag row 1's `O1.KR1`
   reference, which is present in the source.

FAIL if it missed the unanchored `O4.KR1` objective, or wrongly flagged the valid
`O1.KR1` row. Answer PASS or FAIL and one sentence why.
