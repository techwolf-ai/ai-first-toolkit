# Judge rubric — test-critic negative control (spec-named cases covered)

Given the test-critic report over the `parse_page_size` diff whose tests now cover
**every edge case the spec §2.1 names** — a missing (None) required value, a
non-integer, a negative, 0 (below the lower bound), exactly 1 (lower boundary
accepted), exactly 100 (upper boundary accepted), and 101 (above the upper bound):

PASS if **no in-scope, spec-named case is flagged as uncovered** — i.e. each of
the cases above is marked covered (✓), because each has an asserting test in the
diff.

test-critic is adversarial by design, so it MAY additionally raise a **beyond-spec**
edge case that §2.1 does not name (empty string `""`, whitespace, integer
overflow, float-like `"1.5"`, etc.) as a `✗` or `?`. That is the critic doing its
job on cases outside this spec's contract — it does **not** count as a false
positive and must **not** fail this control on its own.

FAIL only if the report flags one of the spec-§2.1-named cases (None, negative,
0, the 1/100 boundaries, 101, non-integer) as uncovered when the diff clearly
tests it. Answer PASS or FAIL and one sentence why.
