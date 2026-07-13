# Not a pure offline read (runs a suite)

Unlike the prose guardians in this lane (which only read a spec/diff/fixture),
`verify-milestone` **executes the milestone's `test_command`**. So this scenario
needs a runnable command — here a trivial passing `true` in `.specto/config.yml`
— rather than being a pure `--from-fixture` read. It is included to give
**behavioural** milestone coverage (does the verdict correctly fail on an AC with
no covering test?), not just golden-shape coverage.

The planted defect is coverage, not a red suite: the suite passes (`true`), but
`M1-AC2` has no covering test, so the verdict must be `overall: fail` with `M1-AC2`
in `uncovered_or_failed` — a green suite proves the tests pass, not that the right
tests exist (same principle as `test-critic`).

Still offline-safe: `true` reaches no network, and the sandbox is a throwaway dir.
