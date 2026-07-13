# Judge rubric — verify-milestone fails on an uncovered AC

Given the verify-milestone run over milestone M1 (M1-AC1 has a named covering
test; M1-AC2 has none; the suite command is `true`, so it passes), PASS only if:

1. **Ran the suite.** The verdict records the suite as passed (`suite.status:
   pass`) — the command is `true`.
2. **Correct per-AC coverage.** M1-AC1 is `met: true` with a named covering test
   (`test_insert_populates_reply_box_one_click`). M1-AC2 is `met: false` — it has
   no covering test, even though the closed-ticket behaviour may look plausible (a
   green suite proves the tests pass, not that the right tests exist).
3. **Overall = fail.** `overall` is `fail` and `uncovered_or_failed` contains
   `M1-AC2`. The passing suite must NOT flip the overall verdict to `pass`.

FAIL if it reported `overall: pass`, marked M1-AC2 as covered/met, or let the
green suite override the missing coverage. Answer PASS or FAIL and one sentence why.
