# Judge rubric — test-critic flags the right uncovered edge case

Given the test-critic report over the `parse_page_size` diff (which ships only a
happy-path test), PASS only if:

1. **Flagged a real gap.** The report marks at least one genuinely uncovered
   edge case among the ones the spec §2.1 names: the `None`/required-input error
   path, the boundary rejections (0, negative, > 100), or non-integer input.
2. **Right target.** The flagged gap corresponds to behaviour actually in the
   diff and left untested — not a fabricated case, and not the happy path (which
   IS tested and should be marked covered).

FAIL if it declared coverage adequate, invented an out-of-scope gap, or flagged
the tested happy path as uncovered. Answer PASS or FAIL and one sentence why.
