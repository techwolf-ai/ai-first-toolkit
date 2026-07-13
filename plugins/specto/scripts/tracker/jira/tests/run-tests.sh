#!/usr/bin/env bash
# Test harness for the Specto jira helper scripts.
# All assertions run the helpers in --from-fixture mode (no acli, no network).

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/.."
FIXTURES="$HERE/fixtures"

# Shared assertion helpers + PASS/FAIL counters.
source "$HERE/../../../tests/lib/assert.sh"

# --------------------------------------------------------------------------------
# epic-fields.sh — profile-driven: questions come from --questions JSON.
# The fixtures simulate a tenant whose epics carry Q1/Q2/Q3 display-name fields;
# QUESTIONS below is the matching profile a repo would declare.
# --------------------------------------------------------------------------------
HELPER="$DIR/epic-fields.sh"
QUESTIONS='[
  {"id":"Q1","flag":"security","question":"Does the change affect authentication or authorization?","epic_field":"Q1: Is the change affecting the authentication and authorization methods to the service?"},
  {"id":"Q2","flag":"availability","question":"Could the change impact the availability of services?","epic_field":"Q2: Is this a change that could impact the availability of services?"},
  {"id":"Q3","flag":"data","question":"Will the change make permanent changes to customer data?","epic_field":"Q3: Will the change make permanent changes to customer data?"}
]'

echo "== epic-fields.sh: Standard-change epic (all-No, --questions) =="
out="$("$HELPER" APP-1234 --questions "$QUESTIONS" --from-fixture "$FIXTURES/epic-standard.json" 2>/dev/null)"; rc=$?
assert "epic-standard" "exit code 0" "$rc" "0"
assert "epic-standard" "classification line" "$(echo "$out" | grep -E '^classification=')" "classification=Standard"
assert "epic-standard" "q3 flag" "$(echo "$out" | grep -E '^flag_Q3=')" "flag_Q3=No"
assert "epic-standard" "epic_type" "$(echo "$out" | grep -E '^epic_type=')" "epic_type=Customer Outcome"
assert "epic-standard" "resolved via display name" "$(echo "$out" | grep -E '^resolved_via=')" "resolved_via=display_name"

echo
echo "== epic-fields.sh: Non-standard epic (Q1=Yes, Q3=Yes, --questions) =="
out="$("$HELPER" APP-1234 --questions "$QUESTIONS" --from-fixture "$FIXTURES/epic-non-standard.json" 2>/dev/null)"; rc=$?
assert "epic-non-standard" "exit code 0" "$rc" "0"
assert "epic-non-standard" "classification line" "$(echo "$out" | grep -E '^classification=')" "classification=Non-standard (Q1 / Q3)"
assert "epic-non-standard" "q1 flag" "$(echo "$out" | grep -E '^flag_Q1=')" "flag_Q1=Yes"

echo
echo "== epic-fields.sh: no --questions (no compliance profile) =="
out="$("$HELPER" APP-1234 --from-fixture "$FIXTURES/epic-standard.json" 2>/dev/null)"; rc=$?
assert "epic-unconfigured" "exit code 0" "$rc" "0"
assert "epic-unconfigured" "classification unconfigured" "$(echo "$out" | grep -E '^classification=')" "classification=unconfigured"
assert "epic-unconfigured" "no flag lines" "$(echo "$out" | grep -c '^flag_')" "0"
assert "epic-unconfigured" "metadata still read" "$(echo "$out" | grep -E '^epic_type=')" "epic_type=Customer Outcome"

echo
echo "== epic-fields.sh: missing OPTIONAL metadata fields =="
out="$("$HELPER" APP-1234 --questions "$QUESTIONS" --from-fixture "$FIXTURES/epic-missing-fields.json" 2>/dev/null)"; rc=$?
assert "epic-missing-optional" "exit code 0 (optional fields non-gating)" "$rc" "0"
assert "epic-missing-optional" "classification still resolves" "$(echo "$out" | grep -E '^classification=')" "classification=Standard"
assert "epic-missing-optional" "delivery_cycle empty" "$(echo "$out" | grep -E '^delivery_cycle=')" "delivery_cycle="

echo
echo "== epic-fields.sh: missing REQUIRED gating field (Q1) =="
"$HELPER" APP-1234 --questions "$QUESTIONS" --from-fixture "$FIXTURES/epic-missing-required.json" >/dev/null 2>&1; rc=$?
assert "epic-missing-required" "exit code 1" "$rc" "1"

echo
echo "== epic-fields.sh: substring fallback (question text, no epic_field) =="
out="$("$HELPER" APP-1234 --questions '[{"id":"QX","flag":"availability","question":"could impact the availability of services"}]' --from-fixture "$FIXTURES/epic-standard.json" 2>/dev/null)"; rc=$?
assert "epic-substring" "exit code 0" "$rc" "0"
assert "epic-substring" "flag resolved via substring" "$(echo "$out" | grep -E '^flag_QX=')" "flag_QX=No"
assert "epic-substring" "resolved_via substring or mixed" "$(echo "$out" | grep -E '^resolved_via=(substring|mixed)$' | wc -l | tr -d ' ')" "1"

echo
echo "== epic-fields.sh: malformed JSON =="
"$HELPER" APP-1234 --questions "$QUESTIONS" --from-fixture "$FIXTURES/epic-malformed.json" >/dev/null 2>&1; rc=$?
assert "epic-malformed" "exit code 1" "$rc" "1"

echo
echo "== epic-fields.sh: bad usage =="
"$HELPER" >/dev/null 2>&1; rc=$?
assert "bad-usage" "exit code 2" "$rc" "2"
"$HELPER" APP-1234 --questions 'not-json' --from-fixture "$FIXTURES/epic-standard.json" >/dev/null 2>&1; rc=$?
assert "bad-usage" "non-array --questions exit 2" "$rc" "2"

# --------------------------------------------------------------------------------
# link-tickets.sh
# --------------------------------------------------------------------------------
echo
echo "== link-tickets.sh =="
"$DIR/link-tickets.sh" Blocks APP-100 APP-200 --from-fixture "$FIXTURES/link-ok.json" >/dev/null 2>&1; rc=$?
assert "link-ok" "exit code 0 (link create succeeds)" "$rc" "0"
"$DIR/link-tickets.sh" Blocks APP-100 >/dev/null 2>&1; rc=$?
assert "link-bad-usage" "exit code 2 (too few args)" "$rc" "2"
# The `reviews` link type is what GitLab bot + Jira automation check for on
# Test Plan ↔ implementation pairings. link-tickets.sh is type-agnostic so it
# routes through unchanged; this assertion locks the contract in.
"$DIR/link-tickets.sh" reviews APP-100 APP-200 --from-fixture "$FIXTURES/link-ok.json" >/dev/null 2>&1; rc=$?
assert "link-reviews-ok" "exit code 0 (reviews link type accepted)" "$rc" "0"
# `Post-Incident Reviews` is an actual link-type NAME some Jira tenants expose
# for reviewer-shape links (the outward description is "reviews"). The helper
# is type-agnostic; this assertion locks in that the name-with-spaces flows
# through unchanged.
"$DIR/link-tickets.sh" "Post-Incident Reviews" APP-100 APP-200 --from-fixture "$FIXTURES/link-ok.json" >/dev/null 2>&1; rc=$?
assert "link-post-incident-reviews-ok" "exit code 0 (Post-Incident Reviews link type accepted)" "$rc" "0"

# --------------------------------------------------------------------------------
# delete-links.sh
# --------------------------------------------------------------------------------
echo
echo "== delete-links.sh =="
out="$("$DIR/delete-links.sh" APP-100 --from-fixture "$FIXTURES/issuelinks-multi.json" 2>/dev/null)"; rc=$?
assert "delete-links-all" "exit code 0" "$rc" "0"
assert "delete-links-all" "de-duped ids, all types" "$(echo "$out" | tr '\n' ',')" "46401,46402,"

out="$("$DIR/delete-links.sh" APP-100 --type Blocks --from-fixture "$FIXTURES/issuelinks-multi.json" 2>/dev/null)"; rc=$?
assert "delete-links-typed" "exit code 0" "$rc" "0"
assert "delete-links-typed" "--type Blocks filters + de-dupes" "$(echo "$out" | tr '\n' ',')" "46401,"

"$DIR/delete-links.sh" --dry-run >/dev/null 2>&1; rc=$?
assert "delete-links-bad-usage" "exit code 2 (no keys)" "$rc" "2"

out="$("$DIR/delete-links.sh" APP-100 --from-fixture "$FIXTURES/issuelinks-empty.json" 2>/dev/null)"; rc=$?
assert "delete-links-empty" "exit code 0 (no links is not an error)" "$rc" "0"
assert "delete-links-empty" "prints nothing" "$out" ""

# --------------------------------------------------------------------------------
# create-ticket.sh
# --------------------------------------------------------------------------------
echo
echo "== create-ticket.sh =="
out="$(printf 'body text\n' | "$DIR/create-ticket.sh" PROJ EPIC-1 "My summary" - --from-fixture "$FIXTURES/create-ok.json" 2>/dev/null)"; rc=$?
assert "create-happy" "exit code 0" "$rc" "0"
assert "create-happy" "prints the new key on stdout" "$out" "APP-1234"

out="$(printf 'body\n' | "$DIR/create-ticket.sh" PROJ EPIC-1 "S" - --blocks APP-5 --blocks APP-6 --blocked-by APP-7 --from-fixture "$FIXTURES/create-ok.json" 2>/dev/null)"; rc=$?
assert "create-with-links" "exit code 0 (create + 3 links)" "$rc" "0"
assert "create-with-links" "still prints just the key" "$out" "APP-1234"

# customfield-fallback path: the resolver is empty by default, so creation still
# succeeds with no customfields applied (it's a no-op, not a failure).
out="$(printf 'b\n' | "$DIR/create-ticket.sh" UNKNOWNPROJ EPIC-9 "S" - --from-fixture "$FIXTURES/create-ok.json" 2>/dev/null)"; rc=$?
assert "create-cf-noop" "exit code 0 (empty customfield map tolerated)" "$rc" "0"
assert "create-cf-noop" "key still printed" "$out" "APP-1234"

"$DIR/create-ticket.sh" PROJ EPIC-1 >/dev/null 2>&1; rc=$?
assert "create-bad-usage" "exit code 2 (too few args)" "$rc" "2"

# Standalone create (epic="-" sentinel and explicit --no-epic).
out="$(printf 'b\n' | "$DIR/create-ticket.sh" PROJ - "S" - --from-fixture "$FIXTURES/create-ok.json" 2>/dev/null)"; rc=$?
assert "create-no-epic-dash" "exit code 0 (epic '-' = standalone)" "$rc" "0"
assert "create-no-epic-dash" "key still printed" "$out" "APP-1234"
out="$(printf 'b\n' | "$DIR/create-ticket.sh" PROJ EPIC-1 "S" - --no-epic --from-fixture "$FIXTURES/create-ok.json" 2>/dev/null)"; rc=$?
assert "create-no-epic-flag" "exit code 0 (--no-epic overrides positional epic)" "$rc" "0"
assert "create-no-epic-flag" "key still printed" "$out" "APP-1234"

# Full Bug-with-everything flag set + extra labels (fixture mode ignores most of
# this — we're only asserting that the parser accepts the flags and still drives
# the key-from-fixture + link loop end-to-end).
out="$(printf 'b\n' | "$DIR/create-ticket.sh" PROJ EPIC-1 "Login broken" - \
  --type Bug --label "non-standard-change" --label "ops" \
  --sprint-id 7 --impact High --priority Urgent --assign \
  --blocks APP-99 \
  --from-fixture "$FIXTURES/create-ok.json" 2>/dev/null)"; rc=$?
assert "create-bug-full-flags" "exit code 0 (Bug + all flags accepted)" "$rc" "0"
assert "create-bug-full-flags" "still prints just the key" "$out" "APP-1234"

# Test Plan with --description-adf-file: fixture mode bypasses ADF parsing, but the
# parser must still accept the flag and the key path must still be exercised. The
# positional <description-file> is "-" and the ADF file points at a real file —
# fixture mode skips the stdin drain because we're not in live mode.
adf_tmp="$(mktemp -t adf.XXXXXX)"
echo '{"type":"doc","version":1,"content":[]}' > "$adf_tmp"
out="$("$DIR/create-ticket.sh" PROJ - "[APP-1] Test plan: foo" "$adf_tmp" \
  --type "Test Plan" --no-epic --label "non-standard-change" \
  --description-adf-file "$adf_tmp" \
  --from-fixture "$FIXTURES/create-ok.json" 2>/dev/null)"; rc=$?
rm -f "$adf_tmp"
assert "create-test-plan-adf" "exit code 0 (Test Plan + ADF file accepted)" "$rc" "0"
assert "create-test-plan-adf" "still prints just the key" "$out" "APP-1234"

# Unknown flag still rejected.
"$DIR/create-ticket.sh" PROJ EPIC-1 "S" - --bogus 1 --from-fixture "$FIXTURES/create-ok.json" >/dev/null 2>&1; rc=$?
assert "create-unknown-flag" "exit code 2 (rejects unknown flag)" "$rc" "2"

# --label requires a value (last token bare-flag).
"$DIR/create-ticket.sh" PROJ EPIC-1 "S" - --label --from-fixture "$FIXTURES/create-ok.json" >/dev/null 2>&1; rc=$?
assert "create-label-missing-arg" "exit code 2 (bare --label rejected)" "$rc" "2"

# Zero-links regression: under an earlier skill version, acli `link create` exited 0
# while storing NOTHING, and the run still reported "16/16 ✓". Links that silently
# fail to store must never be reported as success — the post-link self-verify
# (link-tickets.sh + create-ticket.sh both re-read issuelinks via REST) has to
# catch an empty store and exit 3. Mocked-acli live path: create succeeds, link
# create exits 0, but `workitem view --fields=issuelinks` returns no links.
MOCKBIN="$(mktemp -d)"; MOCK_LOG="$MOCKBIN/calls.log"
cat > "$MOCKBIN/acli" <<'EOF'
#!/usr/bin/env bash
echo "$@" >> "$MOCK_LOG"
case "${2:-} ${3:-}" in
  "workitem create") echo '{"key":"APP-999"}'; exit 0 ;;
  "workitem link")   exit 0 ;;   # claims success regardless of what stored
  "workitem view")
    if [[ -n "${MOCK_LINKS_OK:-}" ]]; then
      echo '{"fields":{"issuelinks":[{"type":{"name":"Blocks"},"inwardIssue":{"key":"APP-1"},"outwardIssue":{"key":"APP-999"}}]}}'
    else
      echo '{"fields":{"issuelinks":[]}}'
    fi
    exit 0 ;;
  *) echo '{}'; exit 0 ;;
esac
EOF
chmod +x "$MOCKBIN/acli"
err="$(printf 'b\n' | PATH="$MOCKBIN:$PATH" MOCK_LOG="$MOCK_LOG" \
        "$DIR/create-ticket.sh" PROJ - "T" - --no-epic --blocked-by APP-1 2>&1 >/dev/null)"; rc=$?
assert "create-zero-links" "exit code 3 (empty issuelinks can never read as success)" "$rc" "3"
assert "create-zero-links" "stderr names the direction/store failure" "$(printf '%s\n' "$err" | grep -c 'direction')" "1"
# Counter-test: the same flow with the link actually stored verifies clean.
: > "$MOCK_LOG"
out="$(printf 'b\n' | PATH="$MOCKBIN:$PATH" MOCK_LOG="$MOCK_LOG" MOCK_LINKS_OK=1 \
        "$DIR/create-ticket.sh" PROJ - "T" - --no-epic --blocked-by APP-1 2>/dev/null)"; rc=$?
assert "create-links-stored" "exit code 0 (stored link verifies)" "$rc" "0"
assert "create-links-stored" "prints the new key" "$out" "APP-999"
rm -rf "$MOCKBIN"

# --------------------------------------------------------------------------------
# assign-ticket.sh
# --------------------------------------------------------------------------------
echo
echo "== assign-ticket.sh =="
"$DIR/assign-ticket.sh" APP-1 user@example.com --from-fixture "$FIXTURES/link-ok.json" >/dev/null 2>&1; rc=$?
assert "assign-explicit" "exit code 0 (assignee + reporter)" "$rc" "0"
"$DIR/assign-ticket.sh" APP-1 --from-fixture "$FIXTURES/link-ok.json" >/dev/null 2>&1; rc=$?
assert "assign-default-me" "exit code 0 (default @me)" "$rc" "0"
"$DIR/assign-ticket.sh" >/dev/null 2>&1; rc=$?
assert "assign-bad-usage" "exit code 2 (no args)" "$rc" "2"

# --------------------------------------------------------------------------------
# set-parent.sh
# --------------------------------------------------------------------------------
echo
echo "== set-parent.sh =="
"$DIR/set-parent.sh" APP-1 APP-100 --from-fixture "$FIXTURES/link-ok.json" >/dev/null 2>&1; rc=$?
assert "set-parent-ok" "exit code 0 (fixture short-circuit)" "$rc" "0"
"$DIR/set-parent.sh" APP-1 --from-fixture "$FIXTURES/link-ok.json" >/dev/null 2>&1; rc=$?
assert "set-parent-missing-parent" "exit code 2 (parent arg required)" "$rc" "2"
"$DIR/set-parent.sh" APP-1 APP-100 --from-fixture "$FIXTURES/does-not-exist.json" >/dev/null 2>&1; rc=$?
assert "set-parent-bad-fixture" "exit code 3 (fixture not found)" "$rc" "3"
"$DIR/set-parent.sh" APP-1 APP-100 --bogus >/dev/null 2>&1; rc=$?
assert "set-parent-bad-usage" "exit code 2 (unknown flag)" "$rc" "2"

# --------------------------------------------------------------------------------
# transition-ticket.sh — workflow-name fallback
# --------------------------------------------------------------------------------
echo
echo "== transition-ticket.sh =="
out="$("$DIR/transition-ticket.sh" APP-1 "To Do" --from-fixture "$FIXTURES/transitions-altnames.json" 2>/dev/null)"; rc=$?
assert "transition-fallback-todo" "exit code 0 (literal absent, synonym matched)" "$rc" "0"
assert "transition-fallback-todo" "matched 'Backlog'" "$out" "transitioned_to=Backlog"
out="$("$DIR/transition-ticket.sh" APP-1 "In Review" --from-fixture "$FIXTURES/transitions-altnames.json" 2>/dev/null)"; rc=$?
assert "transition-fallback-review" "exit code 0" "$rc" "0"
assert "transition-fallback-review" "matched 'Code Review'" "$out" "transitioned_to=Code Review"
out="$("$DIR/transition-ticket.sh" APP-1 "In Progress" --from-fixture "$FIXTURES/transitions-altnames.json" 2>/dev/null)"; rc=$?
assert "transition-literal-present" "exit code 0 (literal name present)" "$rc" "0"
assert "transition-literal-present" "matched literal 'In Progress'" "$out" "transitioned_to=In Progress"
"$DIR/transition-ticket.sh" APP-1 "To Do" --from-fixture "$FIXTURES/transitions-weird.json" >/dev/null 2>&1; rc=$?
assert "transition-no-match" "exit code 1 (no literal or synonym in workflow)" "$rc" "1"
"$DIR/transition-ticket.sh" APP-1 >/dev/null 2>&1; rc=$?
assert "transition-bad-usage" "exit code 2 (too few args)" "$rc" "2"

# --------------------------------------------------------------------------------
# comment.sh
# --------------------------------------------------------------------------------
echo
echo "== comment.sh =="
printf 'hello\n' | "$DIR/comment.sh" APP-1 - --from-fixture "$FIXTURES/link-ok.json" >/dev/null 2>&1; rc=$?
assert "comment-stdin" "exit code 0 (body from stdin)" "$rc" "0"
printf '   \n' | "$DIR/comment.sh" APP-1 - --from-fixture "$FIXTURES/link-ok.json" >/dev/null 2>&1; rc=$?
assert "comment-empty-body" "exit code 1 (empty body)" "$rc" "1"
"$DIR/comment.sh" APP-1 >/dev/null 2>&1; rc=$?
assert "comment-bad-usage" "exit code 2 (too few args)" "$rc" "2"

# --------------------------------------------------------------------------------
# active-sprint.sh — resolve the active sprint(s) for a board (reads side)
# --------------------------------------------------------------------------------
echo
echo "== active-sprint.sh =="
out="$("$DIR/active-sprint.sh" 12 --from-fixture "$FIXTURES/sprint-active.json" 2>/dev/null)"; rc=$?
assert "active-sprint-single" "exit code 0" "$rc" "0"
assert "active-sprint-single" "prints id<TAB>name on one line" "$out" "$(printf '34\tSprint 7')"
out="$("$DIR/active-sprint.sh" 12 --from-fixture "$FIXTURES/sprint-none.json" 2>/dev/null)"; rc=$?
assert "active-sprint-none" "exit code 0 (no active sprint is not an error)" "$rc" "0"
assert "active-sprint-none" "no lines on stdout" "$out" ""
out="$("$DIR/active-sprint.sh" 12 --from-fixture "$FIXTURES/sprint-multi-active.json" 2>/dev/null)"; rc=$?
assert "active-sprint-multi" "exit code 0" "$rc" "0"
assert "active-sprint-multi" "two lines, one per active sprint" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" "2"
"$DIR/active-sprint.sh" >/dev/null 2>&1; rc=$?
assert "active-sprint-bad-usage" "exit code 2 (no args)" "$rc" "2"

# --------------------------------------------------------------------------------
# add-to-sprint.sh — Jira Agile REST sprint placement (with fixture backwards compat)
# --------------------------------------------------------------------------------
echo
echo "== add-to-sprint.sh =="
# Legacy one-arg form: still accepted, falls through to a no-op exit 0 on the
# legacy active-sprint fixture shape (matches the prior stub contract so older
# callers don't break).
"$DIR/add-to-sprint.sh" APP-1 --from-fixture "$FIXTURES/sprint-active.json" >/dev/null 2>&1; rc=$?
assert "sprint-active" "exit code 0 (legacy fixture, active sprint present)" "$rc" "0"
"$DIR/add-to-sprint.sh" APP-1 --from-fixture "$FIXTURES/sprint-none.json" >/dev/null 2>&1; rc=$?
assert "sprint-none" "exit code 0 (legacy fixture, no active sprint -> no-op)" "$rc" "0"
# Two-arg form: <SPRINT_ID> <KEY>. Success fixture exits 0; error fixture exits 3.
"$DIR/add-to-sprint.sh" 5271 APP-1 --from-fixture "$FIXTURES/sprint-add-ok.json" >/dev/null 2>&1; rc=$?
assert "sprint-add-ok" "exit code 0 (REST API success fixture)" "$rc" "0"
"$DIR/add-to-sprint.sh" 9999 APP-1 --from-fixture "$FIXTURES/sprint-add-error.json" >/dev/null 2>&1; rc=$?
assert "sprint-add-error" "exit code 3 (REST API error fixture)" "$rc" "3"
"$DIR/add-to-sprint.sh" >/dev/null 2>&1; rc=$?
assert "sprint-bad-usage" "exit code 2 (no args)" "$rc" "2"

# --------------------------------------------------------------------------------
# get-ticket-description.sh — ADF -> Markdown
# --------------------------------------------------------------------------------
echo
echo "== get-ticket-description.sh =="
md="$("$DIR/get-ticket-description.sh" APP-4242 --from-fixture "$FIXTURES/ticket-adf.json" 2>/dev/null)"; rc=$?
assert "adf-happy" "exit code 0" "$rc" "0"
assert "adf-happy" "H1 rendered" "$(printf '%s\n' "$md" | grep -c '^# Goal$')" "1"
assert "adf-happy" "H2 rendered" "$(printf '%s\n' "$md" | grep -c '^## Acceptance criteria$')" "1"
assert "adf-happy" "bold mark" "$(printf '%s\n' "$md" | grep -c '\*\*confidence score\*\*')" "1"
assert "adf-happy" "italic mark" "$(printf '%s\n' "$md" | grep -c '_labelled data_')" "1"
assert "adf-happy" "inline code mark" "$(printf '%s\n' "$md" | grep -c '`GET /skills`')" "1"
assert "adf-happy" "bullet list item" "$(printf '%s\n' "$md" | grep -c '^- Score is in \[0, 1\]\.$')" "1"
assert "adf-happy" "ordered list item" "$(printf '%s\n' "$md" | grep -c '^1\. Train the calibrator\.$')" "1"
assert "adf-happy" "link rendered" "$(printf '%s\n' "$md" | grep -c '\[Storage model\](https://example.atlassian.net/wiki/spaces/X/pages/123#2-3-storage-model)')" "1"
assert "adf-happy" "code fence opened" "$(printf '%s\n' "$md" | grep -c '^```python$')" "1"
assert "adf-happy" "code fence body" "$(printf '%s\n' "$md" | grep -c 'def calibrate(scores):')" "1"
assert "adf-happy" "hard break splits the paragraph" "$(printf '%s\n' "$md" | grep -c '^second line$')" "1"

"$DIR/get-ticket-description.sh" APP-9999 --from-fixture "$FIXTURES/ticket-adf-malformed.json" >/dev/null 2>&1; rc=$?
assert "adf-malformed" "exit code 1 (no/unparseable ADF description)" "$rc" "1"
"$DIR/get-ticket-description.sh" >/dev/null 2>&1; rc=$?
assert "adf-bad-usage" "exit code 2 (no args)" "$rc" "2"

# --------------------------------------------------------------------------------
# references/test-plan-adf-template.jq — ADF doc renderer for create-test-plan
# --------------------------------------------------------------------------------
echo
echo "== test-plan-adf-template.jq =="
TEMPLATE="$DIR/../../../references/test-plan-adf-template.jq"
[[ -f "$TEMPLATE" ]] || { echo "  FAIL: template missing: $TEMPLATE"; FAIL=$((FAIL+1)); }
# Render with minimal valid inputs (no rollout) and assert the structural invariants
# acli enforces. The headline regression: taskItem.content[].type MUST NOT be
# "paragraph" — wrapping the inline runs in a paragraph is the most common ADF
# mistake (acli rejects with INVALID_INPUT).
rendered="$(jq -n \
  --arg context 'inv' \
  --argjson risks '["unmigrated user breaks"]' \
  --argjson prereqs '["p"]' \
  --argjson cases '[{"title":"1. (R1) T.","setup":"do thing.","expected":"thing happens."}]' \
  --argjson signoff '["s"]' \
  --argjson rollout '[]' \
  -f "$TEMPLATE" 2>/dev/null)"; rc=$?
assert "adf-tpl-render-ok"   "exit code 0 on minimal valid inputs" "$rc" "0"
assert "adf-tpl-doc-shape"   "top-level is doc / version 1"        "$(echo "$rendered" | jq -r '"\(.type) v\(.version)"')" "doc v1"
# The structural invariant: no taskItem's first content child is a paragraph.
violations="$(echo "$rendered" | jq -r '[.. | objects | select(.type == "taskItem") | .content[0].type] | map(select(. == "paragraph")) | length')"
assert "adf-tpl-no-task-para" "no taskItem wraps content in paragraph (acli INVALID_INPUT guard)" "$violations" "0"
# Counts.
assert "adf-tpl-cases-count"   "exactly 1 case"   "$(echo "$rendered" | jq '[.. | objects | select(.attrs.localId == "cases")   | .content[]] | length')" "1"
assert "adf-tpl-signoff-count" "exactly 1 signoff" "$(echo "$rendered" | jq '[.. | objects | select(.attrs.localId == "signoff") | .content[]] | length')" "1"
# Rollout section omitted when $rollout is empty.
rollout_headings="$(echo "$rendered" | jq -r '[.. | objects | select(.type == "heading") | .content[0].text] | map(select(. == "Rollout cadence")) | length')"
assert "adf-tpl-rollout-omit" "Rollout cadence heading omitted when rollout is empty" "$rollout_headings" "0"
# Rollout section appears when $rollout is non-empty.
rendered_rollout="$(jq -n \
  --arg context 'inv' \
  --argjson risks '["r1"]' \
  --argjson prereqs '["p"]' \
  --argjson cases '[{"title":"1.","setup":"s","expected":"e"}]' \
  --argjson signoff '["s"]' \
  --argjson rollout '["step 1","step 2"]' \
  -f "$TEMPLATE" 2>/dev/null)"
rollout_headings="$(echo "$rendered_rollout" | jq -r '[.. | objects | select(.type == "heading") | .content[0].text] | map(select(. == "Rollout cadence")) | length')"
assert "adf-tpl-rollout-show" "Rollout cadence heading appears when rollout is non-empty" "$rollout_headings" "1"
# Stable localIds across renders (c1, c2, c3 in order).
ids="$(echo "$rendered_rollout" | jq -r '[.. | objects | select(.type == "taskItem") | .attrs.localId] | @csv' | tr -d '"')"
assert "adf-tpl-stable-ids"   "case + signoff localIds are c1,s1 with one case + one signoff" "$ids" "c1,s1"
# Pre-requisites section omitted when $prereqs is empty.
rendered_no_pre="$(jq -n \
  --arg context 'inv' \
  --argjson risks '["r1"]' \
  --argjson prereqs '[]' \
  --argjson cases '[{"title":"1.","setup":"s","expected":"e"}]' \
  --argjson signoff '["s"]' \
  --argjson rollout '[]' \
  -f "$TEMPLATE" 2>/dev/null)"
pre_headings="$(echo "$rendered_no_pre" | jq -r '[.. | objects | select(.type == "heading") | .content[0].text] | map(select(. == "Pre-requisites")) | length')"
assert "adf-tpl-prereqs-omit" "Pre-requisites heading omitted when prereqs is empty" "$pre_headings" "0"

# Risks section: heading present + bullets auto-prefixed with bold R1 — , R2 — .
risk_headings="$(echo "$rendered" | jq '[.. | objects | select(.type == "heading") | .content[0].text] | map(select(. == "Risks")) | length')"
assert "adf-tpl-risks-show" "Risks heading present" "$risk_headings" "1"
r1_prefix="$(echo "$rendered" | jq -r '[.. | objects | select(.marks?[]?.type == "strong") | .text] | map(select(test("^R[0-9]+ —"))) | length')"
assert "adf-tpl-risks-prefix" "at least one Rn — prefix appears bolded" "$r1_prefix" "1"

# Sign-off omitted when empty.
rendered_no_signoff="$(jq -n \
  --arg context 'inv' \
  --argjson risks '["r1"]' \
  --argjson prereqs '[]' \
  --argjson cases '[{"title":"1.","setup":"s","expected":"e"}]' \
  --argjson signoff '[]' \
  --argjson rollout '[]' \
  -f "$TEMPLATE" 2>/dev/null)"
signoff_headings="$(echo "$rendered_no_signoff" | jq -r '[.. | objects | select(.type == "heading") | .content[0].text] | map(select(. == "Sign-off")) | length')"
assert "adf-tpl-signoff-omit" "Sign-off heading omitted when signoff is empty" "$signoff_headings" "0"

# Case rendering: bold "Expected:" appears inline.
expected_bold="$(echo "$rendered" | jq '[.. | objects | select(.marks?[]?.type == "strong") | .text] | map(select(. == "Expected: ")) | length')"
assert "adf-tpl-expected-bold" "case renders a bold 'Expected: ' run" "$expected_bold" "1"

# --------------------------------------------------------------------------------
# get-ticket-summary.sh — read .fields.summary (single vetted path for the title)
# --------------------------------------------------------------------------------
echo
echo "== get-ticket-summary.sh =="
out="$("$DIR/get-ticket-summary.sh" APP-4242 --from-fixture "$FIXTURES/ticket-adf.json" 2>/dev/null)"; rc=$?
assert "summary-happy" "exit code 0" "$rc" "0"
assert "summary-happy" "prints the summary string" "$out" "Add confidence scoring to skill timeline"
"$DIR/get-ticket-summary.sh" APP-1 --from-fixture "$FIXTURES/ticket-no-summary.json" >/dev/null 2>&1; rc=$?
assert "summary-missing" "exit code 1 (no .fields.summary)" "$rc" "1"
"$DIR/get-ticket-summary.sh" APP-9999 --from-fixture "$FIXTURES/epic-malformed.json" >/dev/null 2>&1; rc=$?
assert "summary-malformed" "exit code 1 (unparseable JSON)" "$rc" "1"
"$DIR/get-ticket-summary.sh" >/dev/null 2>&1; rc=$?
assert "summary-bad-usage" "exit code 2 (no args)" "$rc" "2"

# --------------------------------------------------------------------------------
# get-ticket-type.sh — read .fields.issuetype.name (Epic / Task / Bug / Story / …)
# --------------------------------------------------------------------------------
echo
echo "== get-ticket-type.sh =="
out="$("$DIR/get-ticket-type.sh" APP-100 --from-fixture "$FIXTURES/ticket-type-epic.json" 2>/dev/null)"; rc=$?
assert "type-epic" "exit code 0" "$rc" "0"
assert "type-epic" "prints Epic" "$out" "Epic"
out="$("$DIR/get-ticket-type.sh" APP-200 --from-fixture "$FIXTURES/ticket-type-task.json" 2>/dev/null)"; rc=$?
assert "type-task" "exit code 0" "$rc" "0"
assert "type-task" "prints Task" "$out" "Task"
"$DIR/get-ticket-type.sh" APP-9999 --from-fixture "$FIXTURES/ticket-no-summary.json" >/dev/null 2>&1; rc=$?
assert "type-missing" "exit code 1 (no .fields.issuetype.name)" "$rc" "1"
"$DIR/get-ticket-type.sh" >/dev/null 2>&1; rc=$?
assert "type-bad-usage" "exit code 2 (no args)" "$rc" "2"

# --------------------------------------------------------------------------------
# get-ticket-parent.sh — prefer .fields.parent.key, fall back to first Relates
# --------------------------------------------------------------------------------
echo
echo "== get-ticket-parent.sh =="
out="$("$DIR/get-ticket-parent.sh" APP-300 --from-fixture "$FIXTURES/ticket-parent-epic.json" 2>/dev/null)"; rc=$?
assert "parent-epic" "exit code 0" "$rc" "0"
assert "parent-epic" "prints <KEY>\\tparent" "$out" "$(printf 'APP-100\tparent')"
out="$("$DIR/get-ticket-parent.sh" APP-301 --from-fixture "$FIXTURES/ticket-parent-relates.json" 2>/dev/null)"; rc=$?
assert "parent-relates" "exit code 0 (Relates fallback)" "$rc" "0"
assert "parent-relates" "prints <KEY>\\trelates" "$out" "$(printf 'APP-200\trelates')"
out="$("$DIR/get-ticket-parent.sh" APP-302 --from-fixture "$FIXTURES/ticket-parent-none.json" 2>/dev/null)"; rc=$?
assert "parent-none" "exit code 0 (no parent at all, clean empty)" "$rc" "0"
assert "parent-none" "stdout empty when no parent" "$out" ""
"$DIR/get-ticket-parent.sh" >/dev/null 2>&1; rc=$?
assert "parent-bad-usage" "exit code 2 (no args)" "$rc" "2"

# --------------------------------------------------------------------------------
# get-ticket-sprint.sh — read .fields.customfield_10020[] (active sprint only)
# --------------------------------------------------------------------------------
echo
echo "== get-ticket-sprint.sh =="
out="$("$DIR/get-ticket-sprint.sh" APP-400 --from-fixture "$FIXTURES/ticket-sprint-active.json" 2>/dev/null)"; rc=$?
assert "sprint-of-ticket-active" "exit code 0" "$rc" "0"
assert "sprint-of-ticket-active" "prints active sprint id (skips closed sprints in array)" "$out" "5271"
out="$("$DIR/get-ticket-sprint.sh" APP-401 --from-fixture "$FIXTURES/ticket-sprint-none.json" 2>/dev/null)"; rc=$?
assert "sprint-of-ticket-none" "exit code 0 (no active sprint, clean empty)" "$rc" "0"
assert "sprint-of-ticket-none" "stdout empty when no active sprint" "$out" ""
"$DIR/get-ticket-sprint.sh" >/dev/null 2>&1; rc=$?
assert "sprint-of-ticket-bad-usage" "exit code 2 (no args)" "$rc" "2"

# --------------------------------------------------------------------------------
# list-children.sh — normalized child work items of an epic
# --------------------------------------------------------------------------------
echo
echo "== list-children.sh =="
out="$("$DIR/list-children.sh" APP-100 --from-fixture "$FIXTURES/children-bare.json" 2>/dev/null)"; rc=$?
assert "children-bare" "exit code 0" "$rc" "0"
assert "children-bare" "returns a 2-element array" "$(printf '%s' "$out" | jq 'length')" "2"
assert "children-bare" "key normalized" "$(printf '%s' "$out" | jq -r '.[0].key')" "APP-101"
assert "children-bare" "summary normalized" "$(printf '%s' "$out" | jq -r '.[0].summary')" "Wire the scoring endpoint"
assert "children-bare" "status normalized" "$(printf '%s' "$out" | jq -r '.[0].status')" "In Progress"
assert "children-bare" "type normalized" "$(printf '%s' "$out" | jq -r '.[1].type')" "Bug"
out="$("$DIR/list-children.sh" APP-100 --from-fixture "$FIXTURES/children-wrapped.json" 2>/dev/null)"; rc=$?
assert "children-wrapped" "exit code 0 ({results:[...]} wrapper accepted)" "$rc" "0"
assert "children-wrapped" "same normalized array from the wrapper" "$(printf '%s' "$out" | jq -r '.[0].key')" "APP-101"
"$DIR/list-children.sh" APP-100 --from-fixture "$FIXTURES/epic-malformed.json" >/dev/null 2>&1; rc=$?
assert "children-malformed" "exit code 1 (unparseable JSON)" "$rc" "1"
"$DIR/list-children.sh" >/dev/null 2>&1; rc=$?
assert "children-bad-usage" "exit code 2 (no args)" "$rc" "2"

# --------------------------------------------------------------------------------
# get-ticket-status.sh — read .fields.status.name (live status, never cached)
# --------------------------------------------------------------------------------
echo
echo "== get-ticket-status.sh =="
out="$("$DIR/get-ticket-status.sh" APP-500 --from-fixture "$FIXTURES/ticket-status.json" 2>/dev/null)"; rc=$?
assert "status-happy" "exit code 0" "$rc" "0"
assert "status-happy" "prints the status string" "$out" "In Progress"
"$DIR/get-ticket-status.sh" APP-1 --from-fixture "$FIXTURES/ticket-no-summary.json" >/dev/null 2>&1; rc=$?
assert "status-missing" "exit code 1 (no .fields.status.name)" "$rc" "1"
"$DIR/get-ticket-status.sh" >/dev/null 2>&1; rc=$?
assert "status-bad-usage" "exit code 2 (no args)" "$rc" "2"

# --------------------------------------------------------------------------------
# ticket-url.sh — canonical browse URL, site never hardcoded
# --------------------------------------------------------------------------------
echo
echo "== ticket-url.sh =="
out="$(JIRA_SITE=jira.example.com "$DIR/ticket-url.sh" APP-1 2>/dev/null)"; rc=$?
assert "ticket-url-env" "exit code 0 (JIRA_SITE set)" "$rc" "0"
assert "ticket-url-env" "prints the browse URL" "$out" "https://jira.example.com/browse/APP-1"
out="$(JIRA_SITE="https://jira.example.com/" "$DIR/ticket-url.sh" APP-1 2>/dev/null)"
assert "ticket-url-normalize" "https:// prefix + trailing slash normalized" "$out" "https://jira.example.com/browse/APP-1"
# No site anywhere: empty JIRA_SITE, cwd outside any .specto/config.yml, and
# CLAUDE_PLUGIN_DATA pointed at an empty throwaway dir so the machine-level
# plugin-config lookup finds nothing either.
NOSITE="$(mktemp -d -t specto-nosite.XXXXXX)"
(cd "$NOSITE" && JIRA_SITE= CLAUDE_PLUGIN_DATA="$NOSITE/plugin-data" "$DIR/ticket-url.sh" APP-1) >/dev/null 2>&1; rc=$?
assert "ticket-url-no-site" "exit code 3 (no site configured anywhere)" "$rc" "3"
rm -rf "$NOSITE"
"$DIR/ticket-url.sh" >/dev/null 2>&1; rc=$?
assert "ticket-url-bad-usage" "exit code 2 (no args)" "$rc" "2"
"$DIR/ticket-url.sh" APP-1 extra >/dev/null 2>&1; rc=$?
assert "ticket-url-extra-args" "exit code 2 (exactly one arg expected)" "$rc" "2"

# --------------------------------------------------------------------------------
# references/ticket-description-adf-template.jq — ADF doc renderer for create-ticket
# --------------------------------------------------------------------------------
echo
echo "== ticket-description-adf-template.jq =="
DESC_TEMPLATE="$DIR/../../../references/ticket-description-adf-template.jq"
[[ -f "$DESC_TEMPLATE" ]] || { echo "  FAIL: template missing: $DESC_TEMPLATE"; FAIL=$((FAIL+1)); }
# Minimal valid inputs: Context + Goal + Scope only. Out-of-scope and AC empty.
desc_rendered="$(jq -n \
  --arg context 'Some context.' \
  --arg goal    'Some goal.' \
  --argjson scope                '["First scope bullet.", {"title":"Second.", "body":"with bold title."}]' \
  --argjson out_of_scope         '[]' \
  --argjson acceptance_criteria  '[]' \
  -f "$DESC_TEMPLATE" 2>/dev/null)"; rc=$?
assert "desc-tpl-render-ok"  "exit code 0 on minimal valid inputs" "$rc" "0"
assert "desc-tpl-doc-shape"  "top-level is doc / version 1"        "$(echo "$desc_rendered" | jq -r '"\(.type) v\(.version)"')" "doc v1"
# Sections rendered: Context + Goal + Scope, no Out of scope, no Acceptance criteria.
headings="$(echo "$desc_rendered" | jq -r '[.. | objects | select(.type == "heading") | .content[0].text] | join(",")')"
assert "desc-tpl-headings-min" "only Context, Goal, Scope sections render" "$headings" "Context,Goal,Scope"
# Scope bullet 2 has a bold "Second." prefix.
bold_scope="$(echo "$desc_rendered" | jq '[.. | objects | select(.marks?[]?.type == "strong") | .text] | map(select(. == "Second. ")) | length')"
assert "desc-tpl-scope-bold" "object-shape scope bullet renders bold title" "$bold_scope" "1"
# Full render: with out-of-scope + AC.
desc_rendered_full="$(jq -n \
  --arg context 'C' \
  --arg goal    'G' \
  --argjson scope                '["s"]' \
  --argjson out_of_scope         '["oos1", "oos2"]' \
  --argjson acceptance_criteria  '["ac1", "ac2", "ac3"]' \
  -f "$DESC_TEMPLATE" 2>/dev/null)"
headings_full="$(echo "$desc_rendered_full" | jq -r '[.. | objects | select(.type == "heading") | .content[0].text] | join(",")')"
assert "desc-tpl-headings-full" "all five sections render when populated" "$headings_full" "Context,Goal,Scope,Out of scope,Acceptance criteria"
# Acceptance criteria are taskItems (NOT wrapped in paragraph).
ac_violations="$(echo "$desc_rendered_full" | jq -r '[.. | objects | select(.type == "taskItem") | .content[0].type] | map(select(. == "paragraph")) | length')"
assert "desc-tpl-ac-no-para" "no taskItem wraps content in paragraph (acli INVALID_INPUT guard)" "$ac_violations" "0"
ac_count="$(echo "$desc_rendered_full" | jq '[.. | objects | select(.attrs.localId == "ac") | .content[]] | length')"
assert "desc-tpl-ac-count" "three taskItems under Acceptance criteria" "$ac_count" "3"

# --------------------------------------------------------------------------------
# md_to_adf.py — Markdown → ADF conversion used by create-ticket.sh & comment.sh.
# --------------------------------------------------------------------------------
echo
echo "== md_to_adf.py =="

if ! command -v python3 >/dev/null; then
  echo "  SKIP: python3 not on PATH"
else
  CONVERTER="$DIR/md_to_adf.py"

  # Headings → ADF heading nodes
  out="$(printf '## Heading 2\n### Heading 3\n' | python3 "$CONVERTER")"
  assert "md_to_adf-heading" "two heading nodes emitted" \
    "$(echo "$out" | jq '[.content[] | select(.type == "heading")] | length')" "2"
  assert "md_to_adf-heading" "first heading level=2" \
    "$(echo "$out" | jq '.content[0].attrs.level')" "2"
  assert "md_to_adf-heading" "second heading level=3" \
    "$(echo "$out" | jq '.content[1].attrs.level')" "3"

  # Bullet list
  out="$(printf -- '- one\n- two\n- three\n' | python3 "$CONVERTER")"
  assert "md_to_adf-bullet" "bulletList with 3 items" \
    "$(echo "$out" | jq '.content[0].content | length')" "3"
  assert "md_to_adf-bullet" "node type is bulletList" \
    "$(echo "$out" | jq -r '.content[0].type')" "bulletList"

  # Ordered list
  out="$(printf '1. step one\n2. step two\n' | python3 "$CONVERTER")"
  assert "md_to_adf-ordered" "orderedList with 2 items" \
    "$(echo "$out" | jq '.content[0].content | length')" "2"
  assert "md_to_adf-ordered" "node type is orderedList" \
    "$(echo "$out" | jq -r '.content[0].type')" "orderedList"

  # Inline marks: **strong**, `code`, [link](url), bare URL
  out="$(printf 'plain **bold** and `code` and [link](https://example.com) and https://bare.example.com.\n' | python3 "$CONVERTER")"
  assert "md_to_adf-inline" "strong mark present" \
    "$(echo "$out" | jq '[.. | objects | select(.marks?[]?.type == "strong")] | length')" "1"
  assert "md_to_adf-inline" "code mark present" \
    "$(echo "$out" | jq '[.. | objects | select(.marks?[]?.type == "code")] | length')" "1"
  assert "md_to_adf-inline" "link marks present (md link + bare URL)" \
    "$(echo "$out" | jq '[.. | objects | select(.marks?[]?.type == "link")] | length')" "2"

  # Bare URL followed by sentence punctuation: the trailing '.' is stripped from
  # the link but must survive in the prose (regression: it used to be dropped).
  out="$(printf 'See https://example.com. Next.\n' | python3 "$CONVERTER")"
  assert "md_to_adf-url-punct" "URL href has no trailing period" \
    "$(echo "$out" | jq -r '[.. | objects | select(.marks?[]?.type == "link") | .text][0]')" "https://example.com"
  assert "md_to_adf-url-punct" "stripped period survives in following text" \
    "$(echo "$out" | jq '[.. | objects | select(.text? | (. != null and contains(". Next")))] | length')" "1"

  # Blockquote (the Spec section permalink convention)
  out="$(printf '> Spec section: https://example.com/spec#anchor\n' | python3 "$CONVERTER")"
  assert "md_to_adf-blockquote" "blockquote present" \
    "$(echo "$out" | jq -r '.content[0].type')" "blockquote"

  # Fenced code block with language
  out="$(printf '```python\nprint("hi")\n```\n' | python3 "$CONVERTER")"
  assert "md_to_adf-codeblock" "codeBlock present" \
    "$(echo "$out" | jq -r '.content[0].type')" "codeBlock"
  assert "md_to_adf-codeblock" "language preserved" \
    "$(echo "$out" | jq -r '.content[0].attrs.language')" "python"

  # Task list (GitHub-flavoured checkboxes)
  out="$(printf -- '- [x] done\n- [ ] todo\n' | python3 "$CONVERTER")"
  assert "md_to_adf-task" "node type is taskList" \
    "$(echo "$out" | jq -r '.content[0].type')" "taskList"
  assert "md_to_adf-task" "two taskItems" \
    "$(echo "$out" | jq '.content[0].content | length')" "2"
  assert "md_to_adf-task" "first state DONE" \
    "$(echo "$out" | jq -r '.content[0].content[0].attrs.state')" "DONE"
  assert "md_to_adf-task" "second state TODO" \
    "$(echo "$out" | jq -r '.content[0].content[1].attrs.state')" "TODO"
  # acli rejects the payload with INVALID_INPUT if taskItem.content[0] is a paragraph.
  assert "md_to_adf-task" "no taskItem wraps content in paragraph (acli INVALID_INPUT guard)" \
    "$(echo "$out" | jq '[.. | objects | select(.type == "taskItem") | .content[0].type] | map(select(. == "paragraph")) | length')" "0"

  # Mixed: a task list followed by a bullet list lands in two separate blocks.
  out="$(printf -- '- [x] task\n- bullet\n' | python3 "$CONVERTER")"
  assert "md_to_adf-task" "task and bullet split into separate top-level blocks" \
    "$(echo "$out" | jq -r '[.content[].type] | join(",")')" "taskList,bulletList"

  # Empty input → exit 1
  printf '' | python3 "$CONVERTER" >/dev/null 2>&1; rc=$?
  assert "md_to_adf-empty" "exit code 1 (empty input)" "$rc" "1"

  # Top-level shape
  out="$(printf 'just a paragraph\n' | python3 "$CONVERTER")"
  assert "md_to_adf-shape" "top-level type is doc" "$(echo "$out" | jq -r '.type')" "doc"
  assert "md_to_adf-shape" "version is 1" "$(echo "$out" | jq '.version')" "1"
fi

# --------------------------------------------------------------------------------
# render-mermaid.py — dependency-graph emission for plan-to-tickets stdout.
# --------------------------------------------------------------------------------
echo
echo "== render-mermaid.py =="

if ! command -v python3 >/dev/null; then
  echo "  SKIP: python3 not on PATH"
else
  RM="$DIR/../../lib/render-mermaid.py"

  # Single ticket, no edges
  out="$(echo '[{"id":"M1-SE1","version":"V-Agent","blocked_by":[]}]' | python3 "$RM")"
  assert "render-mermaid-single" "header is flowchart LR" "$(echo "$out" | head -1)" "flowchart LR"
  assert "render-mermaid-single" "exactly one node line" \
    "$(echo "$out" | grep -cE '^    [A-Za-z0-9_]+\[')" "1"
  assert "render-mermaid-single" "no edge lines" \
    "$(echo "$out" | grep -cE ' --> ')" "0"

  # Edges from blocked_by
  out="$(echo '[
    {"id":"A","version":"V-Agent","blocked_by":[]},
    {"id":"B","version":"V-Agent","blocked_by":["A"]}
  ]' | python3 "$RM")"
  assert "render-mermaid-edge" "one edge emitted" "$(echo "$out" | grep -cE ' --> ')" "1"
  assert "render-mermaid-edge" "edge direction A→B" \
    "$(echo "$out" | grep -E ' --> ' | head -1 | sed -E 's/^[[:space:]]+//')" "A --> B"

  # Version classes
  out="$(echo '[
    {"id":"X","version":"V-Agent","blocked_by":[]},
    {"id":"Y","version":"V-Console","blocked_by":[]},
    {"id":"Z","version":"V-plus","blocked_by":[]}
  ]' | python3 "$RM")"
  assert "render-mermaid-classes" "vagent class applied" \
    "$(echo "$out" | grep -cE ':::vagent$')" "1"
  assert "render-mermaid-classes" "vconsole class applied" \
    "$(echo "$out" | grep -cE ':::vconsole$')" "1"
  assert "render-mermaid-classes" "vplus class applied" \
    "$(echo "$out" | grep -cE ':::vplus$')" "1"
  assert "render-mermaid-classes" "all three classDefs emitted" \
    "$(echo "$out" | grep -cE '^    classDef ')" "3"

  # short_label adds <br/>
  out="$(echo '[{"id":"M1-SE5","version":"V-Agent","blocked_by":[],"short_label":"POST /tasks"}]' | python3 "$RM")"
  assert "render-mermaid-shortlabel" "<br/> appears in node label" \
    "$(echo "$out" | grep -cE '<br/>POST /tasks')" "1"

  # Hyphenated IDs → underscore-converted mermaid identifiers
  out="$(echo '[{"id":"M1-SE1","version":"V-Agent","blocked_by":[]}]' | python3 "$RM")"
  assert "render-mermaid-idmangle" "hyphen → underscore in mermaid id" \
    "$(echo "$out" | grep -cE '^    M1_SE1\[')" "1"

  # Empty input → exit 1
  echo '[]' | python3 "$RM" >/dev/null 2>&1; rc=$?
  assert "render-mermaid-empty" "exit code 1 (empty input)" "$rc" "1"

  # Unparseable input → exit 1
  echo 'not json' | python3 "$RM" >/dev/null 2>&1; rc=$?
  assert "render-mermaid-malformed" "exit code 1 (unparseable JSON)" "$rc" "1"

  # Item missing "id" → clean exit 1, no Python traceback
  err="$(echo '[{"version":"V-Agent"}]' | python3 "$RM" 2>&1 >/dev/null)"; rc=$?
  assert "render-mermaid-noid" "exit code 1 (item without id)" "$rc" "1"
  assert "render-mermaid-noid" "no Python traceback on missing id" \
    "$(printf '%s' "$err" | grep -c 'Traceback')" "0"

  # Quotes / brackets in labels are escaped so mermaid stays well-formed
  out="$(echo '[{"id":"A","version":"V-Agent","blocked_by":[],"short_label":"say \"hi\" [x]"}]' | python3 "$RM")"
  assert "render-mermaid-escape" "node line has exactly 2 literal quotes (the delimiters)" \
    "$(echo "$out" | grep -E '^    A\[' | tr -cd '"' | wc -c | tr -d ' ')" "2"
  assert "render-mermaid-escape" "quote escaped as #quot;" \
    "$(echo "$out" | grep -cE '#quot;hi#quot;')" "1"
  assert "render-mermaid-escape" "bracket escaped as #91;/#93;" \
    "$(echo "$out" | grep -cE '#91;x#93;')" "1"
fi

echo
echo "Total: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
