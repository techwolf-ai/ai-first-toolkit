# End-to-end structural invariants (golden fixtures)

Skills are LLM-driven, so their output can't be reproduced deterministically in
CI. This suite instead asserts **mechanically-checkable structure** over:

1. **Fixtures** (`fixtures/`) — good/bad specs used to prove each invariant both
   holds on well-formed output *and* fires on broken output (non-vacuous).
2. **Golden scenarios** (`golden/<name>/`) — snapshots of a real skill run,
   captured once and asserted against on every CI run.

The CI gate is deterministic: no model runs here. Judgment-level checks (does it
read well, scope-review's engineering-creep call) stay with the LLM review
agents — this suite only covers what a grep can decide.

## Layout

```
e2e/
  run-tests.sh                 # the suite (run by scripts/tests/run-all.sh)
  capture.sh                   # snapshot a real spec folder into golden/<name>/
  lib/invariants.sh            # pure structural predicates (exit 0 = holds)
  fixtures/                    # good/bad specs for the non-vacuous self-tests
  golden/<name>/
    spec/product-spec.md
    spec/engineering-spec.md
    spec/.specto-meta.yml
    plan.md
    tickets/*.md               # rendered ticket bodies
    assert-extra.sh            # per-scenario extra assertions (optional)
    MANIFEST
```

## Invariants checked

- **product-spec:** §1 Value before §2 before §3; §1 present; MoSCoW present; no
  engineering content (SQL/DDL, `customfield_`, storage-model / endpoint-contract
  headings).
- **engineering-spec:** §1 before §2 before §3; §2.1 Architecture, §3.1 coverage,
  §4 Rollback, §6 Design decisions all present.
- **tickets:** each rendered body carries a `> Spec section:` link, acceptance
  criteria, and its Blocks/BlockedBy edges.

## (Re)capturing a golden scenario

Whenever a skill's output shape intentionally changes, re-capture from a real
run so the golden reflects reality:

```bash
scripts/tests/e2e/capture.sh <scenario-name> \
  --spec-folder docs/development/specs/<slug> \
  --plan .specto/plan.md
```

Volatile fields (git SHAs in `> Spec section:` permalinks, timestamps, the source
folder's absolute path) are normalized on capture so re-captures diff cleanly.
Review the diff, then commit the updated `golden/<name>/`.
