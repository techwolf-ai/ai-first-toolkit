# Specto helper tests

Every helper domain ships a self-contained bash test suite that runs offline
(`--from-fixture` fixtures and mocked-`glab`/`acli` on `PATH` — no network, no
credentials, no live GitLab/Jira).

## Running everything

```bash
bash scripts/tests/run-all.sh
```

`run-all.sh` is the aggregate entry point CI runs on every MR. It runs the
top-level config suite plus every `scripts/<domain>/tests/run-tests.sh`, prints
each suite's result, and exits non-zero if **any** suite fails.

## Running one suite

Each suite is independently runnable while you work on that domain:

```bash
bash scripts/forge/gitlab/tests/run-tests.sh
bash scripts/tracker/jira/tests/run-tests.sh
bash scripts/lint/tests/run-tests.sh
bash scripts/conventions/tests/run-tests.sh
bash scripts/mdreview/tests/run-tests.sh
bash scripts/tests/config-suite.sh          # plugin-config.sh
```

## Layout

- `run-all.sh` — aggregate runner (CI entry point).
- `config-suite.sh` — suite for the cross-cutting `scripts/plugin-config.sh`.
- `lib/assert.sh` — shared assertion helpers (`assert`, `assert_exit`, `assert_summary`).
- `e2e/` — end-to-end structural-invariant suite over spec/ticket artifacts,
  driven by golden fixtures. See `e2e/README.md` (and `e2e/capture.sh` to record
  a golden from a real run).
- Domain suites live next to the code they test, at `scripts/<domain>/tests/run-tests.sh`.

CI is defined at the repo root `.gitlab-ci.yml` (`specto-tests` job, scoped to
`plugins/specto/**` changes).
