#!/usr/bin/env bash
# Behavioural skill-eval runner — the LLM lane.
#
# Unlike the golden-e2e suite (which asserts structure over *recorded* output),
# this actually RUNS a skill on a toy example and asserts it did the right thing.
# That needs a live model, so it is non-deterministic and NOT part of `run-all` /
# CI. Run it nightly or on demand.
#
#   SKILL_EVALS=on scripts/tests/skill-evals/run-evals.sh [--runs N] [--only <glob>]
#   scripts/tests/skill-evals/run-evals.sh --dry-list        # deterministic; no LLM
#
# A scenario is a directory scripts/tests/skill-evals/<skill>/<scenario>/ with:
#   setup.sh    <sandbox>   builds the toy sandbox (seeds inputs / fixtures)   [required]
#   prompt.txt              the user turn under test                           [required]
#   checks.sh   (sourced)   deterministic assertions over the sandbox         [required]
#   rubric.md   (optional)  prose-quality rubric for an LLM judge
#
# Safety: evals NEVER touch real Jira/GitLab. Authoring skills run pure-local in
# the sandbox; action skills must run in dry_run / --from-fixture (the scenario's
# setup + prompt are responsible for that).
#
# Exit: 0 when every scenario's majority of runs passed (or the lane SKIPs);
#       1 when a scenario's majority failed; 2 bad usage.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"            # .../scripts/tests/skill-evals
TESTS="$(cd "$HERE/.." && pwd)"                  # .../scripts/tests
source "$TESTS/lib/assert.sh"                    # PASS/FAIL + assert
# invariants lib is available to checks.sh (sourced in the same shell)
# shellcheck source=/dev/null
source "$TESTS/e2e/lib/invariants.sh"

RUNS=3
ONLY='*'
DRY_LIST=0
KEEP=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --runs)     [[ $# -ge 2 ]] || { echo "usage: --runs N" >&2; exit 2; }; RUNS="$2"; shift 2 ;;
    --only)     [[ $# -ge 2 ]] || { echo "usage: --only <glob>" >&2; exit 2; }; ONLY="$2"; shift 2 ;;
    --dry-list) DRY_LIST=1; shift ;;
    --keep)     KEEP=1; shift ;;
    *) echo "usage: run-evals.sh [--runs N] [--only <glob>] [--dry-list] [--keep]" >&2; exit 2 ;;
  esac
done

# Enumerate scenario dirs: a dir two levels deep holding prompt.txt.
scenarios=()
for p in "$HERE"/*/*/prompt.txt; do
  [[ -f "$p" ]] || continue
  scenarios+=("$(dirname "$p")")
done

# --dry-list: deterministic — validate the scaffolding shape, no LLM. This is the
# part run-all guards, so eval scenarios can't silently rot.
if [[ "$DRY_LIST" -eq 1 ]]; then
  rc=0
  if [[ ${#scenarios[@]} -eq 0 ]]; then echo "no scenarios found under $HERE" >&2; exit 1; fi
  for s in "${scenarios[@]}"; do
    rel="${s#"$HERE"/}"
    missing=()
    for f in setup.sh prompt.txt checks.sh; do [[ -f "$s/$f" ]] || missing+=("$f"); done
    if [[ ${#missing[@]} -eq 0 ]]; then
      echo "OK   $rel"
    else
      echo "BAD  $rel (missing: ${missing[*]})"; rc=1
    fi
  done
  exit "$rc"
fi

# Live lane — guard so it never breaks a plain unit run.
skip_reason=""
[[ "${SKILL_EVALS:-off}" == "on" ]] || skip_reason="SKILL_EVALS!=on"
[[ -z "$skip_reason" ]] && ! command -v claude >/dev/null 2>&1 && skip_reason="claude CLI not on PATH"
# Note: no API-key env check — the claude CLI authenticates via its own config /
# keychain, so requiring ANTHROPIC_API_KEY would wrongly SKIP a logged-in setup.
if [[ -n "$skip_reason" ]]; then
  echo "SKIP skill-evals ($skip_reason). Set SKILL_EVALS=on with the claude CLI + credentials to run."
  exit 0
fi

# --- Harness improvements (see README) -------------------------------------------
# 1. Branch-install parity: eval the WORKING-TREE specto, not whatever version is
#    installed user-level. Headless `claude -p` loads the installed plugin by
#    default; --plugin-dir loads the branch plugin for the session so the lane
#    tests the code under review. The loaded version is recorded in every report
#    so a stale/mismatched result is visible rather than silent.
# 2. Different-family judge: pin the judge to a different model than the skill runs
#    on, so the grader doesn't share the skill model's blind spots (self-grading).
#    Override with SPECTO_EVAL_JUDGE_MODEL; if your session default IS this model,
#    set it to another family to preserve the separation.
# 3. Cost/token accounting: run the skill via --output-format json to capture
#    total_cost_usd + token usage per run (reported per scenario).
PLUGIN_DIR="$(cd "$HERE/../../.." && pwd)"          # .../plugins/specto (branch)
PLUGIN_VERSION="$(jq -r '.version // "unknown"' "$PLUGIN_DIR/.claude-plugin/plugin.json" 2>/dev/null || echo unknown)"
JUDGE_MODEL="${SPECTO_EVAL_JUDGE_MODEL:-claude-sonnet-5}"
# Appended to every scenario prompt: under load the headless agent sometimes
# dispatches the guardian subagent asynchronously and returns an empty transcript
# ("I'll report once it completes"). Force synchronous completion so checks/judge
# see the real output. This is a harness-robustness guard, not a scenario input.
SYNC_SUFFIX=$'\n\nRun any subagent you invoke synchronously and wait for it to finish; include its full findings in your final message before you end. Do not dispatch it in the background or defer it to a later turn.'
echo "eval harness: specto v$PLUGIN_VERSION (branch, --plugin-dir $PLUGIN_DIR) · judge model $JUDGE_MODEL"

# LLM judge for prose-quality rubrics — handles the phrasing variance that makes
# transcript greps brittle. Prints PASS or FAIL. Pinned to a different model family
# than the skill under test (see improvement 2 above).
judge() {  # <rubric-file> <transcript-file> ; prints PASS|FAIL, reasoning to stderr
  local rubric="$1" tx="$2" out first
  out="$( (cd /tmp && claude -p "Grade this skill-eval run against the rubric. Start your reply with the single word PASS or FAIL, then one sentence why.

RUBRIC:
$(cat "$rubric")

RUN TRANSCRIPT:
$(cat "$tx")
" --model "$JUDGE_MODEL") 2>/dev/null )"
  # Robust to leading reasoning / format variance: take the FIRST PASS|FAIL token
  # anywhere in the reply (not just line 1). Default FAIL if the judge said nothing.
  first="$(printf '%s' "$out" | grep -oiE '\b(PASS|FAIL)\b' | head -1 | tr '[:lower:]' '[:upper:]')"
  [[ -n "$out" ]] && printf 'judge: %s\n' "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-200)" >&2
  echo "${first:-FAIL}"
}

run_scenario() {  # <scenario-dir>
  local dir="$1" rel; rel="${dir#"$HERE"/}"
  local passes=0 run scen_cost=0
  for ((run = 1; run <= RUNS; run++)); do
    local sandbox transcript rawout rawerr
    sandbox="$(mktemp -d -t specto-eval.XXXXXX)"
    transcript="$(mktemp -t specto-eval-tx.XXXXXX)"   # the model's final text (checks + judge read this)
    rawout="$(mktemp -t specto-eval-raw.XXXXXX)"      # the raw --output-format json envelope (cost/usage)
    rawerr="$(mktemp -t specto-eval-err.XXXXXX)"      # the CLI's stderr (kept out of the json so jq parses)
    ( bash "$dir/setup.sh" "$sandbox" ) >/dev/null 2>&1 || { echo "  run $run: setup failed"; rm -rf "$sandbox" "$transcript" "$rawout" "$rawerr"; continue; }
    # Invoke the skill headlessly WITH the sandbox as cwd, so the prompt's
    # relative paths resolve against the seeded files. Specto is a user-level
    # plugin, so its skills load regardless of cwd.
    # If setup.sh dropped stub executables in $sandbox/bin (a fake acli/glab that
    # echoes fixture JSON), prepend it to PATH so a scenario can exercise a path
    # that otherwise needs a live service (e.g. dod's epic Issue Checklist read).
    local run_path="$PATH"
    [[ -d "$sandbox/bin" ]] && run_path="$sandbox/bin:$PATH"
    # Run with --dangerously-skip-permissions (NOT --permission-mode acceptEdits):
    # a headless subagent can't answer a Bash permission prompt, so acceptEdits
    # blocks the vetted plugin helpers (epic-fields.sh, get-ticket-description.sh,
    # mr-fetch.sh) and the $sandbox/bin stubs — degrading a guardian to a fallback
    # read. Skipping permissions is safe here because the lane's contract is
    # OFFLINE-ONLY: every scenario stubs acli/glab on $sandbox/bin or uses
    # --from-fixture, and the sandbox is a throwaway mktemp dir with no real
    # credentials. A scenario that reaches a live service is a bug in the
    # scenario, not a reason to re-tighten the flag.
    # --plugin-dir loads the BRANCH specto (parity: eval the code under review, not
    # the installed version); --output-format json captures cost/usage. The json
    # envelope lands in $rawout; we extract .result into $transcript so checks.sh
    # and the judge read the model's final text exactly as before.
    ( cd "$sandbox" && PATH="$run_path" claude -p "$(cat "$dir/prompt.txt")$SYNC_SUFFIX" \
        --dangerously-skip-permissions --plugin-dir "$PLUGIN_DIR" --output-format json ) \
      > "$rawout" 2>"$rawerr" || true
    local run_cost=0
    if jq -e . "$rawout" >/dev/null 2>&1; then
      jq -r '.result // ""' "$rawout" > "$transcript"
      run_cost="$(jq -r '.total_cost_usd // 0' "$rawout")"
    else
      # No parseable JSON (a hard CLI error before any result) — surface stdout +
      # stderr as the transcript so the failure is visible and the run FAILs.
      cat "$rawout" "$rawerr" > "$transcript"
    fi
    scen_cost="$(awk -v a="$scen_cost" -v b="$run_cost" 'BEGIN{printf "%.4f", a+b}')"
    # Deterministic checks run in a subshell so a scenario's PASS/FAIL don't leak
    # into the outer tally; the subshell's exit code is the run verdict.
    local det_ok=0 judge_ok=1
    if ( PASS=0; FAIL=0; SANDBOX="$sandbox"; TRANSCRIPT="$transcript"; \
         source "$dir/checks.sh"; [[ "$FAIL" -eq 0 ]] ); then det_ok=1; fi
    if [[ -f "$dir/rubric.md" ]]; then
      [[ "$(judge "$dir/rubric.md" "$transcript")" == "PASS" ]] && judge_ok=1 || judge_ok=0
    fi
    if [[ "$det_ok" -eq 1 && "$judge_ok" -eq 1 ]]; then
      passes=$((passes + 1)); echo "  run $run: PASS (\$$run_cost)"
    else
      echo "  run $run: FAIL (checks=$det_ok judge=$judge_ok, \$$run_cost)"
    fi
    if [[ "$KEEP" -eq 1 ]]; then
      echo "    kept: sandbox=$sandbox transcript=$transcript raw=$rawout err=$rawerr"
    else
      rm -rf "$sandbox" "$transcript" "$rawout" "$rawerr"
    fi
  done
  local need=$(( RUNS / 2 + 1 ))
  if [[ "$passes" -ge "$need" ]]; then
    echo "SCENARIO PASS  $rel ($passes/$RUNS) [specto v$PLUGIN_VERSION, ~\$$scen_cost]"; return 0
  fi
  echo "SCENARIO FAIL  $rel ($passes/$RUNS, needed $need) [specto v$PLUGIN_VERSION, ~\$$scen_cost]"; return 1
}

failed=0
for s in "${scenarios[@]}"; do
  rel="${s#"$HERE"/}"
  case "$rel" in $ONLY|$ONLY/*) ;; *) continue ;; esac
  echo "== $rel =="
  run_scenario "$s" || failed=$((failed + 1))
  echo
done

echo "============================================================"
if [[ "$failed" -gt 0 ]]; then echo "$failed scenario(s) failed."; exit 1; fi
echo "All scenarios passed."
