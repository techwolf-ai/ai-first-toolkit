# Skill evals (behavioural lane)

The golden-e2e suite (`../e2e/`) asserts structure over *recorded* output — it
never runs a skill. This lane **runs a skill on a toy example and asserts it did
the right thing**. That needs a live model, so it is:

- **non-deterministic** → each scenario runs N times (default 3), majority must pass;
- **out of CI** → `run-all` does NOT invoke it (only a deterministic `--dry-list`
  shape check guards the scaffolding). Run it nightly or on demand;
- **offline & safe** → evals never touch real Jira/GitLab. Authoring skills run
  pure-local in a sandbox; action skills run `dry_run` / `--from-fixture` only.

## Offline contract (why the runner can skip permissions)

The runner invokes headless `claude -p` with **`--dangerously-skip-permissions`**
(not `--permission-mode acceptEdits`). A headless subagent can't answer a Bash
permission prompt, and `acceptEdits` blocks the vetted plugin helpers
(`epic-fields.sh`, `get-ticket-description.sh`, `mr-fetch.sh`) and the
`$sandbox/bin` stubs — silently degrading a guardian to a fallback read (e.g. a
raw file read instead of `get-ticket-description.sh`). Skipping permissions is safe
**because every scenario is offline by contract**: it either stubs its network
tool (`acli`/`glab`) on `$sandbox/bin` or reads a `--from-fixture` file, and the
sandbox is a throwaway `mktemp` dir with no real credentials. The rule for a new
scenario: **it must never reach a live service — stub it or use a fixture.** A
scenario that reaches a live service is a bug in the scenario.

## Harness improvements

Three techniques borrowed from agent-eval practice,
to close known weaknesses of this lane:

- **Branch-install parity.** The runner loads the *working-tree* specto via
  `--plugin-dir` (not whatever version is installed user-level), so the lane evals
  the code under review. The **loaded plugin version is printed in every report**
  (`[specto v<x>]` on each `SCENARIO` line) so a stale/mismatched result is visible
  rather than silent — the failure mode where an eval quietly grades the installed
  plugin instead of the branch.
- **Different-family judge.** The rubric judge runs on a *different* model than the
  skill under test (default `claude-sonnet-5`, override `SPECTO_EVAL_JUDGE_MODEL`),
  so the grader doesn't share the skill model's blind spots. If your session
  default already *is* that model, set the env var to another family to keep the
  separation.
- **Cost/token accounting.** The skill runs via `--output-format json`; the runner
  extracts `.result` for the checks/judge (unchanged behaviour) and reports
  `total_cost_usd` per run and per scenario (`~$<cost>` on each line).
- **Allow-fence stubs.** A `$sandbox/bin` stub answers only the subcommands it
  *expects* and exits non-zero (`STUB-FORBIDDEN`, code 97) on anything else, rather
  than silently returning a default payload. This gives the offline contract teeth
  (an unexpected call fails loudly) and removes a false-PASS class. Keep the
  expected patterns generous enough not to fence a legitimate call — match the
  subcommand shape (`*workitem*view*`, `*mr*`), not exact arg strings.

## Run it

```bash
# behavioural runs (needs the `claude` CLI + credentials):
SKILL_EVALS=on scripts/tests/skill-evals/run-evals.sh --runs 3
SKILL_EVALS=on scripts/tests/skill-evals/run-evals.sh --only 'new-spec/*' --runs 1

# deterministic shape check (no LLM; this is what CI runs):
scripts/tests/skill-evals/run-evals.sh --dry-list
```

Without `SKILL_EVALS=on`, the `claude` CLI, or credentials, the runner prints
`SKIP` and exits 0 — it never breaks a plain unit run.

## Two dimensions

- **Behaviour** — the scenario dirs below. Each runs the skill and checks the result.
- **Triggering** — `triggering/cases.md`: does each description fire on the right
  prompt and not a neighbour's. Run those through the `skill-creator` skill's eval
  mode (variance analysis on triggering accuracy). No sandbox — descriptions only.

## Limitations (found by smoke-testing the runner)

- **Evals run the *installed* plugin, not the branch under review.** Headless
  `claude -p` loads the user-level specto plugin, so an eval validates whatever
  version is installed — not the working-tree/MR changes. To eval a branch's
  behaviour, install that branch first (local marketplace / branch install) or
  merge it. Until then, a scenario can only exercise new behaviour if the *prompt*
  asks for it explicitly. Scenarios that depend on a **v1-new** skill/agent (e.g.
  `reconcile-spec`, new in the stack) are built to lock behaviour going forward
  but will fail/skip until the branch is installed — each such dir carries a
  `NOTES.md` marking it "needs branch installed". Guardians already in the
  installed base (`scope-review`, `code-mr-review`, `test-critic`, `dod`,
  `plan-to-tickets`) eval the installed behaviour today.
- **Interactive gates can't be observed headlessly.** With no user to answer an
  `AskUserQuestion`, a skill that would normally stop for confirmation (e.g.
  `new-spec` staged drafting) instead drafts in one pass. So headless evals judge
  the *quality* of what's produced (value-first, stakeholder language, bundling,
  no engineering creep), not the interactive gating — that needs an interactive
  harness. Rubrics say which is which.
- **Assert coarse facts in `checks.sh`; judge phrasing in `rubric.md`.** The model
  narrates output as prose/tables, not literal helper calls, so transcript greps
  for exact commands are brittle. Keep `checks.sh` to robust signals (a file
  exists, an AC survives, no live write) and let the LLM judge handle
  count/quality judgements that vary in wording.

## Add a scenario

Create `scripts/tests/skill-evals/<skill>/<scenario>/` with:

- `setup.sh <sandbox>` — build the toy sandbox (seed inputs; for action skills,
  seed `--from-fixture` dirs and make the prompt use dry-run). **Required.**
- `prompt.txt` — the user turn under test. **Required.**
- `checks.sh` — deterministic assertions over the sandbox; sourced with
  `$SANDBOX`, `$TRANSCRIPT`, `assert`, and the `inv_*` predicates in scope.
  **Required.**
- `rubric.md` — optional prose-quality rubric for an LLM judge.

Keep `checks.sh` to robust structural facts; leave judgement calls to `rubric.md`.

## Stubbing a live CLI offline (`$sandbox/bin`)

Some guardians read a source that has **no `--from-fixture` mode** — e.g. `dod`
reads the epic Issue Checklist by shelling out to `acli` directly. To eval that
path offline, `setup.sh` drops a stub executable in **`$sandbox/bin/`** (a fake
`acli`/`glab` that echoes canned fixture JSON), and the runner **prepends
`$sandbox/bin` to `PATH`** for the headless `claude -p` call. The stub shadows the
real binary, so the guardian exercises the real branch without touching a live
service. Keep the stub permissive over the subcommands the guardian might call
(match `auth`/`search`/`view` loosely) and return a payload that plants the defect
under test. See `dod-check/missing-checklist-item/setup.sh` for the pattern.
Scenarios that don't seed `$sandbox/bin` are unaffected — the runner only
prepends the dir when it exists.

### `--from-fixture` helper modes (prefer these over a stub when they exist)

Three vetted helpers read canned JSON offline, so a scenario whose prompt drives
the helper directly needs no `acli`/`glab` stub at all:

- **`get-ticket-description.sh <KEY> --from-fixture <file>`** — the ticket's ADF
  work-item JSON (description + acceptance criteria). Used by `review-mr/*`.
- **`mr-fetch.sh <discussions|info|diff> --from-fixture <dir>`** — reads
  `<dir>/discussions.json` / `info.json` / `diff.json`. Used by
  `resolve-spec-comments/*` (seed `<dir>/discussions.json` with unresolved
  threads) and any MR-anchored reviewer.
- **`epic-fields.sh <epic> --from-fixture <file>`** — raw `acli` epic JSON
  with a `.fields` object (Q1/Q2/Q3 = `customfield_10101/10129/10128`).

Which to use — fixture mode vs `$sandbox/bin` stub — depends on **who** invokes
the tool. When the *prompt* can name the helper with `--from-fixture`, use the
fixture (cleaner, no PATH shadowing). When a **skill** calls the live path
internally (e.g. `change-classification-review` runs `epic-fields.sh <epic>`
with no fixture flag, or `dod-check --mode=epic-creation` runs
`acli … workitem search`), the scenario can't inject a flag — drop an `acli` stub
on `$sandbox/bin` that shadows the real binary and returns the planted fixture.

### Epic-creation DoD stub (two acli subcommands)

`dod-check --mode=epic-creation` reads the epic **and** its children. Its
`$sandbox/bin/acli` stub must answer both `workitem view <epic>` (the epic JSON
with its Issue Checklist `customfield_10107`) **and** `workitem search --jql
"parent = <epic>"` (the child-ticket list, whose summaries/descriptions plant the
coverage gap). See `dod-check/epic-item-no-ticket/setup.sh`.

## Lane-discipline pattern (asserting a *silence*)

A reviewer must stay silent on a **neighbour's** defect while its own lane is
clean — the regression guard for the found lane-leak (scope-review raising an
out-of-lane writing-clarity aside on clean specs). These scenarios seed a spec
that is clean on the reviewer's own axes but carries a defect belonging to a
sibling reviewer's lane, then assert the reviewer emits its **clean sentinel**
(e.g. `no scope issues found`, `[specto:product-review] no findings …`) and no
in-lane finding bullets. Because asserting an absence is inherently rubric-heavy,
`checks.sh` asserts only the clean sentinel + no in-lane bullets; the rubric
judges that the reviewer did not stray into the neighbour's lane. See
`scope-review/ignores-writing-nit/` and `product-review/ignores-scope-blur/`.

## Planted-defect guardian pattern

Most scenarios here follow one shape: **seed a fixture with a known defect, run
the guardian offline, assert it catches that defect** — plus a **negative-control**
clean fixture that must produce no finding (the false-positive guard). `checks.sh`
greps the guardian's stable finding markers (`[finding-type]`, `✗`, `### <axis>`,
`[specto:…]` prefixes, the `no … found` sentinels); the rubric judges detection
quality and low false positives. Network-touching guardians run in collect /
dry-run / `--from-fixture` mode; the one source without a fixture mode (`dod`'s
epic checklist) uses the `$sandbox/bin` stub above.

**Negative controls for *adversarial* guardians.** `test-critic` is adversarial by
design — on any diff it will surface *some* beyond-spec edge case (empty string,
whitespace, overflow) as a `✗`. A negative control that asserts "zero `✗`" is
therefore unwinnable and will flap. Frame the false-positive guard as **"no
*in-scope* (spec-named) case flagged"** instead: seed a fixture that covers every
case the spec section names, keep `checks.sh` to "the report ran + a Summary line",
and let the rubric judge that the spec-named cases are all ✓ while explicitly
tolerating beyond-spec extras. Same lesson for prose guardians (`scope-review`): a
clean-spec control should fail on a fabricated *in-lane* finding, not on a stray
out-of-lane aside (writing-clarity remarks are `product-review`'s lane, not scope).
