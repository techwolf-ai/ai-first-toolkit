#!/usr/bin/env bash
# Test harness for the Specto lint library.
# Convention: each lint script exits 0 on pass, 1 on fail; prints findings to stdout.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
LINT_DIR="$(cd "$HERE/.." && pwd)"
PRODUCT_CHECKS="$LINT_DIR/checks.d/product"
ENG_CHECKS="$LINT_DIR/checks.d/engineering"
FIXTURES="$HERE/fixtures"

# Shared assertion helpers + PASS/FAIL counters.
source "$HERE/../../tests/lib/assert.sh"

echo "== checks.d/product/check-metadata-rows.sh =="
"$PRODUCT_CHECKS/check-metadata-rows.sh" "$FIXTURES/missing-metadata.md" >/dev/null
assert_exit 1 $? "missing-metadata.md should fail"
"$PRODUCT_CHECKS/check-metadata-rows.sh" "$FIXTURES/good-product-spec.md" >/dev/null
assert_exit 0 $? "good-product-spec.md should pass"

echo
echo "== checks.d/product/check-metric-count.sh =="
"$PRODUCT_CHECKS/check-metric-count.sh" "$FIXTURES/too-many-metrics.md" >/dev/null
assert_exit 1 $? "too-many-metrics.md should fail"
"$PRODUCT_CHECKS/check-metric-count.sh" "$FIXTURES/good-product-spec.md" >/dev/null
assert_exit 0 $? "good-product-spec.md should pass"

echo
echo "== checks.d/engineering/check-code-fence.sh =="
"$ENG_CHECKS/check-code-fence.sh" "$FIXTURES/eng-spec-good.md" >/dev/null
assert_exit 0 $? "eng-spec-good.md should pass (§3.2 has a fenced block)"
"$ENG_CHECKS/check-code-fence.sh" "$FIXTURES/eng-spec-no-fence.md" >/dev/null
assert_exit 1 $? "eng-spec-no-fence.md should fail (§3.2 prose but no fence)"

echo
echo "== checks.d/engineering/check-reversibility.sh =="
"$ENG_CHECKS/check-reversibility.sh" "$FIXTURES/eng-spec-good.md" >/dev/null
assert_exit 0 $? "eng-spec-good.md should pass (§4.3 present with body)"
"$ENG_CHECKS/check-reversibility.sh" "$FIXTURES/eng-spec-no-reversibility.md" >/dev/null
assert_exit 1 $? "eng-spec-no-reversibility.md should fail (no §4.3)"

echo
echo "== checks.d/engineering/check-stakeholder-table.sh =="
"$ENG_CHECKS/check-stakeholder-table.sh" "$FIXTURES/eng-spec-good.md" >/dev/null
assert_exit 0 $? "eng-spec-good.md should pass (table has a data-platform row)"
"$ENG_CHECKS/check-stakeholder-table.sh" "$FIXTURES/eng-spec-bad-stakeholders.md" >/dev/null
assert_exit 1 $? "eng-spec-bad-stakeholders.md should fail (table, no platform row)"
"$ENG_CHECKS/check-stakeholder-table.sh" "$FIXTURES/good-product-spec.md" >/dev/null
assert_exit 0 $? "good-product-spec.md should pass (no stakeholder table at all)"

echo
echo "== run-checks.sh (generic orchestrator) =="
"$LINT_DIR/run-checks.sh" "$PRODUCT_CHECKS" "$FIXTURES/missing-metadata.md" >/dev/null
assert_exit 1 $? "run-checks should fail when a product check fails"
"$LINT_DIR/run-checks.sh" "$PRODUCT_CHECKS" "$FIXTURES/good-product-spec.md" >/dev/null
assert_exit 0 $? "run-checks should pass on a clean product spec"
"$LINT_DIR/run-checks.sh" "$ENG_CHECKS" "$FIXTURES/eng-spec-good.md" >/dev/null
assert_exit 0 $? "run-checks should pass on a clean eng spec"
"$LINT_DIR/run-checks.sh" "$ENG_CHECKS" "$FIXTURES/eng-spec-no-fence.md" >/dev/null
assert_exit 1 $? "run-checks should fail when an eng check fails"
"$LINT_DIR/run-checks.sh" "$ENG_CHECKS" >/dev/null 2>&1
assert_exit 2 $? "run-checks bad usage (missing file arg)"
"$LINT_DIR/run-checks.sh" "$ENG_CHECKS/nonexistent-dir" "$FIXTURES/eng-spec-good.md" >/dev/null 2>&1
assert_exit 2 $? "run-checks bad usage (not a directory)"

echo
echo "== product-spec-lint.sh (shim) =="
"$LINT_DIR/product-spec-lint.sh" "$FIXTURES/missing-metadata.md" >/dev/null
assert_exit 1 $? "shim should fail on any individual product-check failure"
"$LINT_DIR/product-spec-lint.sh" "$FIXTURES/good-product-spec.md" >/dev/null
assert_exit 0 $? "shim should pass on a clean product spec"
"$LINT_DIR/product-spec-lint.sh" >/dev/null 2>&1
assert_exit 2 $? "shim bad usage (no args)"

echo
echo "== engineering-spec-lint.sh (shim) =="
"$LINT_DIR/engineering-spec-lint.sh" "$FIXTURES/eng-spec-good.md" >/dev/null
assert_exit 0 $? "shim should pass on a clean eng spec"
"$LINT_DIR/engineering-spec-lint.sh" "$FIXTURES/eng-spec-no-reversibility.md" >/dev/null
assert_exit 1 $? "shim should fail on a broken eng spec"
"$LINT_DIR/engineering-spec-lint.sh" >/dev/null 2>&1
assert_exit 2 $? "shim bad usage (no args)"

echo
echo "== check-diagram-palette.sh (shared, wired into both dirs) =="
"$ENG_CHECKS/check-diagram-palette.sh" "$FIXTURES/bad-diagram-palette.md" >/dev/null
assert_exit 1 $? "classDef fill: without color: should fail (engineering dir)"
"$PRODUCT_CHECKS/check-diagram-palette.sh" "$FIXTURES/bad-diagram-palette.md" >/dev/null
assert_exit 1 $? "classDef fill: without color: should fail (product dir)"
"$ENG_CHECKS/check-diagram-palette.sh" "$FIXTURES/good-diagram-palette.md" >/dev/null
assert_exit 0 $? "no-classDef and explicit-color diagrams should pass"
"$ENG_CHECKS/check-diagram-palette.sh" "$FIXTURES/eng-spec-good.md" >/dev/null
assert_exit 0 $? "clean eng spec (no offending classDef) should pass"
"$PRODUCT_CHECKS/check-diagram-palette.sh" "$FIXTURES/good-product-spec.md" >/dev/null
assert_exit 0 $? "clean product spec should pass"
"$PRODUCT_CHECKS/check-diagram-palette.sh" "$FIXTURES/pastel-with-color.md" >/dev/null
assert_exit 1 $? "pastel fill with explicit color: still fails (blocklist)"
"$ENG_CHECKS/check-diagram-palette.sh" >/dev/null 2>&1
assert_exit 2 $? "bad usage (no args)"

echo
echo "== check-mermaid-scaffold.sh (shared, wired into both dirs) =="
"$ENG_CHECKS/check-mermaid-scaffold.sh" "$FIXTURES/scaffold-placeholder.md" >/dev/null
assert_exit 1 $? "unfilled <…> placeholder in a diagram should fail"
"$PRODUCT_CHECKS/check-mermaid-scaffold.sh" "$FIXTURES/scaffold-untyped.md" >/dev/null
assert_exit 1 $? "mermaid block with no recognized diagram type should fail"
"$ENG_CHECKS/check-mermaid-scaffold.sh" "$FIXTURES/scaffold-br-ok.md" >/dev/null
assert_exit 0 $? "<br/> line breaks are not placeholders (should pass)"
"$ENG_CHECKS/check-mermaid-scaffold.sh" "$FIXTURES/good-diagram-palette.md" >/dev/null
assert_exit 0 $? "filled, typed diagrams should pass"
"$ENG_CHECKS/check-mermaid-scaffold.sh" "$FIXTURES/good-product-spec.md" >/dev/null
assert_exit 0 $? "a spec with no mermaid should pass"
"$ENG_CHECKS/check-mermaid-scaffold.sh" >/dev/null 2>&1
assert_exit 2 $? "bad usage (no args)"

echo
echo "== validate-mermaid.sh (extraction + usage; renderer-independent assertions) =="
out="$("$LINT_DIR/validate-mermaid.sh" --list "$FIXTURES/good-diagram-palette.md" 2>/dev/null)"
assert_exit 0 $? "--list exits 0"
n="$(printf '%s\n' "$out" | grep -c ':')"
assert_exit 0 "$([[ "$n" == "2" ]] && echo 0 || echo 1)" "--list extracts both fences from good-diagram-palette.md"
first="$(printf '%s\n' "$out" | head -1 | cut -f2)"
assert_exit 0 "$([[ "$first" == "flowchart TD" ]] && echo 0 || echo 1)" "--list reports the first fence's diagram type"
out="$("$LINT_DIR/validate-mermaid.sh" --list "$FIXTURES/good-product-spec.md" 2>/dev/null)"
assert_exit 0 "$([[ -z "$out" ]] && echo 0 || echo 1)" "--list on a spec with no mermaid prints nothing"
"$LINT_DIR/validate-mermaid.sh" >/dev/null 2>&1
assert_exit 2 $? "bad usage (no file)"
"$LINT_DIR/validate-mermaid.sh" --list /no/such/file.md >/dev/null 2>&1
assert_exit 2 $? "bad usage (file does not exist)"

echo
echo "Total: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
