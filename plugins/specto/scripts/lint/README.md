# Specto lint pre-pass library

Mechanical, fast, deterministic checks against the spec guidelines (`references/product-spec-guidelines.md`, `references/engineering-spec-guidelines.md`). The `review-spec` skill runs these before any model-driven review; if lint fails, the model pass is skipped.

## Layout

```text
scripts/lint/
  run-checks.sh                 # generic orchestrator: run-checks.sh <checks-dir> <file>
  product-spec-lint.sh          # shim → run-checks.sh checks.d/product   <file>
  engineering-spec-lint.sh      # shim → run-checks.sh checks.d/engineering <file>
  checks.d/
    product/
      check-metadata-rows.sh    # the four required header metadata rows are present
      check-metric-count.sh     # §1.4 has ≤ 5 metric rows
    engineering/
      check-code-fence.sh       # §3.2 (AI test plan) has a fenced ``` block when it has prose
      check-reversibility.sh    # §4.3 (data-migration reversibility) section present + non-trivial
      check-stakeholder-table.sh# stakeholder/reviewer table, when present, has a data-platform row
  tests/
    run-tests.sh                # bash assert harness — CI runs this on every change to scripts/lint/
    fixtures/                   # read-only spec fixtures (good + one-violation-each)
```

### `run-checks.sh <checks-dir> <file>`

Iterates every executable `check-*.sh` in `<checks-dir>` (sorted), runs each as `<check> <file>`, passes through each failing check's findings, prints a one-line summary, and exits 1 if any check failed. Exit codes: `0` clean, `1` any violation, `2` bad usage / not-a-directory / not-a-file.

### Entry points

- `product-spec-lint.sh <file>` — runs `checks.d/product/`.
- `engineering-spec-lint.sh <file>` — runs `checks.d/engineering/`.

Both are 3-line shims that `exec` into `run-checks.sh`. The `review-spec` skill picks the entry point based on which kind of spec it is reviewing; the Q3=Yes conditionality for `check-stakeholder-table.sh` is decided by the caller (it only routes the spec through eng-lint when appropriate — the check itself just validates table contents when invoked).

## Tests

`tests/run-tests.sh` runs assertions against `tests/fixtures/`. CI should run this on every change to `scripts/lint/`. All asserts pass on a clean checkout.

## Adding a new check

1. Decide which kind it is (`product` or `engineering`) — that's the `checks.d/<kind>/` it lives in.
2. Add a fixture to `tests/fixtures/` (a spec that violates only the new rule, plus reuse the existing `good-*` fixture for the clean case).
3. Add assertions to `tests/run-tests.sh`; run the harness and confirm the new assertions fail.
4. Write `checks.d/<kind>/check-<rule>.sh`: take `<file>` as `$1`, exit `0` on pass / `1` on a violation / `2` on bad usage, print what's wrong to stdout. Mirror the awk section-extraction in `check-metric-count.sh` for section-scoped rules. `chmod +x` it.
5. Run the harness again; confirm the new assertions pass. No orchestrator edit is needed — `run-checks.sh` picks up every executable `check-*.sh` in the directory automatically.
