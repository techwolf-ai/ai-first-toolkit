# Deterministic checks for the code-mr-review implementer's-choice negative
# control (guidelines principle 9). The diff picks a valid alt implementation that
# meets every §2.4 criterion, so a `spec-adherence` finding litigating the choice
# would be a false positive. The false-positive guard is the ABSENCE of any
# spec-adherence finding (grep both the transcript and the .md-review sink).
# Whether it positively VERIFIED the criteria is the rubric's call. Sourced with
# $SANDBOX, $TRANSCRIPT, PASS/FAIL in scope.

t="$TRANSCRIPT"
sink="$SANDBOX/.md-review/comments.json"
# Match a spec-adherence *finding*, not a passing mention. In the transcript that
# is a collect-format bullet (`- **[spec-adherence-…] …`); narrating
# "spec-adherence: ✓ criteria met" as prose is NOT a finding and must not trip
# this control (calibration note from the authoring run). In the .md-review sink,
# any occurrence is a real finding (the sink only holds findings), so match it raw.
spec_adherence_findings() {
  local n m=0
  n="$(grep -ciE '^[[:space:]]*-[[:space:]]+\*\*\[spec-adherence' "$t" 2>/dev/null)"
  [[ -f "$sink" ]] && m="$(grep -ciE 'spec-adherence' "$sink" 2>/dev/null)"
  echo $(( n + m ))
}

assert "impl-choice" "review produced output" "$([[ -s "$t" ]] && echo yes || echo no)" "yes"

# No spec-adherence finding — the implementation is a granted implementer's choice
# that satisfies the §2.4 criteria; litigating it is the failure this control guards.
assert "impl-choice" "raised no spec-adherence finding on the choice" \
  "$([[ "$(spec_adherence_findings)" -eq 0 ]] && echo yes || echo no)" "yes"
