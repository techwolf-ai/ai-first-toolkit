# Deterministic checks for the code-mr-review security-axis eval. code-mr-review
# namespaces security findings as `security-*` under a `### security` axis heading;
# the phrasing of the vulnerability class varies, so accept the axis token or the
# words "injection"/"sql injection". Findings may also route to
# .md-review/comments.json — grep both the transcript and that sidecar. WHICH line
# and the fix are the rubric's call. Sourced with $SANDBOX, $TRANSCRIPT, PASS/FAIL.

t="$TRANSCRIPT"
sink="$SANDBOX/.md-review/comments.json"
both() { grep -ciE "$1" "$t" 2>/dev/null; [[ -f "$sink" ]] && grep -ciE "$1" "$sink" 2>/dev/null; }
hit()  { [[ "$( { both "$1"; } | awk '{s+=$1} END{print s+0}' )" -ge 1 ]] && echo yes || echo no; }

assert "review-mr" "review produced output" "$([[ -s "$t" ]] && echo yes || echo no)" "yes"

# Planted defect — the SQL injection (f-string interpolation into the query).
assert "review-mr" "emitted a security-axis injection finding" \
  "$(hit 'security-|injection|sql injection')" "yes"

# It must not declare the branch clean.
assert "review-mr" "did not declare no findings" \
  "$([[ "$(grep -ciE 'no findings on' "$t")" -eq 0 ]] && echo yes || echo no)" "yes"
