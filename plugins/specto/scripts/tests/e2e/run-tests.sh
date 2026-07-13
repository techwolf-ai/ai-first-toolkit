#!/usr/bin/env bash
# End-to-end structural invariants over Specto spec / ticket artifacts.
#
# Deterministic and offline. Two things run here:
#   1. The invariants hold on known-good fixtures AND fire on deliberately
#      broken ones (a predicate that can't fail proves nothing).
#   2. The same invariants run over captured golden scenarios (golden/<name>/),
#      which are snapshots of real skill output recorded via capture.sh.
#
# No LLM runs here: golden scenarios are captured once from a real run and then
# asserted deterministically. Re-capture (capture.sh) when a skill's output
# shape intentionally changes.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"     # scripts/tests/e2e
source "$HERE/../lib/assert.sh"           # scripts/tests/lib/assert.sh
source "$HERE/lib/invariants.sh"
FIX="$HERE/fixtures"
GOLDEN="$HERE/golden"

# Assert every product-spec structural invariant HOLDS for $1 (labelled $2).
check_product_spec() {
  local f="$1" tag="$2"
  assert "$tag" "§1 Value before §2 User stories"                 "$(inv_order_ok "$f" '^## 1\.' '^## 2\.'   && echo ok || echo bad)" "ok"
  assert "$tag" "§2 User stories before §3 Functional requirements" "$(inv_order_ok "$f" '^## 2\.' '^## 3\.' && echo ok || echo bad)" "ok"
  assert "$tag" "§1 Value section present"                          "$(inv_has "$f" '^## 1\. '                && echo ok || echo bad)" "ok"
  assert "$tag" "MoSCoW Must-haves present"                         "$(inv_has "$f" 'Must haves|Must-have'    && echo ok || echo bad)" "ok"
  assert "$tag" "no engineering content"                            "$(inv_lacks "$f" "$PRODUCT_ENG_CONTENT_RE" && echo ok || echo bad)" "ok"
}

# Assert every engineering-spec structural invariant HOLDS for $1 (labelled $2).
check_engineering_spec() {
  local f="$1" tag="$2"
  assert "$tag" "§1 NFR before §2 Technical approach"    "$(inv_order_ok "$f" '^## 1\.' '^## 2\.' && echo ok || echo bad)" "ok"
  assert "$tag" "§2 Technical approach before §3 Test plan" "$(inv_order_ok "$f" '^## 2\.' '^## 3\.' && echo ok || echo bad)" "ok"
  assert "$tag" "§2.1 Architecture present"              "$(inv_has "$f" '^### 2\.1\.' && echo ok || echo bad)" "ok"
  assert "$tag" "§3.1 Unit/integration coverage present" "$(inv_has "$f" '^### 3\.1\.' && echo ok || echo bad)" "ok"
  assert "$tag" "§4 Rollback plan present"               "$(inv_has "$f" '^## 4\. ' && echo ok || echo bad)" "ok"
  assert "$tag" "§6 Design decisions present"            "$(inv_has "$f" '^## 6\. ' && echo ok || echo bad)" "ok"
}

echo "== e2e: invariants hold on good fixtures =="
check_product_spec     "$FIX/product-spec-good.md"     "product-good"
check_engineering_spec "$FIX/engineering-spec-good.md" "eng-good"
# Lean: a single-spec draft with no §1.3 Objectives / no Delivery
# Stakeholders still satisfies every structural invariant (value-first order,
# MoSCoW, no engineering content). Its `## Engineering notes` tail is prose, not
# an eng-content violation.
check_product_spec     "$FIX/product-spec-lean.md"     "product-lean"

echo
echo "== e2e: invariants FIRE on broken fixtures (non-vacuous) =="
# Each predicate must report a VIOLATION on the broken fixtures ("bad"). If any
# of these comes back "ok", the corresponding invariant is vacuous.
assert "product-bad" "§2-before-§3 order violation detected" "$(inv_order_ok "$FIX/product-spec-bad.md" '^## 2\.' '^## 3\.' && echo ok || echo bad)" "bad"
assert "product-bad" "missing MoSCoW detected"               "$(inv_has "$FIX/product-spec-bad.md" 'Must haves|Must-have' && echo ok || echo bad)" "bad"
assert "product-bad" "engineering content detected"          "$(inv_lacks "$FIX/product-spec-bad.md" "$PRODUCT_ENG_CONTENT_RE" && echo ok || echo bad)" "bad"
assert "eng-bad"     "§2-before-§3 order violation detected" "$(inv_order_ok "$FIX/engineering-spec-bad.md" '^## 2\.' '^## 3\.' && echo ok || echo bad)" "bad"
assert "eng-bad"     "missing §6 detected"                   "$(inv_has "$FIX/engineering-spec-bad.md" '^## 6\. ' && echo ok || echo bad)" "bad"

echo
echo "== e2e: verify-milestone verdict shape (schema) =="
V="$FIX/milestone-verdict-good.json"
assert "verdict" "valid JSON"                 "$(jq -e . "$V" >/dev/null 2>&1 && echo ok || echo bad)" "ok"
assert "verdict" "has all required keys"      "$(jq -e 'has("milestone") and has("suite") and has("acceptance_criteria") and has("overall") and has("uncovered_or_failed")' "$V" >/dev/null 2>&1 && echo ok || echo bad)" "ok"
assert "verdict" "suite.status in enum"       "$(jq -r '.suite.status' "$V" | grep -cE '^(pass|fail|skipped)$')" "1"
assert "verdict" "overall in {pass,fail}"     "$(jq -r '.overall' "$V" | grep -cE '^(pass|fail)$')" "1"
assert "verdict" "every AC has id+met"        "$(jq -e 'all(.acceptance_criteria[]; has("id") and has("met"))' "$V" >/dev/null 2>&1 && echo ok || echo bad)" "ok"
# Consistency rule: overall==pass ⇒ uncovered_or_failed is empty.
assert "verdict" "pass verdict has empty uncovered list" "$(jq -e 'if .overall=="pass" then (.uncovered_or_failed|length)==0 else true end' "$V" >/dev/null 2>&1 && echo ok || echo bad)" "ok"
# Non-vacuous: an inconsistent pass verdict (overall=pass but AC uncovered) must be caught.
assert "verdict" "inconsistent pass verdict detected" "$(jq '.uncovered_or_failed=["M1-AC2"]' "$V" | jq -e 'if .overall=="pass" then (.uncovered_or_failed|length)==0 else true end' >/dev/null 2>&1 && echo ok || echo bad)" "bad"

echo
echo "== e2e: skill-eval scaffolding shape (deterministic --dry-list, no LLM) =="
EVALS="$HERE/../skill-evals/run-evals.sh"
if [[ -f "$EVALS" ]]; then
  ev_out="$(bash "$EVALS" --dry-list 2>&1)"; ev_rc=$?
  assert "skill-evals" "--dry-list exits 0 (all scenarios well-formed)" "$ev_rc" "0"
  assert "skill-evals" "no malformed (BAD) scenarios"                   "$(printf '%s\n' "$ev_out" | grep -c '^BAD')" "0"
  assert "skill-evals" "at least 2 scenarios enumerated"                "$([[ "$(printf '%s\n' "$ev_out" | grep -c '^OK')" -ge 2 ]] && echo yes || echo no)" "yes"
fi

echo
echo "== e2e: captured golden scenarios =="
found=0
for scen in "$GOLDEN"/*/; do
  [[ -d "$scen" ]] || continue
  found=1
  name="$(basename "$scen")"
  echo "-- scenario: $name"
  [[ -f "$scen/spec/product-spec.md" ]]     && check_product_spec     "$scen/spec/product-spec.md"     "golden:$name:product"
  [[ -f "$scen/spec/engineering-spec.md" ]] && check_engineering_spec "$scen/spec/engineering-spec.md" "golden:$name:eng"
  # Per-scenario extra assertions (e.g. rendered ticket bodies) — added by D4.3.
  [[ -f "$scen/assert-extra.sh" ]] && source "$scen/assert-extra.sh"
done
[[ "$found" -eq 0 ]] && echo "  (no golden scenarios captured yet — run capture.sh)"

assert_summary "e2e"
