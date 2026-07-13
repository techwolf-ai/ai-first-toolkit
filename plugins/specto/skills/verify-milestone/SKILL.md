---
name: verify-milestone
description: Use to verify a whole milestone is actually done — the test suite passes AND every acceptance criterion the milestone promised is met and covered by a named test. Triggers on "verify M1", "is this milestone done", "check milestone acceptance", "verify-milestone". Reads the milestone's AC from the linked spec sections, runs the suite, and emits a machine-readable verdict (schema: references/milestone-verdict.schema.json). Read-only — never edits code or tickets.
---

# verify-milestone

Per-ticket DoD can all pass while the milestone as a whole misses its intent. This skill checks the milestone: the suite is green **and** each acceptance criterion the milestone promised is met and named to a covering test. It emits a verdict `run-epic` and the author gate on.

Read-only: it runs tests and reads the spec/diff. It never writes code, tests, or Jira.

## Inputs the skill resolves

- **Milestone id** `M<n>` — from the user, or the `specto:milestone-<n>` label on the epic's tickets.
- **Milestone AC** — the acceptance criteria tagged to the milestone: `M<n>-AC<k>` (behavioural) and `M<n>-TAC<k>` (test) lines in the linked `product-spec.md` / `engineering-spec.md`, plus any per-ticket AC labelled to the milestone.
- **Test command** — from `.specto/config.yml` `test_command` (or `plugin-config.sh get test_command`); the milestone's tests must be runnable.

## Steps

1. **Collect the milestone AC.** Gather every `M<n>-AC*` / `M<n>-TAC*` from the specs and the AC of tickets carrying the `specto:milestone-<n>` label. If none resolve, stop and say the milestone has no acceptance criteria to verify.
2. **Run the suite.** Run the milestone's test command. Record `suite.status` (`pass`/`fail`/`skipped`) and the command.
3. **Check each AC.** For each criterion, decide `met` (true/false) from the code + a passing test, and name the **covering test(s)** — the specific test id/path that exercises it. An AC with no covering test is `met: false` even if the behaviour appears present (a green suite proves the tests pass, not that the *right* tests exist — this mirrors `test-critic`).
4. **Emit the verdict.** Print JSON conforming to `references/milestone-verdict.schema.json`: `milestone`, `suite`, `acceptance_criteria[]` (id, met, covering_tests, note), `overall` (`pass` only when the suite passed and every AC is met+covered), and `uncovered_or_failed[]` (the AC ids blocking `pass`).

## Hard rules

- **Read-only.** Never edit code, tests, or tickets. Uncovered AC are *reported*, not fixed here (that's `implement-ticket` / `implement-milestone`).
- **Covering test required.** `met` demands a named test, not just visible behaviour.
- **Deterministic verdict shape.** The JSON validates against the schema; the same milestone + code produce the same verdict.

## When this skill should NOT run

- On a single ticket (use `dod-check` ticket-level).
- To *do* the work (that's `implement-milestone`); this only judges it.
