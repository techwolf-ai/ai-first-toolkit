#!/usr/bin/env bash
# Test harness for the Specto linear helper scripts. Fully offline:
#   * read verbs run in --from-fixture mode, routed through _gql.sh (fixtures
#     are raw GraphQL responses, i.e. backend-shaped);
#   * mutation verbs additionally run their LIVE path against a mock `curl`
#     prepended to PATH, which logs argv, the -K auth-config file, and the
#     stdin request body, then answers canned GraphQL responses keyed on the
#     request body. That is what lets the suite assert the endpoint, the
#     mutation names + variables shapes, and that the API key never appears
#     on curl's argv (ps leakage guard).

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/.."
FIX="$HERE/fixtures"

# Shared assertion helpers + PASS/FAIL counters.
source "$HERE/../../../tests/lib/assert.sh"

# Live-path env: a fake key + a fake endpoint; the mock curl intercepts both.
LKEY="sekret-key-12345"
LEP="https://linear.mock/graphql"

# --------------------------------------------------------------------------------
# Mock curl harness. start_mock creates a temp bin dir with the mock; each live
# invocation passes PATH="$MOCKBIN:$PATH" plus the MOCK_* log paths in env.
# --------------------------------------------------------------------------------
MOCKBIN=""
MOCK_ARGS=""
MOCK_BODY=""
MOCK_HDR=""
start_mock() {
  MOCKBIN="$(mktemp -d)"
  MOCK_ARGS="$MOCKBIN/args.log"
  MOCK_BODY="$MOCKBIN/body.log"
  MOCK_HDR="$MOCKBIN/hdr.log"
  : > "$MOCK_ARGS"; : > "$MOCK_BODY"; : > "$MOCK_HDR"
  cat > "$MOCKBIN/curl" <<'EOF'
#!/usr/bin/env bash
# Offline stand-in for curl: logs argv, the -K config file, and the stdin
# body, then answers canned GraphQL responses keyed on the request body.
printf '%s\n' "$*" >> "$MOCK_ARGS"
prev=""
for a in "$@"; do
  [[ "$prev" == "-K" && -f "$a" ]] && cat "$a" >> "$MOCK_HDR"
  prev="$a"
done
body="$(cat)"
printf '%s\n' "$body" >> "$MOCK_BODY"
case "$body" in
  *issueRelationCreate*) echo '{"data":{"issueRelationCreate":{"success":true,"issueRelation":{"id":"rel-9"}}}}' ;;
  *issueRelationDelete*) echo '{"data":{"issueRelationDelete":{"success":true}}}' ;;
  *issueLabelCreate*)
    name="$(printf '%s' "$body" | jq -r '.variables.input.name')"
    printf '{"data":{"issueLabelCreate":{"success":true,"issueLabel":{"id":"new-%s"}}}}\n' "$name" ;;
  *issueLabels*)
    name="$(printf '%s' "$body" | jq -r '.variables.name')"
    if [[ -n "${MOCK_NO_LABELS:-}" ]]; then
      echo '{"data":{"issueLabels":{"nodes":[]}}}'
    else
      printf '{"data":{"issueLabels":{"nodes":[{"id":"lbl-%s","name":"%s"}]}}}\n' "$name" "$name"
    fi ;;
  *issueAddLabel*)  echo '{"data":{"issueAddLabel":{"success":true}}}' ;;
  *issueCreate*)    echo '{"data":{"issueCreate":{"success":true,"issue":{"identifier":"ENG-123","id":"uuid-new"}}}}' ;;
  *issueUpdate*)    echo '{"data":{"issueUpdate":{"success":true}}}' ;;
  *commentCreate*)  echo '{"data":{"commentCreate":{"success":true}}}' ;;
  *"teams(filter"*) echo '{"data":{"teams":{"nodes":[{"id":"team-uuid","key":"ENG","cycles":{"nodes":[{"id":"cyc-34","name":"Sprint 7","number":7}]}}]}}}' ;;
  *"users(filter"*) echo '{"data":{"users":{"nodes":[{"id":"user-alice"}]}}}' ;;
  *viewer*)         echo '{"data":{"viewer":{"id":"user-me"}}}' ;;
  *"states { nodes"*)
    echo '{"data":{"issue":{"id":"uuid-1","team":{"states":{"nodes":[{"id":"st-backlog","name":"Backlog"},{"id":"st-done","name":"Done"}]}}}}}' ;;
  *"relatedIssue { identifier }"*)   # link-tickets.sh read-back verify
    printf '{"data":{"issue":{"relations":{"nodes":[{"type":"%s","relatedIssue":{"identifier":"%s"}}]}}}}\n' \
      "${MOCK_REL_TYPE:-blocks}" "${MOCK_RELATED_TO:-ENG-200}" ;;
  *inverseRelations*)                # delete-links.sh relations read
    echo '{"data":{"issue":{"relations":{"nodes":[{"id":"rel-1","type":"blocks"}]},"inverseRelations":{"nodes":[{"id":"rel-1","type":"blocks"},{"id":"rel-2","type":"related"}]}}}}' ;;
  *"{ url }"*)
    echo '{"data":{"issue":{"url":"https://linear.app/acme/issue/ENG-123/x"}}}' ;;
  *"issue(id"*)                      # generic issue-id resolution
    id="$(printf '%s' "$body" | jq -r '.variables.id')"
    printf '{"data":{"issue":{"id":"uuid-%s"}}}\n' "$id" ;;
  *) echo '{"data":{}}' ;;
esac
EOF
  chmod +x "$MOCKBIN/curl"
}
stop_mock() { rm -rf "$MOCKBIN"; }

# --------------------------------------------------------------------------------
# _gql.sh — the single GraphQL transport
# --------------------------------------------------------------------------------
echo "== _gql.sh =="
out="$("$DIR/_gql.sh" --from-fixture "$FIX/gql-ok.json" 'query { ok }' 2>/dev/null)"; rc=$?
assert "gql-fixture" "exit code 0" "$rc" "0"
assert "gql-fixture" "returns the .data object" "$(printf '%s' "$out" | jq -r '.ok')" "true"
err="$("$DIR/_gql.sh" --from-fixture "$FIX/gql-errors.json" 'query { x }' 2>&1 >/dev/null)"; rc=$?
assert "gql-errors" "exit code 3 (GraphQL errors[])" "$rc" "3"
assert "gql-errors" "every errors[].message lands on stderr" "$(printf '%s\n' "$err" | grep -c 'linear API error:')" "2"
"$DIR/_gql.sh" --from-fixture "$FIX/gql-malformed.json" 'query { x }' >/dev/null 2>&1; rc=$?
assert "gql-malformed" "exit code 1 (unparseable fixture)" "$rc" "1"
"$DIR/_gql.sh" --from-fixture "$FIX/does-not-exist.json" 'query { x }' >/dev/null 2>&1; rc=$?
assert "gql-missing-fixture" "exit code 3 (fixture not found)" "$rc" "3"
"$DIR/_gql.sh" >/dev/null 2>&1; rc=$?
assert "gql-bad-usage" "exit code 2 (no query)" "$rc" "2"
"$DIR/_gql.sh" 'query { x }' 'not-json' >/dev/null 2>&1; rc=$?
assert "gql-bad-vars" "exit code 2 (variables not JSON)" "$rc" "2"
LINEAR_API_KEY= "$DIR/_gql.sh" 'query { x }' >/dev/null 2>&1; rc=$?
assert "gql-no-key" "exit code 3 (LINEAR_API_KEY unset)" "$rc" "3"

# Live transport against the mock curl: endpoint, auth header placement, body shape.
start_mock
out="$(PATH="$MOCKBIN:$PATH" MOCK_ARGS="$MOCK_ARGS" MOCK_BODY="$MOCK_BODY" MOCK_HDR="$MOCK_HDR" \
       LINEAR_API_KEY="$LKEY" SPECTO_LINEAR_ENDPOINT="$LEP" \
       "$DIR/_gql.sh" 'query { viewer { id } }' 2>/dev/null)"; rc=$?
assert "gql-live" "exit code 0" "$rc" "0"
assert "gql-live" "returns the .data object" "$(printf '%s' "$out" | jq -r '.viewer.id')" "user-me"
assert "gql-live" "POSTs to the configured endpoint" "$(grep -c "$LEP" "$MOCK_ARGS")" "1"
assert "gql-live" "API key is NOT on curl's argv (ps leakage)" "$(grep -c "$LKEY" "$MOCK_ARGS")" "0"
assert "gql-live" "Authorization header rides the -K config file" "$(grep -c "Authorization: $LKEY" "$MOCK_HDR")" "1"
assert "gql-live" "request body is {query, variables}" "$(jq -r 'has("query") and has("variables")' "$MOCK_BODY")" "true"
stop_mock
# Default endpoint when SPECTO_LINEAR_ENDPOINT is unset.
start_mock
PATH="$MOCKBIN:$PATH" MOCK_ARGS="$MOCK_ARGS" MOCK_BODY="$MOCK_BODY" MOCK_HDR="$MOCK_HDR" \
  LINEAR_API_KEY="$LKEY" "$DIR/_gql.sh" 'query { viewer { id } }' >/dev/null 2>&1; rc=$?
assert "gql-default-endpoint" "exit code 0" "$rc" "0"
assert "gql-default-endpoint" "defaults to https://api.linear.app/graphql" "$(grep -c 'https://api.linear.app/graphql' "$MOCK_ARGS")" "1"
stop_mock
# op:// key resolution via a mock 1Password CLI.
start_mock
cat > "$MOCKBIN/op" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == "read" ]] && echo "resolved-op-key-99"
EOF
chmod +x "$MOCKBIN/op"
PATH="$MOCKBIN:$PATH" MOCK_ARGS="$MOCK_ARGS" MOCK_BODY="$MOCK_BODY" MOCK_HDR="$MOCK_HDR" \
  LINEAR_API_KEY="op://vault/linear/api-key" SPECTO_LINEAR_ENDPOINT="$LEP" \
  "$DIR/_gql.sh" 'query { viewer { id } }' >/dev/null 2>&1; rc=$?
assert "gql-op-ref" "exit code 0 (op:// reference resolved)" "$rc" "0"
assert "gql-op-ref" "resolved key lands in the auth header" "$(grep -c 'Authorization: resolved-op-key-99' "$MOCK_HDR")" "1"
assert "gql-op-ref" "resolved key is NOT on curl's argv" "$(grep -c 'resolved-op-key-99' "$MOCK_ARGS")" "0"
stop_mock

# --------------------------------------------------------------------------------
# create-ticket.sh
# --------------------------------------------------------------------------------
echo
echo "== create-ticket.sh =="
out="$(printf 'body text\n' | "$DIR/create-ticket.sh" ENG ENG-1 "My summary" - --from-fixture "$FIX/create-ok.json" 2>/dev/null)"; rc=$?
assert "create-happy" "exit code 0" "$rc" "0"
assert "create-happy" "prints the new identifier on stdout" "$out" "ENG-123"
out="$(printf 'body\n' | "$DIR/create-ticket.sh" ENG ENG-1 "S" - --blocks ENG-5 --blocks ENG-6 --blocked-by ENG-7 --from-fixture "$FIX/create-ok.json" 2>/dev/null)"; rc=$?
assert "create-with-links" "exit code 0 (create + 3 links)" "$rc" "0"
assert "create-with-links" "still prints just the key" "$out" "ENG-123"
out="$(printf 'b\n' | "$DIR/create-ticket.sh" ENG - "S" - --from-fixture "$FIX/create-ok.json" 2>/dev/null)"; rc=$?
assert "create-no-epic-dash" "exit code 0 (epic '-' = standalone)" "$rc" "0"
out="$(printf 'b\n' | "$DIR/create-ticket.sh" ENG ENG-1 "S" - --no-epic --from-fixture "$FIX/create-ok.json" 2>/dev/null)"; rc=$?
assert "create-no-epic-flag" "exit code 0 (--no-epic accepted)" "$rc" "0"
out="$(printf 'b\n' | "$DIR/create-ticket.sh" ENG ENG-1 "Login broken" - \
  --type Bug --label "ops" --sprint-id cyc-34 --impact High --priority Urgent --assign \
  --blocks ENG-99 --from-fixture "$FIX/create-ok.json" 2>/dev/null)"; rc=$?
assert "create-bug-full-flags" "exit code 0 (Bug + all flags accepted)" "$rc" "0"
assert "create-bug-full-flags" "still prints just the key" "$out" "ENG-123"
printf 'b\n' | "$DIR/create-ticket.sh" ENG ENG-1 "S" - --from-fixture "$FIX/create-no-key.json" >/dev/null 2>&1; rc=$?
assert "create-no-key" "exit code 1 (no identifier in the response)" "$rc" "1"
"$DIR/create-ticket.sh" ENG ENG-1 >/dev/null 2>&1; rc=$?
assert "create-bad-usage" "exit code 2 (too few args)" "$rc" "2"
"$DIR/create-ticket.sh" ENG ENG-1 "S" - --bogus 1 >/dev/null 2>&1; rc=$?
assert "create-unknown-flag" "exit code 2 (rejects unknown flag)" "$rc" "2"
"$DIR/create-ticket.sh" ENG ENG-1 "S" - --label >/dev/null 2>&1; rc=$?
assert "create-label-missing-arg" "exit code 2 (bare --label rejected)" "$rc" "2"
# ADF is a capability Linear does not have: flag accepted by the parser, exit 4.
err="$(printf 'b\n' | "$DIR/create-ticket.sh" ENG ENG-1 "S" - --description-adf-file /tmp/x.json 2>&1 >/dev/null)"; rc=$?
assert "create-adf" "exit code 4 (--description-adf-file unsupported)" "$rc" "4"
assert "create-adf" "one-line not-supported reason on stderr" "$(printf '%s\n' "$err" | grep -c '^not supported on linear:')" "1"

# Live path (mock curl): the full mutation pipeline. Asserts the issueCreate
# variables shape: teamId from the teams query, markdown description
# passthrough, priority name -> Linear 0-4 scale, the specto + extra +
# impact:<v> + type labels, parentId from the epic lookup, cycleId, and the
# viewer id for --assign.
start_mock
out="$(printf 'body **md**\n' | PATH="$MOCKBIN:$PATH" MOCK_ARGS="$MOCK_ARGS" MOCK_BODY="$MOCK_BODY" MOCK_HDR="$MOCK_HDR" \
       LINEAR_API_KEY="$LKEY" SPECTO_LINEAR_ENDPOINT="$LEP" \
       "$DIR/create-ticket.sh" ENG ENG-1 "My title" - \
         --type Bug --label extra --impact High --priority High --sprint-id cyc-34 --assign 2>/dev/null)"; rc=$?
assert "create-live" "exit code 0" "$rc" "0"
assert "create-live" "prints the new identifier" "$out" "ENG-123"
cvars() { jq -r "select(.query | contains(\"issueCreate\")) | .variables.input$1" "$MOCK_BODY"; }
assert "create-live" "teamId resolved via the teams query" "$(cvars .teamId)" "team-uuid"
assert "create-live" "title carried" "$(cvars .title)" "My title"
assert "create-live" "markdown description passes through untouched" "$(cvars .description)" "body **md**"
assert "create-live" "priority High maps to 2 on the 0-4 scale" "$(cvars .priority)" "2"
assert "create-live" "cycleId carried from --sprint-id" "$(cvars .cycleId)" "cyc-34"
assert "create-live" "parentId resolved from the epic key" "$(cvars .parentId)" "uuid-ENG-1"
assert "create-live" "assigneeId is the viewer (--assign)" "$(cvars .assigneeId)" "user-me"
assert "create-live" "labels: specto + extra + impact:high + bug (type)" \
  "$(cvars '.labelIds | sort | join(",")')" "lbl-bug,lbl-extra,lbl-impact:high,lbl-specto"
assert "create-live" "teams query filters on the team key" \
  "$(jq -r 'select(.query | contains("teams(filter")) | .variables.key' "$MOCK_BODY")" "ENG"
assert "create-live" "API key never on curl argv across the whole flow" "$(grep -c "$LKEY" "$MOCK_ARGS")" "0"
stop_mock
# Missing label -> auto-created via issueLabelCreate.
start_mock
out="$(printf 'b\n' | PATH="$MOCKBIN:$PATH" MOCK_ARGS="$MOCK_ARGS" MOCK_BODY="$MOCK_BODY" MOCK_HDR="$MOCK_HDR" MOCK_NO_LABELS=1 \
       LINEAR_API_KEY="$LKEY" SPECTO_LINEAR_ENDPOINT="$LEP" \
       "$DIR/create-ticket.sh" ENG - "T" - 2>/dev/null)"; rc=$?
assert "create-live-autolabel" "exit code 0" "$rc" "0"
assert "create-live-autolabel" "specto label auto-created when missing" \
  "$(jq -r 'select(.query | contains("issueLabelCreate")) | .variables.input.name' "$MOCK_BODY")" "specto"
stop_mock
# '-' project sentinel: falls back to the repo config `project:` key.
start_mock
CFG_REPO="$(mktemp -d)"
mkdir -p "$CFG_REPO/.git" "$CFG_REPO/.specto"
printf 'project: ENG\n' > "$CFG_REPO/.specto/config.yml"
EMPTY_DATA="$(mktemp -d)"
out="$(cd "$CFG_REPO" && printf 'b\n' | PATH="$MOCKBIN:$PATH" MOCK_ARGS="$MOCK_ARGS" MOCK_BODY="$MOCK_BODY" MOCK_HDR="$MOCK_HDR" \
       CLAUDE_PLUGIN_DATA="$EMPTY_DATA" LINEAR_API_KEY="$LKEY" SPECTO_LINEAR_ENDPOINT="$LEP" \
       "$DIR/create-ticket.sh" - - "T" - 2>/dev/null)"; rc=$?
assert "create-project-config" "exit code 0 ('-' project resolves from .specto/config.yml)" "$rc" "0"
assert "create-project-config" "teams query uses the configured key" \
  "$(jq -r 'select(.query | contains("teams(filter")) | .variables.key' "$MOCK_BODY")" "ENG"
# '-' with NO config anywhere -> exit 3 with guidance.
NOCFG_REPO="$(mktemp -d)"; mkdir -p "$NOCFG_REPO/.git"
(cd "$NOCFG_REPO" && printf 'b\n' | PATH="$MOCKBIN:$PATH" MOCK_ARGS="$MOCK_ARGS" MOCK_BODY="$MOCK_BODY" MOCK_HDR="$MOCK_HDR" \
       CLAUDE_PLUGIN_DATA="$EMPTY_DATA" LINEAR_API_KEY="$LKEY" SPECTO_LINEAR_ENDPOINT="$LEP" \
       "$DIR/create-ticket.sh" - - "T" - >/dev/null 2>&1); rc=$?
assert "create-project-unset" "exit code 3 ('-' project with no config)" "$rc" "3"
rm -rf "$CFG_REPO" "$NOCFG_REPO" "$EMPTY_DATA"
stop_mock

# --------------------------------------------------------------------------------
# link-tickets.sh
# --------------------------------------------------------------------------------
echo
echo "== link-tickets.sh =="
"$DIR/link-tickets.sh" blocks ENG-100 ENG-200 --from-fixture "$FIX/link-ok.json" >/dev/null 2>&1; rc=$?
assert "link-ok" "exit code 0 (relation create succeeds)" "$rc" "0"
"$DIR/link-tickets.sh" Blocks ENG-100 ENG-200 --from-fixture "$FIX/link-ok.json" >/dev/null 2>&1; rc=$?
assert "link-ok-capitalized" "exit code 0 (jira-style 'Blocks' accepted)" "$rc" "0"
"$DIR/link-tickets.sh" blocks ENG-100 >/dev/null 2>&1; rc=$?
assert "link-bad-usage" "exit code 2 (too few args)" "$rc" "2"
err="$("$DIR/link-tickets.sh" reviews ENG-100 ENG-200 --from-fixture "$FIX/link-ok.json" 2>&1 >/dev/null)"; rc=$?
assert "link-unsupported-type" "exit code 4 (Linear has no custom link types)" "$rc" "4"
assert "link-unsupported-type" "one-line not-supported reason on stderr" "$(printf '%s\n' "$err" | grep -c '^not supported on linear:')" "1"
# Live: canonical 'blocks' -> issueRelationCreate(type: blocks) + direction verify.
start_mock
PATH="$MOCKBIN:$PATH" MOCK_ARGS="$MOCK_ARGS" MOCK_BODY="$MOCK_BODY" MOCK_HDR="$MOCK_HDR" MOCK_RELATED_TO=ENG-200 \
  LINEAR_API_KEY="$LKEY" SPECTO_LINEAR_ENDPOINT="$LEP" \
  "$DIR/link-tickets.sh" blocks ENG-100 ENG-200 >/dev/null 2>&1; rc=$?
assert "link-live-blocks" "exit code 0 (direction verifies)" "$rc" "0"
lvars() { jq -r "select(.query | contains(\"issueRelationCreate\")) | .variables.input$1" "$MOCK_BODY"; }
assert "link-live-blocks" "issueId is the FROM issue" "$(lvars .issueId)" "uuid-ENG-100"
assert "link-live-blocks" "relatedIssueId is the TO issue" "$(lvars .relatedIssueId)" "uuid-ENG-200"
assert "link-live-blocks" "relation type is blocks" "$(lvars .type)" "blocks"
stop_mock
# Live: 'Relates' maps onto Linear's 'related'.
start_mock
PATH="$MOCKBIN:$PATH" MOCK_ARGS="$MOCK_ARGS" MOCK_BODY="$MOCK_BODY" MOCK_HDR="$MOCK_HDR" MOCK_REL_TYPE=related MOCK_RELATED_TO=ENG-200 \
  LINEAR_API_KEY="$LKEY" SPECTO_LINEAR_ENDPOINT="$LEP" \
  "$DIR/link-tickets.sh" Relates ENG-100 ENG-200 >/dev/null 2>&1; rc=$?
assert "link-live-relates" "exit code 0" "$rc" "0"
assert "link-live-relates" "canonical Relates maps to Linear type 'related'" "$(lvars .type)" "related"
stop_mock
# Live: read-back shows the relation pointing elsewhere -> hard exit 3.
start_mock
err="$(PATH="$MOCKBIN:$PATH" MOCK_ARGS="$MOCK_ARGS" MOCK_BODY="$MOCK_BODY" MOCK_HDR="$MOCK_HDR" MOCK_RELATED_TO=ENG-999 \
  LINEAR_API_KEY="$LKEY" SPECTO_LINEAR_ENDPOINT="$LEP" \
  "$DIR/link-tickets.sh" blocks ENG-100 ENG-200 2>&1 >/dev/null)"; rc=$?
assert "link-live-wrong-direction" "exit code 3 (stored direction mismatch)" "$rc" "3"
assert "link-live-wrong-direction" "stderr names the direction failure" "$(printf '%s\n' "$err" | grep -c 'WRONG direction')" "1"
stop_mock

# --------------------------------------------------------------------------------
# delete-links.sh
# --------------------------------------------------------------------------------
echo
echo "== delete-links.sh =="
out="$("$DIR/delete-links.sh" ENG-100 --from-fixture "$FIX/relations-multi.json" 2>/dev/null)"; rc=$?
assert "delete-links-all" "exit code 0" "$rc" "0"
assert "delete-links-all" "de-duped ids, both directions, all types" "$(echo "$out" | tr '\n' ',')" "rel-1,rel-2,rel-3,"
out="$("$DIR/delete-links.sh" ENG-100 --type Blocks --from-fixture "$FIX/relations-multi.json" 2>/dev/null)"; rc=$?
assert "delete-links-typed" "exit code 0" "$rc" "0"
assert "delete-links-typed" "--type Blocks filters + de-dupes" "$(echo "$out" | tr '\n' ',')" "rel-1,"
out="$("$DIR/delete-links.sh" ENG-100 --type Relates --from-fixture "$FIX/relations-multi.json" 2>/dev/null)"
assert "delete-links-relates" "--type Relates maps to 'related'" "$(echo "$out" | tr '\n' ',')" "rel-2,rel-3,"
out="$("$DIR/delete-links.sh" ENG-100 --from-fixture "$FIX/relations-empty.json" 2>/dev/null)"; rc=$?
assert "delete-links-empty" "exit code 0 (no links is not an error)" "$rc" "0"
assert "delete-links-empty" "prints nothing" "$out" ""
"$DIR/delete-links.sh" --dry-run >/dev/null 2>&1; rc=$?
assert "delete-links-bad-usage" "exit code 2 (no keys)" "$rc" "2"
# Live: --dry-run lists but never mutates; a real run deletes each id once.
start_mock
out="$(PATH="$MOCKBIN:$PATH" MOCK_ARGS="$MOCK_ARGS" MOCK_BODY="$MOCK_BODY" MOCK_HDR="$MOCK_HDR" \
       LINEAR_API_KEY="$LKEY" SPECTO_LINEAR_ENDPOINT="$LEP" \
       "$DIR/delete-links.sh" ENG-100 --dry-run 2>/dev/null)"; rc=$?
assert "delete-links-live-dry" "exit code 0" "$rc" "0"
assert "delete-links-live-dry" "lists the candidate ids" "$(echo "$out" | tr '\n' ',')" "rel-1,rel-2,"
assert "delete-links-live-dry" "no delete mutation issued" "$(grep -c 'issueRelationDelete' "$MOCK_BODY")" "0"
stop_mock
start_mock
out="$(PATH="$MOCKBIN:$PATH" MOCK_ARGS="$MOCK_ARGS" MOCK_BODY="$MOCK_BODY" MOCK_HDR="$MOCK_HDR" \
       LINEAR_API_KEY="$LKEY" SPECTO_LINEAR_ENDPOINT="$LEP" \
       "$DIR/delete-links.sh" ENG-100 2>/dev/null)"; rc=$?
assert "delete-links-live" "exit code 0" "$rc" "0"
assert "delete-links-live" "prints each deleted id" "$(echo "$out" | tr '\n' ',')" "rel-1,rel-2,"
assert "delete-links-live" "one delete mutation per id" "$(grep -c 'issueRelationDelete' "$MOCK_BODY")" "2"
stop_mock

# --------------------------------------------------------------------------------
# comment.sh
# --------------------------------------------------------------------------------
echo
echo "== comment.sh =="
printf 'hello\n' | "$DIR/comment.sh" ENG-1 - --from-fixture "$FIX/comment-ok.json" >/dev/null 2>&1; rc=$?
assert "comment-stdin" "exit code 0 (body from stdin)" "$rc" "0"
printf '   \n' | "$DIR/comment.sh" ENG-1 - --from-fixture "$FIX/comment-ok.json" >/dev/null 2>&1; rc=$?
assert "comment-empty-body" "exit code 1 (empty body)" "$rc" "1"
"$DIR/comment.sh" ENG-1 >/dev/null 2>&1; rc=$?
assert "comment-bad-usage" "exit code 2 (too few args)" "$rc" "2"
# Live: markdown body passes through untouched to commentCreate.
start_mock
printf '**fixed** in `1a2b3c`\n' | PATH="$MOCKBIN:$PATH" MOCK_ARGS="$MOCK_ARGS" MOCK_BODY="$MOCK_BODY" MOCK_HDR="$MOCK_HDR" \
  LINEAR_API_KEY="$LKEY" SPECTO_LINEAR_ENDPOINT="$LEP" \
  "$DIR/comment.sh" ENG-1 - >/dev/null 2>&1; rc=$?
assert "comment-live" "exit code 0" "$rc" "0"
assert "comment-live" "markdown body passthrough" \
  "$(jq -r 'select(.query | contains("commentCreate")) | .variables.input.body' "$MOCK_BODY")" '**fixed** in `1a2b3c`'
assert "comment-live" "issueId resolved from the key" \
  "$(jq -r 'select(.query | contains("commentCreate")) | .variables.input.issueId' "$MOCK_BODY")" "uuid-ENG-1"
stop_mock

# --------------------------------------------------------------------------------
# transition-ticket.sh — synonym walk against the team's real state list
# --------------------------------------------------------------------------------
echo
echo "== transition-ticket.sh =="
out="$("$DIR/transition-ticket.sh" ENG-1 "To Do" --from-fixture "$FIX/states-altnames.json" 2>/dev/null)"; rc=$?
assert "transition-fallback-todo" "exit code 0 (literal absent, synonym matched)" "$rc" "0"
assert "transition-fallback-todo" "matched 'Backlog'" "$out" "transitioned_to=Backlog"
err="$("$DIR/transition-ticket.sh" ENG-1 "To Do" --from-fixture "$FIX/states-altnames.json" 2>&1 >/dev/null)"
assert "transition-fallback-todo" "stderr notes the synonym match" "$(printf '%s\n' "$err" | grep -c "matched synonym 'Backlog'")" "1"
out="$("$DIR/transition-ticket.sh" ENG-1 "In Review" --from-fixture "$FIX/states-altnames.json" 2>/dev/null)"; rc=$?
assert "transition-fallback-review" "exit code 0" "$rc" "0"
assert "transition-fallback-review" "matched 'Code Review'" "$out" "transitioned_to=Code Review"
out="$("$DIR/transition-ticket.sh" ENG-1 "In Progress" --from-fixture "$FIX/states-altnames.json" 2>/dev/null)"; rc=$?
assert "transition-literal-present" "exit code 0 (literal name present)" "$rc" "0"
assert "transition-literal-present" "matched literal 'In Progress'" "$out" "transitioned_to=In Progress"
err="$("$DIR/transition-ticket.sh" ENG-1 "To Do" --from-fixture "$FIX/states-weird.json" 2>&1 >/dev/null)"; rc=$?
assert "transition-no-match" "exit code 1 (no literal or synonym in workflow)" "$rc" "1"
assert "transition-no-match" "stderr lists the available states" "$(printf '%s\n' "$err" | grep -c 'Icebox')" "1"
"$DIR/transition-ticket.sh" ENG-1 >/dev/null 2>&1; rc=$?
assert "transition-bad-usage" "exit code 2 (too few args)" "$rc" "2"
# Live: the synonym-picked state id lands in issueUpdate(stateId).
start_mock
out="$(PATH="$MOCKBIN:$PATH" MOCK_ARGS="$MOCK_ARGS" MOCK_BODY="$MOCK_BODY" MOCK_HDR="$MOCK_HDR" \
       LINEAR_API_KEY="$LKEY" SPECTO_LINEAR_ENDPOINT="$LEP" \
       "$DIR/transition-ticket.sh" ENG-1 "To Do" 2>/dev/null)"; rc=$?
assert "transition-live" "exit code 0" "$rc" "0"
assert "transition-live" "prints the synonym-matched decision line" "$out" "transitioned_to=Backlog"
assert "transition-live" "issueUpdate carries the matched stateId" \
  "$(jq -r 'select(.query | contains("issueUpdate")) | .variables.input.stateId' "$MOCK_BODY")" "st-backlog"
stop_mock

# --------------------------------------------------------------------------------
# assign-ticket.sh
# --------------------------------------------------------------------------------
echo
echo "== assign-ticket.sh =="
"$DIR/assign-ticket.sh" ENG-1 user@example.com --from-fixture "$FIX/update-ok.json" >/dev/null 2>&1; rc=$?
assert "assign-explicit" "exit code 0 (fixture success)" "$rc" "0"
"$DIR/assign-ticket.sh" ENG-1 --from-fixture "$FIX/update-ok.json" >/dev/null 2>&1; rc=$?
assert "assign-default-me" "exit code 0 (default @me)" "$rc" "0"
"$DIR/assign-ticket.sh" ENG-1 --from-fixture "$FIX/update-fail.json" >/dev/null 2>&1; rc=$?
assert "assign-fail" "exit code 3 (issueUpdate success=false)" "$rc" "3"
"$DIR/assign-ticket.sh" >/dev/null 2>&1; rc=$?
assert "assign-bad-usage" "exit code 2 (no args)" "$rc" "2"
# Live: @me resolves via viewer; explicit assignee via the users query.
start_mock
PATH="$MOCKBIN:$PATH" MOCK_ARGS="$MOCK_ARGS" MOCK_BODY="$MOCK_BODY" MOCK_HDR="$MOCK_HDR" \
  LINEAR_API_KEY="$LKEY" SPECTO_LINEAR_ENDPOINT="$LEP" \
  "$DIR/assign-ticket.sh" ENG-1 >/dev/null 2>&1; rc=$?
assert "assign-live-me" "exit code 0" "$rc" "0"
assert "assign-live-me" "assigneeId is the viewer id" \
  "$(jq -r 'select(.query | contains("issueUpdate")) | .variables.input.assigneeId' "$MOCK_BODY")" "user-me"
stop_mock
start_mock
PATH="$MOCKBIN:$PATH" MOCK_ARGS="$MOCK_ARGS" MOCK_BODY="$MOCK_BODY" MOCK_HDR="$MOCK_HDR" \
  LINEAR_API_KEY="$LKEY" SPECTO_LINEAR_ENDPOINT="$LEP" \
  "$DIR/assign-ticket.sh" ENG-1 alice@example.com >/dev/null 2>&1; rc=$?
assert "assign-live-explicit" "exit code 0" "$rc" "0"
assert "assign-live-explicit" "assigneeId resolved via the users query" \
  "$(jq -r 'select(.query | contains("issueUpdate")) | .variables.input.assigneeId' "$MOCK_BODY")" "user-alice"
stop_mock

# --------------------------------------------------------------------------------
# label-ticket.sh
# --------------------------------------------------------------------------------
echo
echo "== label-ticket.sh =="
"$DIR/label-ticket.sh" ENG-1 specto --from-fixture "$FIX/label-add-ok.json" >/dev/null 2>&1; rc=$?
assert "label-ok" "exit code 0 (fixture success)" "$rc" "0"
"$DIR/label-ticket.sh" ENG-1 >/dev/null 2>&1; rc=$?
assert "label-bad-usage" "exit code 2 (no labels)" "$rc" "2"
# Live: one issueAddLabel per label, additive; missing labels are created first.
start_mock
PATH="$MOCKBIN:$PATH" MOCK_ARGS="$MOCK_ARGS" MOCK_BODY="$MOCK_BODY" MOCK_HDR="$MOCK_HDR" \
  LINEAR_API_KEY="$LKEY" SPECTO_LINEAR_ENDPOINT="$LEP" \
  "$DIR/label-ticket.sh" ENG-1 specto ops >/dev/null 2>&1; rc=$?
assert "label-live" "exit code 0" "$rc" "0"
assert "label-live" "one issueAddLabel per label" "$(grep -c 'issueAddLabel' "$MOCK_BODY")" "2"
assert "label-live" "existing label id reused (no create)" "$(grep -c 'issueLabelCreate' "$MOCK_BODY")" "0"
stop_mock
start_mock
PATH="$MOCKBIN:$PATH" MOCK_ARGS="$MOCK_ARGS" MOCK_BODY="$MOCK_BODY" MOCK_HDR="$MOCK_HDR" MOCK_NO_LABELS=1 \
  LINEAR_API_KEY="$LKEY" SPECTO_LINEAR_ENDPOINT="$LEP" \
  "$DIR/label-ticket.sh" ENG-1 brand-new >/dev/null 2>&1; rc=$?
assert "label-live-create" "exit code 0" "$rc" "0"
assert "label-live-create" "missing label auto-created" \
  "$(jq -r 'select(.query | contains("issueLabelCreate")) | .variables.input.name' "$MOCK_BODY")" "brand-new"
stop_mock

# --------------------------------------------------------------------------------
# set-parent.sh
# --------------------------------------------------------------------------------
echo
echo "== set-parent.sh =="
"$DIR/set-parent.sh" ENG-1 ENG-100 --from-fixture "$FIX/update-ok.json" >/dev/null 2>&1; rc=$?
assert "set-parent-ok" "exit code 0 (fixture success)" "$rc" "0"
"$DIR/set-parent.sh" ENG-1 --from-fixture "$FIX/update-ok.json" >/dev/null 2>&1; rc=$?
assert "set-parent-missing-parent" "exit code 2 (parent arg required)" "$rc" "2"
"$DIR/set-parent.sh" ENG-1 ENG-100 --from-fixture "$FIX/does-not-exist.json" >/dev/null 2>&1; rc=$?
assert "set-parent-bad-fixture" "exit code 3 (fixture not found)" "$rc" "3"
"$DIR/set-parent.sh" ENG-1 ENG-100 --bogus >/dev/null 2>&1; rc=$?
assert "set-parent-bad-usage" "exit code 2 (unknown flag)" "$rc" "2"
# Live: parentId resolved and applied via issueUpdate.
start_mock
PATH="$MOCKBIN:$PATH" MOCK_ARGS="$MOCK_ARGS" MOCK_BODY="$MOCK_BODY" MOCK_HDR="$MOCK_HDR" \
  LINEAR_API_KEY="$LKEY" SPECTO_LINEAR_ENDPOINT="$LEP" \
  "$DIR/set-parent.sh" ENG-1 ENG-100 >/dev/null 2>&1; rc=$?
assert "set-parent-live" "exit code 0" "$rc" "0"
assert "set-parent-live" "issueUpdate carries the parent's resolved id" \
  "$(jq -r 'select(.query | contains("issueUpdate")) | .variables.input.parentId' "$MOCK_BODY")" "uuid-ENG-100"
assert "set-parent-live" "issueUpdate targets the child's resolved id" \
  "$(jq -r 'select(.query | contains("issueUpdate")) | .variables.id' "$MOCK_BODY")" "uuid-ENG-1"
stop_mock

# --------------------------------------------------------------------------------
# get-ticket-parent.sh
# --------------------------------------------------------------------------------
echo
echo "== get-ticket-parent.sh =="
out="$("$DIR/get-ticket-parent.sh" ENG-5 --from-fixture "$FIX/ticket-parent-epic.json" 2>/dev/null)"; rc=$?
assert "parent-epic" "exit code 0" "$rc" "0"
assert "parent-epic" "real parent -> KEY<TAB>parent" "$out" "$(printf 'ENG-1\tparent')"
out="$("$DIR/get-ticket-parent.sh" ENG-5 --from-fixture "$FIX/ticket-parent-relates.json" 2>/dev/null)"; rc=$?
assert "parent-relates" "exit code 0" "$rc" "0"
assert "parent-relates" "first RELATED relation wins (blocks skipped)" "$out" "$(printf 'ENG-2\trelates')"
out="$("$DIR/get-ticket-parent.sh" ENG-5 --from-fixture "$FIX/ticket-parent-inverse.json" 2>/dev/null)"; rc=$?
assert "parent-inverse" "inverse related relation found" "$out" "$(printf 'ENG-3\trelates')"
out="$("$DIR/get-ticket-parent.sh" ENG-5 --from-fixture "$FIX/ticket-parent-none.json" 2>/dev/null)"; rc=$?
assert "parent-none" "exit code 0 (no parent is clean)" "$rc" "0"
assert "parent-none" "empty stdout" "$out" ""
"$DIR/get-ticket-parent.sh" >/dev/null 2>&1; rc=$?
assert "parent-bad-usage" "exit code 2 (no args)" "$rc" "2"

# --------------------------------------------------------------------------------
# get-ticket-type.sh
# --------------------------------------------------------------------------------
echo
echo "== get-ticket-type.sh =="
out="$("$DIR/get-ticket-type.sh" ENG-1 --from-fixture "$FIX/ticket-type-epic.json" 2>/dev/null)"; rc=$?
assert "type-epic" "exit code 0" "$rc" "0"
assert "type-epic" "issue with children -> Epic" "$out" "Epic"
out="$("$DIR/get-ticket-type.sh" ENG-2 --from-fixture "$FIX/ticket-type-bug.json" 2>/dev/null)"
assert "type-bug" "'Bug' label (case-insensitive) -> Bug" "$out" "Bug"
out="$("$DIR/get-ticket-type.sh" ENG-3 --from-fixture "$FIX/ticket-type-plain.json" 2>/dev/null)"
assert "type-plain" "no type label -> Issue fallback" "$out" "Issue"
"$DIR/get-ticket-type.sh" >/dev/null 2>&1; rc=$?
assert "type-bad-usage" "exit code 2 (no args)" "$rc" "2"

# --------------------------------------------------------------------------------
# get-ticket-status.sh / get-ticket-summary.sh
# --------------------------------------------------------------------------------
echo
echo "== get-ticket-status.sh / get-ticket-summary.sh =="
out="$("$DIR/get-ticket-status.sh" ENG-1 --from-fixture "$FIX/ticket-status.json" 2>/dev/null)"; rc=$?
assert "status-happy" "exit code 0" "$rc" "0"
assert "status-happy" "prints the live state name" "$out" "In Progress"
"$DIR/get-ticket-status.sh" ENG-1 --from-fixture "$FIX/gql-errors.json" >/dev/null 2>&1; rc=$?
assert "status-api-error" "exit code 3 (errors[] fixture propagates)" "$rc" "3"
"$DIR/get-ticket-status.sh" >/dev/null 2>&1; rc=$?
assert "status-bad-usage" "exit code 2 (no args)" "$rc" "2"
out="$("$DIR/get-ticket-summary.sh" ENG-1 --from-fixture "$FIX/ticket-summary.json" 2>/dev/null)"; rc=$?
assert "summary-happy" "exit code 0" "$rc" "0"
assert "summary-happy" "prints the title string" "$out" "Add confidence scoring to skill timeline"
"$DIR/get-ticket-summary.sh" ENG-1 --from-fixture "$FIX/ticket-desc-empty.json" >/dev/null 2>&1; rc=$?
assert "summary-missing" "exit code 1 (no title in response)" "$rc" "1"

# --------------------------------------------------------------------------------
# get-ticket-description.sh — markdown passthrough
# --------------------------------------------------------------------------------
echo
echo "== get-ticket-description.sh =="
out="$("$DIR/get-ticket-description.sh" ENG-1 --from-fixture "$FIX/ticket-desc.json" 2>/dev/null)"; rc=$?
assert "desc-happy" "exit code 0" "$rc" "0"
expected="$(printf '# Goal\n\nShip **confidence** scores via `GET /skills`.\n\n- AC1: score in [0, 1].')"
assert "desc-happy" "markdown passes through byte-for-byte" "$out" "$expected"
"$DIR/get-ticket-description.sh" ENG-1 --from-fixture "$FIX/ticket-desc-empty.json" >/dev/null 2>&1; rc=$?
assert "desc-empty" "exit code 1 (empty ticket body)" "$rc" "1"
"$DIR/get-ticket-description.sh" >/dev/null 2>&1; rc=$?
assert "desc-bad-usage" "exit code 2 (no args)" "$rc" "2"

# --------------------------------------------------------------------------------
# get-ticket-sprint.sh
# --------------------------------------------------------------------------------
echo
echo "== get-ticket-sprint.sh =="
out="$("$DIR/get-ticket-sprint.sh" ENG-1 --from-fixture "$FIX/ticket-sprint.json" 2>/dev/null)"; rc=$?
assert "sprint-happy" "exit code 0" "$rc" "0"
assert "sprint-happy" "prints the cycle id" "$out" "cyc-77"
out="$("$DIR/get-ticket-sprint.sh" ENG-1 --from-fixture "$FIX/ticket-sprint-none.json" 2>/dev/null)"; rc=$?
assert "sprint-none" "exit code 0 (not in a cycle is clean)" "$rc" "0"
assert "sprint-none" "empty stdout" "$out" ""
"$DIR/get-ticket-sprint.sh" >/dev/null 2>&1; rc=$?
assert "sprint-bad-usage" "exit code 2 (no args)" "$rc" "2"

# --------------------------------------------------------------------------------
# active-sprint.sh — cycles as sprints
# --------------------------------------------------------------------------------
echo
echo "== active-sprint.sh =="
out="$("$DIR/active-sprint.sh" ENG --from-fixture "$FIX/cycles-active.json" 2>/dev/null)"; rc=$?
assert "active-sprint-single" "exit code 0" "$rc" "0"
assert "active-sprint-single" "prints id<TAB>name on one line" "$out" "$(printf 'cyc-34\tSprint 7')"
out="$("$DIR/active-sprint.sh" ENG --from-fixture "$FIX/cycles-noname.json" 2>/dev/null)"; rc=$?
assert "active-sprint-multi" "exit code 0" "$rc" "0"
assert "active-sprint-multi" "two lines, one per active cycle" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" "2"
assert "active-sprint-multi" "nameless cycle renders as Cycle <number>" "$(printf '%s\n' "$out" | sed -n '2p')" "$(printf 'cyc-35\tCycle 42')"
out="$("$DIR/active-sprint.sh" ENG --from-fixture "$FIX/cycles-none.json" 2>/dev/null)"; rc=$?
assert "active-sprint-none" "exit code 0 (no active cycle is not an error)" "$rc" "0"
assert "active-sprint-none" "no lines on stdout" "$out" ""
"$DIR/active-sprint.sh" NOPE --from-fixture "$FIX/team-missing.json" >/dev/null 2>&1; rc=$?
assert "active-sprint-no-team" "exit code 1 (unknown team key)" "$rc" "1"
"$DIR/active-sprint.sh" >/dev/null 2>&1; rc=$?
assert "active-sprint-bad-usage" "exit code 2 (no args)" "$rc" "2"

# --------------------------------------------------------------------------------
# add-to-sprint.sh — issueUpdate(cycleId)
# --------------------------------------------------------------------------------
echo
echo "== add-to-sprint.sh =="
"$DIR/add-to-sprint.sh" cyc-34 ENG-1 --from-fixture "$FIX/update-ok.json" >/dev/null 2>&1; rc=$?
assert "sprint-add-ok" "exit code 0 (issueUpdate success fixture)" "$rc" "0"
"$DIR/add-to-sprint.sh" cyc-34 ENG-1 --from-fixture "$FIX/update-fail.json" >/dev/null 2>&1; rc=$?
assert "sprint-add-error" "exit code 3 (issueUpdate failure fixture)" "$rc" "3"
err="$("$DIR/add-to-sprint.sh" ENG-1 2>&1 >/dev/null)"; rc=$?
assert "sprint-add-legacy" "exit code 0 (legacy one-arg stub form)" "$rc" "0"
assert "sprint-add-legacy" "stderr warns about the missing SPRINT_ID" "$(printf '%s\n' "$err" | grep -c 'without a SPRINT_ID')" "1"
"$DIR/add-to-sprint.sh" >/dev/null 2>&1; rc=$?
assert "sprint-add-bad-usage" "exit code 2 (no args)" "$rc" "2"
# Live: cycleId lands in issueUpdate for the resolved issue.
start_mock
PATH="$MOCKBIN:$PATH" MOCK_ARGS="$MOCK_ARGS" MOCK_BODY="$MOCK_BODY" MOCK_HDR="$MOCK_HDR" \
  LINEAR_API_KEY="$LKEY" SPECTO_LINEAR_ENDPOINT="$LEP" \
  "$DIR/add-to-sprint.sh" cyc-34 ENG-1 >/dev/null 2>&1; rc=$?
assert "sprint-add-live" "exit code 0" "$rc" "0"
assert "sprint-add-live" "issueUpdate carries the cycleId" \
  "$(jq -r 'select(.query | contains("issueUpdate")) | .variables.input.cycleId' "$MOCK_BODY")" "cyc-34"
stop_mock

# --------------------------------------------------------------------------------
# epic-fields.sh — profile-driven classification from the epic description
# --------------------------------------------------------------------------------
echo
echo "== epic-fields.sh =="
QUESTIONS='[{"id":"Q1","flag":"security","question":"Does the change affect authentication or authorization?"},{"id":"Q3","flag":"data","question":"Will the change make permanent changes to customer data?"}]'
out="$("$DIR/epic-fields.sh" ENG-1 --questions "$QUESTIONS" --from-fixture "$FIX/epic-description.json" 2>/dev/null)"; rc=$?
assert "epic-fields-body" "exit code 0" "$rc" "0"
assert "epic-fields-body" "Q1 checked -> Yes" "$(echo "$out" | grep '^flag_Q1=')" "flag_Q1=Yes"
assert "epic-fields-body" "classification lists yes ids" "$(echo "$out" | grep '^classification=')" "classification=Non-standard (Q1 / Q3)"
assert "epic-fields-body" "resolved via body" "$(echo "$out" | grep '^resolved_via=')" "resolved_via=body"
out="$("$DIR/epic-fields.sh" ENG-1 --from-fixture "$FIX/epic-description.json" 2>/dev/null)"; rc=$?
assert "epic-fields-unconfigured" "exit code 0 without --questions" "$rc" "0"
assert "epic-fields-unconfigured" "classification unconfigured" "$(echo "$out" | grep '^classification=')" "classification=unconfigured"
"$DIR/epic-fields.sh" >/dev/null 2>&1; rc=$?
assert "epic-fields-bad-usage" "exit code 2 (no args)" "$rc" "2"


# --------------------------------------------------------------------------------
# list-children.sh — normalized [{key, summary, status, type}]
# --------------------------------------------------------------------------------
echo
echo "== list-children.sh =="
out="$("$DIR/list-children.sh" ENG-1 --from-fixture "$FIX/children.json" 2>/dev/null)"; rc=$?
assert "children-happy" "exit code 0" "$rc" "0"
assert "children-happy" "two children" "$(printf '%s' "$out" | jq 'length')" "2"
assert "children-happy" "key normalized" "$(printf '%s' "$out" | jq -r '.[0].key')" "ENG-10"
assert "children-happy" "summary normalized" "$(printf '%s' "$out" | jq -r '.[0].summary')" "Build the API"
assert "children-happy" "status normalized" "$(printf '%s' "$out" | jq -r '.[1].status')" "Todo"
assert "children-happy" "type derived from the bug label" "$(printf '%s' "$out" | jq -r '.[0].type')" "Bug"
assert "children-happy" "no type label -> Issue" "$(printf '%s' "$out" | jq -r '.[1].type')" "Issue"
assert "children-happy" "exactly the 4 normalized fields per entry" "$(printf '%s' "$out" | jq '.[0] | keys | length')" "4"
out="$("$DIR/list-children.sh" ENG-1 --from-fixture "$FIX/children-none.json" 2>/dev/null)"; rc=$?
assert "children-none" "exit code 0" "$rc" "0"
assert "children-none" "empty array" "$(printf '%s' "$out" | jq -c '.')" "[]"
"$DIR/list-children.sh" >/dev/null 2>&1; rc=$?
assert "children-bad-usage" "exit code 2 (no args)" "$rc" "2"

# --------------------------------------------------------------------------------
# ticket-url.sh — canonical browse URL from issue.url
# --------------------------------------------------------------------------------
echo
echo "== ticket-url.sh =="
out="$("$DIR/ticket-url.sh" ENG-123 --from-fixture "$FIX/url.json" 2>/dev/null)"; rc=$?
assert "url-happy" "exit code 0" "$rc" "0"
assert "url-happy" "prints the canonical browse URL" "$out" "https://linear.app/acme/issue/ENG-123/add-confidence-scoring"
"$DIR/ticket-url.sh" >/dev/null 2>&1; rc=$?
assert "url-bad-usage" "exit code 2 (no args)" "$rc" "2"
"$DIR/ticket-url.sh" ENG-123 extra >/dev/null 2>&1; rc=$?
assert "url-extra-args" "exit code 2 (unexpected extra arg)" "$rc" "2"
# Live: the url query goes out for the right key.
start_mock
out="$(PATH="$MOCKBIN:$PATH" MOCK_ARGS="$MOCK_ARGS" MOCK_BODY="$MOCK_BODY" MOCK_HDR="$MOCK_HDR" \
       LINEAR_API_KEY="$LKEY" SPECTO_LINEAR_ENDPOINT="$LEP" \
       "$DIR/ticket-url.sh" ENG-123 2>/dev/null)"; rc=$?
assert "url-live" "exit code 0" "$rc" "0"
assert "url-live" "prints the API-provided url" "$out" "https://linear.app/acme/issue/ENG-123/x"
assert "url-live" "query targets the requested key" \
  "$(jq -r 'select(.query | contains("url")) | .variables.id' "$MOCK_BODY")" "ENG-123"
stop_mock

echo
echo "Total: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
