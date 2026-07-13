# Specto — agent guide

Before shipping any change to the Specto plugin, run the test suite and confirm it
is green. "Shipping" = opening or updating an MR, marking one ready, or claiming a
feature done.

## Run the tests before you ship

From `plugins/specto/`:

```bash
bash scripts/tests/run-all.sh
```

This is the single entry point CI runs on every MR (root `.gitlab-ci.yml` →
`specto-tests`, python:3.12-slim). It must report **all suites passed** before you
open, update, or mark an MR ready. It runs the config suite, every
`scripts/<domain>/tests/run-tests.sh`, and the golden-e2e structural suite —
including the deterministic `--dry-list` shape check for the behavioural
skill-eval lane. A per-domain runner (`scripts/<domain>/tests/run-tests.sh`) is
independently runnable while you iterate on one area.

Do not claim the change is done until `run-all.sh` is green.

## Behavioural skill-evals (when you change a skill or agent's behaviour)

`run-all.sh` only checks that eval scenarios are *well-formed*; it does not run
them. The behavioural lane runs a skill against a live model, so it is
non-deterministic and kept out of CI. When you add or change what a skill or agent
*does*, exercise it:

```bash
SKILL_EVALS=on scripts/tests/skill-evals/run-evals.sh --only '<skill>/*' --runs 3
```

And add or update a scenario for the new behaviour — a
`scripts/tests/skill-evals/<skill>/<scenario>/` dir with `setup.sh` +
`prompt.txt` + `checks.sh` + `rubric.md`. Keep `checks.sh` to stable markers; put
count/quality judgements in `rubric.md`. Scenarios are offline by contract: stub
`acli`/`glab` on `$sandbox/bin` or use `--from-fixture`; a scenario must never
reach a live service. See `scripts/tests/skill-evals/README.md`.
