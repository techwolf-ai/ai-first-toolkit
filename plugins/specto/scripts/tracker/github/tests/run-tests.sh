#!/usr/bin/env bash
# Test harness for the Specto github tracker helper scripts.
# Fully offline: fixture mode (--from-fixture <path>) plus a mock `gh` binary
# prepended to PATH (it logs argv, captures --body-file / stdin bodies, and
# returns canned JSON), the same two patterns as forge/gitlab/tests/. Fixtures
# are gh-shaped (what `gh issue view --json ...` / the REST endpoints return);
# the asserted output lines match the jira suite's shapes where the adapter
# contract defines them as shared.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/.."
FIXTURES="$HERE/fixtures"

# Shared assertion helpers + PASS/FAIL counters.
source "$HERE/../../../tests/lib/assert.sh"

# --------------------------------------------------------------------------------
# One mock gh for every live-path block. Behaviour toggles via env:
#   MOCK_VIEW_JSON        raw `issue view` response override
#   MOCK_VIEW_STATE       state for the default `issue view` response (OPEN)
#   MOCK_CREATE_FAIL_ONCE first `issue create` fails (label-retry scenario)
#   MOCK_EDIT_FAIL        every `issue edit` fails
#   MOCK_EDIT_FAIL_ONCE   first `issue edit` fails, later ones succeed
#   MOCK_CREATE_NUMBER    issue number in the created-issue URL (1234)
# Every call appends "GH_REPO=<env> <argv>" to $MOCK_LOG; scenario state lives
# in $MOCK_STATE (cleared per scenario).
# --------------------------------------------------------------------------------
MOCKBIN="$(mktemp -d)"
MOCK_LOG="$MOCKBIN/calls.log"
MOCK_BODY="$MOCKBIN/body.captured"
MOCK_STATE="$MOCKBIN/state"
mkdir -p "$MOCK_STATE"
cat > "$MOCKBIN/gh" <<'EOF'
#!/usr/bin/env bash
echo "GH_REPO=${GH_REPO:-} $*" >> "$MOCK_LOG"
case "${1:-} ${2:-}" in
  "issue create")
    if [[ -n "${MOCK_CREATE_FAIL_ONCE:-}" && ! -e "$MOCK_STATE/created" ]]; then
      touch "$MOCK_STATE/created"
      echo "could not add label: 'specto' not found" >&2
      exit 1
    fi
    prev=""
    for a in "$@"; do
      [[ "$prev" == "--body-file" && -f "$a" && -n "${MOCK_BODY:-}" ]] && cp "$a" "$MOCK_BODY"
      prev="$a"
    done
    echo "https://github.com/acme/widgets/issues/${MOCK_CREATE_NUMBER:-1234}"
    exit 0 ;;
  "issue view")
    if [[ -n "${MOCK_VIEW_JSON:-}" ]]; then
      echo "$MOCK_VIEW_JSON"
    else
      echo "{\"state\":\"${MOCK_VIEW_STATE:-OPEN}\"}"
    fi
    exit 0 ;;
  "issue comment")
    [[ -n "${MOCK_BODY:-}" ]] && cat > "$MOCK_BODY" || cat > /dev/null
    exit 0 ;;
  "issue edit")
    [[ -n "${MOCK_EDIT_FAIL:-}" ]] && exit 1
    if [[ -n "${MOCK_EDIT_FAIL_ONCE:-}" && ! -e "$MOCK_STATE/edited" ]]; then
      touch "$MOCK_STATE/edited"
      exit 1
    fi
    exit 0 ;;
  "issue close"|"issue reopen"|"label create") exit 0 ;;
esac
if [[ "${1:-}" == "api" ]]; then
  case "$*" in
    *milestones/*) echo '{"title":"Sprint 7"}' ;;
    *milestones*)  echo '[{"number":34,"title":"Sprint 7"}]' ;;
    *blocked_by*)  echo '[{"number":5}]' ;;
    *blocking*)    echo '[{"number":9}]' ;;
    *)             echo '{}' ;;
  esac
  exit 0
fi
exit 0
EOF
chmod +x "$MOCKBIN/gh"
export MOCK_LOG MOCK_BODY MOCK_STATE
mock_reset() { : > "$MOCK_LOG"; : > "$MOCK_BODY"; rm -f "$MOCK_STATE"/* 2>/dev/null; return 0; }

# --------------------------------------------------------------------------------
# create-ticket.sh
# --------------------------------------------------------------------------------
echo "== create-ticket.sh (fixture) =="
out="$(printf 'body text\n' | "$DIR/create-ticket.sh" acme/widgets 77 "My summary" - --from-fixture "$FIXTURES/create-ok.json" 2>/dev/null)"; rc=$?
assert "create-happy" "exit code 0" "$rc" "0"
assert "create-happy" "prints the new issue number on stdout" "$out" "1234"

out="$(printf 'body\n' | "$DIR/create-ticket.sh" PROJ 77 "S" - --blocks 5 --blocks 6 --blocked-by 7 --from-fixture "$FIXTURES/create-ok.json" 2>/dev/null)"; rc=$?
assert "create-with-links" "exit code 0 (create + 3 links)" "$rc" "0"
assert "create-with-links" "still prints just the number" "$out" "1234"

"$DIR/create-ticket.sh" PROJ 77 >/dev/null 2>&1; rc=$?
assert "create-bad-usage" "exit code 2 (too few args)" "$rc" "2"

out="$(printf 'b\n' | "$DIR/create-ticket.sh" PROJ - "S" - --from-fixture "$FIXTURES/create-ok.json" 2>/dev/null)"; rc=$?
assert "create-no-epic-dash" "exit code 0 (epic '-' = standalone)" "$rc" "0"
assert "create-no-epic-dash" "number still printed" "$out" "1234"
out="$(printf 'b\n' | "$DIR/create-ticket.sh" PROJ 77 "S" - --no-epic --from-fixture "$FIXTURES/create-ok.json" 2>/dev/null)"; rc=$?
assert "create-no-epic-flag" "exit code 0 (--no-epic overrides positional epic)" "$rc" "0"

out="$(printf 'b\n' | "$DIR/create-ticket.sh" PROJ 77 "Login broken" - \
  --type Bug --label "non-standard-change" --label "ops" \
  --sprint-id 34 --impact High --priority Urgent --assign \
  --blocks 5 \
  --from-fixture "$FIXTURES/create-ok.json" 2>/dev/null)"; rc=$?
assert "create-bug-full-flags" "exit code 0 (Bug + all flags accepted)" "$rc" "0"
assert "create-bug-full-flags" "still prints just the number" "$out" "1234"

"$DIR/create-ticket.sh" PROJ 77 "S" - --bogus 1 --from-fixture "$FIXTURES/create-ok.json" >/dev/null 2>&1; rc=$?
assert "create-unknown-flag" "exit code 2 (rejects unknown flag)" "$rc" "2"
"$DIR/create-ticket.sh" PROJ 77 "S" - --label --from-fixture "$FIXTURES/create-ok.json" >/dev/null 2>&1; rc=$?
assert "create-label-missing-arg" "exit code 2 (bare --label rejected)" "$rc" "2"

# ADF descriptions are Jira-internal: exit 4, one-line stderr, in every mode.
err="$("$DIR/create-ticket.sh" PROJ 77 "S" - --description-adf-file /tmp/x.adf --from-fixture "$FIXTURES/create-ok.json" </dev/null 2>&1 >/dev/null)"; rc=$?
assert "create-adf-unsupported" "exit code 4 (ADF has no github path)" "$rc" "4"
assert "create-adf-unsupported" "stderr says not supported on github" "$(printf '%s\n' "$err" | grep -c 'not supported on github')" "1"

echo
echo "== create-ticket.sh (mocked gh, live path) =="
# The whole flow: markdown-through create with auto labels, GH_REPO export from
# an owner/repo project, post-create type edit, parent attach, milestone
# placement, and both dependency directions.
mock_reset
out="$(printf '# Ctx\n\n**bold** body\n' | PATH="$MOCKBIN:$PATH" GH_REPO= \
  "$DIR/create-ticket.sh" acme/widgets 77 "Login broken" - \
  --type Bug --label ops --impact High --priority Urgent --assign \
  --sprint-id 34 --blocks 5 --blocked-by 6 2>/dev/null)"; rc=$?
assert "create-live" "exit code 0" "$rc" "0"
assert "create-live" "prints the parsed issue number" "$out" "1234"
assert "create-live" "create carries --label specto" "$(grep -c -- '--label specto' "$MOCK_LOG")" "1"
assert "create-live" "impact maps to a lowercased label" "$(grep -c -- '--label impact:high' "$MOCK_LOG")" "1"
assert "create-live" "priority maps to a lowercased label" "$(grep -c -- '--label priority:urgent' "$MOCK_LOG")" "1"
assert "create-live" "--assign adds --assignee @me on create" "$(grep -c -- '--assignee @me' "$MOCK_LOG")" "1"
assert "create-live" "owner/repo project exported as GH_REPO" "$(grep -c '^GH_REPO=acme/widgets issue create' "$MOCK_LOG")" "1"
assert "create-live" "non-Task type set via issue edit --type" "$(grep -c 'issue edit 1234 --type Bug' "$MOCK_LOG")" "1"
assert "create-live" "epic attached via --set-parent (native sub-issue)" "$(grep -c 'issue edit 1234 --set-parent 77' "$MOCK_LOG")" "1"
assert "create-live" "sprint-id resolved to a milestone title edit" "$(grep -c 'issue edit 1234 --milestone Sprint 7' "$MOCK_LOG")" "1"
assert "create-live" "--blocks 5: 5 becomes blocked-by the new issue" "$(grep -c 'issue edit 5 --add-blocked-by 1234' "$MOCK_LOG")" "1"
assert "create-live" "--blocked-by 6: new issue becomes blocked-by 6" "$(grep -c 'issue edit 1234 --add-blocked-by 6' "$MOCK_LOG")" "1"
assert "create-live" "markdown body passes through verbatim" "$(grep -c '\*\*bold\*\*' "$MOCK_BODY")" "1"
assert "create-live" "no ADF anywhere in the body" "$(grep -c '"type"' "$MOCK_BODY")" "0"

# A non-owner/repo project is accepted and ignored (current repo, GH_REPO empty).
mock_reset
out="$(printf 'b\n' | PATH="$MOCKBIN:$PATH" GH_REPO= "$DIR/create-ticket.sh" PROJ - "T" - 2>/dev/null)"; rc=$?
assert "create-live-project-ignored" "exit code 0" "$rc" "0"
assert "create-live-project-ignored" "bare project key leaves GH_REPO empty" "$(grep -c '^GH_REPO= issue create' "$MOCK_LOG")" "1"

# gh does not auto-create labels: a rejected create retries once after
# best-effort `gh label create` per label.
mock_reset
out="$(printf 'b\n' | PATH="$MOCKBIN:$PATH" GH_REPO= MOCK_CREATE_FAIL_ONCE=1 MOCK_CREATE_NUMBER=77 \
  "$DIR/create-ticket.sh" PROJ - "T" - 2>/dev/null)"; rc=$?
assert "create-live-label-retry" "exit code 0 (second create attempt wins)" "$rc" "0"
assert "create-live-label-retry" "prints the number from the retry" "$out" "77"
assert "create-live-label-retry" "the specto label was auto-created between attempts" "$(grep -c 'label create specto' "$MOCK_LOG")" "1"

# --------------------------------------------------------------------------------
# comment.sh
# --------------------------------------------------------------------------------
echo
echo "== comment.sh =="
printf 'hello\n' | "$DIR/comment.sh" 12 - --from-fixture "$FIXTURES/link-ok.json" >/dev/null 2>&1; rc=$?
assert "comment-stdin" "exit code 0 (body from stdin)" "$rc" "0"
printf '   \n' | "$DIR/comment.sh" 12 - --from-fixture "$FIXTURES/link-ok.json" >/dev/null 2>&1; rc=$?
assert "comment-empty-body" "exit code 1 (empty body)" "$rc" "1"
"$DIR/comment.sh" 12 >/dev/null 2>&1; rc=$?
assert "comment-bad-usage" "exit code 2 (too few args)" "$rc" "2"
mock_reset
printf '## Update\n\n**bold** note\n' | PATH="$MOCKBIN:$PATH" GH_REPO= "$DIR/comment.sh" 12 - >/dev/null 2>&1; rc=$?
assert "comment-live" "exit code 0" "$rc" "0"
assert "comment-live" "posts via gh issue comment --body-file -" "$(grep -c 'issue comment 12 --body-file -' "$MOCK_LOG")" "1"
assert "comment-live" "markdown body passes through verbatim (no ADF)" "$(grep -c '\*\*bold\*\*' "$MOCK_BODY")" "1"

# --------------------------------------------------------------------------------
# transition-ticket.sh — canonical statuses on a two-state backend
# --------------------------------------------------------------------------------
echo
echo "== transition-ticket.sh =="
out="$("$DIR/transition-ticket.sh" 12 "Done" --from-fixture "$FIXTURES/link-ok.json" 2>/dev/null)"; rc=$?
assert "transition-done" "exit code 0" "$rc" "0"
assert "transition-done" "prints transitioned_to=Done" "$out" "transitioned_to=Done"
err="$("$DIR/transition-ticket.sh" 12 "Done" --from-fixture "$FIXTURES/link-ok.json" 2>&1 >/dev/null)"
assert "transition-done" "no synonym note for the literal display name" "$(printf '%s\n' "$err" | grep -c 'note:')" "0"
out="$("$DIR/transition-ticket.sh" 12 "Closed" --from-fixture "$FIXTURES/link-ok.json" 2>/dev/null)"; rc=$?
err="$("$DIR/transition-ticket.sh" 12 "Closed" --from-fixture "$FIXTURES/link-ok.json" 2>&1 >/dev/null)"
assert "transition-synonym" "exit code 0 (jira synonym accepted)" "$rc" "0"
assert "transition-synonym" "'Closed' resolves to Done" "$out" "transitioned_to=Done"
assert "transition-synonym" "stderr notes the synonym resolution" "$(printf '%s\n' "$err" | grep -c 'note:')" "1"
out="$("$DIR/transition-ticket.sh" 12 "Code Review" --from-fixture "$FIXTURES/link-ok.json" 2>/dev/null)"
assert "transition-review-synonym" "'Code Review' resolves to In Review" "$out" "transitioned_to=In Review"
out="$("$DIR/transition-ticket.sh" 12 "in_progress" --from-fixture "$FIXTURES/link-ok.json" 2>/dev/null)"
assert "transition-canonical-token" "canonical token in_progress accepted" "$out" "transitioned_to=In Progress"
"$DIR/transition-ticket.sh" 12 "Weird Status" --from-fixture "$FIXTURES/link-ok.json" >/dev/null 2>&1; rc=$?
assert "transition-no-match" "exit code 1 (no canonical mapping)" "$rc" "1"
"$DIR/transition-ticket.sh" 12 >/dev/null 2>&1; rc=$?
assert "transition-bad-usage" "exit code 2 (too few args)" "$rc" "2"
"$DIR/transition-ticket.sh" 12 Done --from-fixture "$FIXTURES/does-not-exist.json" >/dev/null 2>&1; rc=$?
assert "transition-bad-fixture" "exit code 3 (fixture not found)" "$rc" "3"

# Live paths: done closes, todo reopens, in-between statuses degrade to labels.
mock_reset
out="$(PATH="$MOCKBIN:$PATH" GH_REPO= "$DIR/transition-ticket.sh" 12 done 2>/dev/null)"; rc=$?
assert "transition-live-done" "exit code 0" "$rc" "0"
assert "transition-live-done" "closes the open issue" "$(grep -c 'issue close 12' "$MOCK_LOG")" "1"
assert "transition-live-done" "prints transitioned_to=Done" "$out" "transitioned_to=Done"
mock_reset
PATH="$MOCKBIN:$PATH" GH_REPO= MOCK_VIEW_STATE=CLOSED "$DIR/transition-ticket.sh" 12 done >/dev/null 2>&1; rc=$?
assert "transition-live-already-closed" "exit code 0 (already closed is a no-op)" "$rc" "0"
assert "transition-live-already-closed" "no close call issued" "$(grep -c 'issue close' "$MOCK_LOG")" "0"
mock_reset
out="$(PATH="$MOCKBIN:$PATH" GH_REPO= MOCK_VIEW_STATE=CLOSED "$DIR/transition-ticket.sh" 12 "To Do" 2>/dev/null)"; rc=$?
assert "transition-live-todo" "exit code 0" "$rc" "0"
assert "transition-live-todo" "reopens the closed issue" "$(grep -c 'issue reopen 12' "$MOCK_LOG")" "1"
mock_reset
out="$(PATH="$MOCKBIN:$PATH" GH_REPO= "$DIR/transition-ticket.sh" 12 in_review 2>/dev/null)"; rc=$?
err="$(PATH="$MOCKBIN:$PATH" GH_REPO= "$DIR/transition-ticket.sh" 12 in_review 2>&1 >/dev/null)"
assert "transition-live-label" "exit code 0 (label degradation is not a failure)" "$rc" "0"
assert "transition-live-label" "adds the status:in_review label" "$(grep -c -- '--add-label status:in_review' "$MOCK_LOG")" "2"
assert "transition-live-label" "swaps out the status:in_progress label" "$(grep -c -- '--remove-label status:in_progress' "$MOCK_LOG")" "2"
assert "transition-live-label" "stderr documents the degradation" "$(printf '%s\n' "$err" | grep -c 'documented degradation')" "1"
assert "transition-live-label" "still prints transitioned_to=In Review" "$out" "transitioned_to=In Review"

# --------------------------------------------------------------------------------
# assign-ticket.sh
# --------------------------------------------------------------------------------
echo
echo "== assign-ticket.sh =="
"$DIR/assign-ticket.sh" 9 alice --from-fixture "$FIXTURES/link-ok.json" >/dev/null 2>&1; rc=$?
assert "assign-explicit" "exit code 0 (explicit assignee)" "$rc" "0"
"$DIR/assign-ticket.sh" 9 --from-fixture "$FIXTURES/link-ok.json" >/dev/null 2>&1; rc=$?
assert "assign-default-me" "exit code 0 (default @me)" "$rc" "0"
"$DIR/assign-ticket.sh" >/dev/null 2>&1; rc=$?
assert "assign-bad-usage" "exit code 2 (no args)" "$rc" "2"
mock_reset
PATH="$MOCKBIN:$PATH" GH_REPO= "$DIR/assign-ticket.sh" 9 >/dev/null 2>&1; rc=$?
assert "assign-live-default" "exit code 0" "$rc" "0"
assert "assign-live-default" "defaults to --add-assignee @me" "$(grep -c 'issue edit 9 --add-assignee @me' "$MOCK_LOG")" "1"
mock_reset
PATH="$MOCKBIN:$PATH" GH_REPO= "$DIR/assign-ticket.sh" 9 alice >/dev/null 2>&1
assert "assign-live-explicit" "explicit assignee carried through" "$(grep -c 'issue edit 9 --add-assignee alice' "$MOCK_LOG")" "1"

# --------------------------------------------------------------------------------
# label-ticket.sh
# --------------------------------------------------------------------------------
echo
echo "== label-ticket.sh =="
"$DIR/label-ticket.sh" 9 specto --from-fixture "$FIXTURES/link-ok.json" >/dev/null 2>&1; rc=$?
assert "label-fixture" "exit code 0" "$rc" "0"
"$DIR/label-ticket.sh" 9 >/dev/null 2>&1; rc=$?
assert "label-bad-usage" "exit code 2 (no labels)" "$rc" "2"
mock_reset
PATH="$MOCKBIN:$PATH" GH_REPO= "$DIR/label-ticket.sh" 9 triage ops >/dev/null 2>&1; rc=$?
assert "label-live" "exit code 0" "$rc" "0"
assert "label-live" "additive --add-label per label, one edit" "$(grep -c 'issue edit 9 --add-label triage --add-label ops' "$MOCK_LOG")" "1"
# Missing repo labels: the edit is retried once after gh label create.
mock_reset
PATH="$MOCKBIN:$PATH" GH_REPO= MOCK_EDIT_FAIL_ONCE=1 "$DIR/label-ticket.sh" 9 triage >/dev/null 2>&1; rc=$?
assert "label-live-retry" "exit code 0 (retry after label create)" "$rc" "0"
assert "label-live-retry" "auto-creates the missing label" "$(grep -c 'label create triage' "$MOCK_LOG")" "1"

# --------------------------------------------------------------------------------
# link-tickets.sh — blocks is native, everything else exits 4
# --------------------------------------------------------------------------------
echo
echo "== link-tickets.sh =="
"$DIR/link-tickets.sh" blocks 100 200 --from-fixture "$FIXTURES/link-ok.json" >/dev/null 2>&1; rc=$?
assert "link-blocks" "exit code 0 (blocks link succeeds)" "$rc" "0"
"$DIR/link-tickets.sh" Blocks 100 200 --from-fixture "$FIXTURES/link-ok.json" >/dev/null 2>&1; rc=$?
assert "link-blocks-cased" "exit code 0 (jira-cased 'Blocks' accepted)" "$rc" "0"
err="$("$DIR/link-tickets.sh" relates 100 200 --from-fixture "$FIXTURES/link-ok.json" 2>&1 >/dev/null)"; rc=$?
assert "link-relates" "exit code 4 (no native relates concept)" "$rc" "4"
assert "link-relates" "stderr says not supported on github" "$(printf '%s\n' "$err" | grep -c 'not supported on github')" "1"
"$DIR/link-tickets.sh" reviews 100 200 --from-fixture "$FIXTURES/link-ok.json" >/dev/null 2>&1; rc=$?
assert "link-other-type" "exit code 4 (arbitrary link types have no github concept)" "$rc" "4"
"$DIR/link-tickets.sh" blocks 100 >/dev/null 2>&1; rc=$?
assert "link-bad-usage" "exit code 2 (too few args)" "$rc" "2"
mock_reset
PATH="$MOCKBIN:$PATH" GH_REPO= "$DIR/link-tickets.sh" blocks 100 200 >/dev/null 2>&1; rc=$?
assert "link-live" "exit code 0" "$rc" "0"
assert "link-live" "'100 blocks 200' writes to the BLOCKED side" "$(grep -c 'issue edit 200 --add-blocked-by 100' "$MOCK_LOG")" "1"

# --------------------------------------------------------------------------------
# delete-links.sh — canonical <blocker>-blocks-<blocked> edge ids
# --------------------------------------------------------------------------------
echo
echo "== delete-links.sh =="
out="$("$DIR/delete-links.sh" 12 --from-fixture "$FIXTURES/deps.json" 2>/dev/null)"; rc=$?
assert "delete-links-all" "exit code 0" "$rc" "0"
assert "delete-links-all" "both edge directions, de-duped and sorted" "$(echo "$out" | tr '\n' ',')" "12-blocks-9,5-blocks-12,"
out="$("$DIR/delete-links.sh" 12 --type Blocks --from-fixture "$FIXTURES/deps.json" 2>/dev/null)"; rc=$?
assert "delete-links-typed" "exit code 0 (--type Blocks accepted, any casing)" "$rc" "0"
assert "delete-links-typed" "same edges under the blocks filter" "$(echo "$out" | tr '\n' ',')" "12-blocks-9,5-blocks-12,"
"$DIR/delete-links.sh" 12 --type Relates --from-fixture "$FIXTURES/deps.json" >/dev/null 2>&1; rc=$?
assert "delete-links-relates" "exit code 4 (no relates concept to filter on)" "$rc" "4"
out="$("$DIR/delete-links.sh" 12 --from-fixture "$FIXTURES/deps-empty.json" 2>/dev/null)"; rc=$?
assert "delete-links-empty" "exit code 0 (no links is not an error)" "$rc" "0"
assert "delete-links-empty" "prints nothing" "$out" ""
"$DIR/delete-links.sh" --dry-run >/dev/null 2>&1; rc=$?
assert "delete-links-bad-usage" "exit code 2 (no keys)" "$rc" "2"
mock_reset
out="$(PATH="$MOCKBIN:$PATH" GH_REPO= "$DIR/delete-links.sh" 12 --dry-run 2>/dev/null)"; rc=$?
assert "delete-links-dry-live" "exit code 0" "$rc" "0"
assert "delete-links-dry-live" "lists both REST-read edges" "$(echo "$out" | tr '\n' ',')" "12-blocks-9,5-blocks-12,"
assert "delete-links-dry-live" "dry-run deletes nothing" "$(grep -c -- '--remove-blocked-by' "$MOCK_LOG")" "0"
mock_reset
out="$(PATH="$MOCKBIN:$PATH" GH_REPO= "$DIR/delete-links.sh" 12 2>/dev/null)"; rc=$?
assert "delete-links-live" "exit code 0" "$rc" "0"
assert "delete-links-live" "removes the incoming edge from the blocked side" "$(grep -c 'issue edit 12 --remove-blocked-by 5' "$MOCK_LOG")" "1"
assert "delete-links-live" "removes the outgoing edge from the other issue" "$(grep -c 'issue edit 9 --remove-blocked-by 12' "$MOCK_LOG")" "1"
assert "delete-links-live" "prints each deleted edge id" "$(echo "$out" | tr '\n' ',')" "12-blocks-9,5-blocks-12,"

# --------------------------------------------------------------------------------
# set-parent.sh — native sub-issue attach, soft-fail exit 3
# --------------------------------------------------------------------------------
echo
echo "== set-parent.sh =="
"$DIR/set-parent.sh" 1 100 --from-fixture "$FIXTURES/link-ok.json" >/dev/null 2>&1; rc=$?
assert "set-parent-ok" "exit code 0 (fixture short-circuit)" "$rc" "0"
"$DIR/set-parent.sh" 1 --from-fixture "$FIXTURES/link-ok.json" >/dev/null 2>&1; rc=$?
assert "set-parent-missing-parent" "exit code 2 (parent arg required)" "$rc" "2"
"$DIR/set-parent.sh" 1 100 --from-fixture "$FIXTURES/does-not-exist.json" >/dev/null 2>&1; rc=$?
assert "set-parent-bad-fixture" "exit code 3 (fixture not found)" "$rc" "3"
"$DIR/set-parent.sh" 1 100 --bogus >/dev/null 2>&1; rc=$?
assert "set-parent-bad-usage" "exit code 2 (unknown flag)" "$rc" "2"
mock_reset
PATH="$MOCKBIN:$PATH" GH_REPO= "$DIR/set-parent.sh" 1 100 >/dev/null 2>&1; rc=$?
assert "set-parent-live" "exit code 0" "$rc" "0"
assert "set-parent-live" "edits the child with --set-parent" "$(grep -c 'issue edit 1 --set-parent 100' "$MOCK_LOG")" "1"
mock_reset
PATH="$MOCKBIN:$PATH" GH_REPO= MOCK_EDIT_FAIL=1 "$DIR/set-parent.sh" 1 100 >/dev/null 2>&1; rc=$?
assert "set-parent-live-fail" "exit code 3 (soft failure, caller falls back)" "$rc" "3"

# --------------------------------------------------------------------------------
# get-ticket-parent.sh
# --------------------------------------------------------------------------------
echo
echo "== get-ticket-parent.sh =="
out="$("$DIR/get-ticket-parent.sh" 300 --from-fixture "$FIXTURES/ticket-parent.json" 2>/dev/null)"; rc=$?
assert "parent-native" "exit code 0" "$rc" "0"
assert "parent-native" "prints <KEY>\\tparent" "$out" "$(printf '100\tparent')"
out="$("$DIR/get-ticket-parent.sh" 301 --from-fixture "$FIXTURES/ticket-parent-none.json" 2>/dev/null)"; rc=$?
assert "parent-none" "exit code 0 (no parent, clean empty)" "$rc" "0"
assert "parent-none" "stdout empty when no parent" "$out" ""
"$DIR/get-ticket-parent.sh" 300 --from-fixture "$FIXTURES/malformed.json" >/dev/null 2>&1; rc=$?
assert "parent-malformed" "exit code 1 (unparseable JSON)" "$rc" "1"
"$DIR/get-ticket-parent.sh" >/dev/null 2>&1; rc=$?
assert "parent-bad-usage" "exit code 2 (no args)" "$rc" "2"

# --------------------------------------------------------------------------------
# get-ticket-type.sh — native type, epic detection, Issue fallback
# --------------------------------------------------------------------------------
echo
echo "== get-ticket-type.sh =="
out="$("$DIR/get-ticket-type.sh" 200 --from-fixture "$FIXTURES/ticket-type-bug.json" 2>/dev/null)"; rc=$?
assert "type-native" "exit code 0" "$rc" "0"
assert "type-native" "prints the native issue type" "$out" "Bug"
out="$("$DIR/get-ticket-type.sh" 100 --from-fixture "$FIXTURES/ticket-type-subissues.json" 2>/dev/null)"
assert "type-subissues" "issue with sub-issues reads as Epic" "$out" "Epic"
out="$("$DIR/get-ticket-type.sh" 100 --from-fixture "$FIXTURES/ticket-type-epic-label.json" 2>/dev/null)"
assert "type-epic-label" "an 'epic' label (any casing) reads as Epic" "$out" "Epic"
out="$("$DIR/get-ticket-type.sh" 100 --from-fixture "$FIXTURES/ticket-type-plain.json" 2>/dev/null)"
assert "type-fallback" "no type, no sub-issues: falls back to Issue" "$out" "Issue"
"$DIR/get-ticket-type.sh" 100 --from-fixture "$FIXTURES/malformed.json" >/dev/null 2>&1; rc=$?
assert "type-malformed" "exit code 1 (unparseable JSON)" "$rc" "1"
"$DIR/get-ticket-type.sh" >/dev/null 2>&1; rc=$?
assert "type-bad-usage" "exit code 2 (no args)" "$rc" "2"

# --------------------------------------------------------------------------------
# get-ticket-status.sh — state mapping + status:* label override
# --------------------------------------------------------------------------------
echo
echo "== get-ticket-status.sh =="
out="$("$DIR/get-ticket-status.sh" 500 --from-fixture "$FIXTURES/ticket-status-closed.json" 2>/dev/null)"; rc=$?
assert "status-closed" "exit code 0" "$rc" "0"
assert "status-closed" "closed state reads as Done" "$out" "Done"
out="$("$DIR/get-ticket-status.sh" 500 --from-fixture "$FIXTURES/ticket-status-open.json" 2>/dev/null)"
assert "status-open" "open state without label reads as To Do" "$out" "To Do"
out="$("$DIR/get-ticket-status.sh" 500 --from-fixture "$FIXTURES/ticket-status-label.json" 2>/dev/null)"
assert "status-label" "status:in_review label overrides on an open issue" "$out" "In Review"
out="$("$DIR/get-ticket-status.sh" 500 --from-fixture "$FIXTURES/ticket-status-label-custom.json" 2>/dev/null)"
assert "status-label-custom" "unknown status:<v> value prints verbatim" "$out" "blocked"
out="$("$DIR/get-ticket-status.sh" 500 --from-fixture "$FIXTURES/ticket-status-closed-label.json" 2>/dev/null)"
assert "status-closed-wins" "closed state beats a stale status label" "$out" "Done"
"$DIR/get-ticket-status.sh" >/dev/null 2>&1; rc=$?
assert "status-bad-usage" "exit code 2 (no args)" "$rc" "2"

# --------------------------------------------------------------------------------
# get-ticket-summary.sh
# --------------------------------------------------------------------------------
echo
echo "== get-ticket-summary.sh =="
out="$("$DIR/get-ticket-summary.sh" 4242 --from-fixture "$FIXTURES/ticket-summary.json" 2>/dev/null)"; rc=$?
assert "summary-happy" "exit code 0" "$rc" "0"
assert "summary-happy" "prints the title string" "$out" "Add confidence scoring to skill timeline"
"$DIR/get-ticket-summary.sh" 1 --from-fixture "$FIXTURES/ticket-no-title.json" >/dev/null 2>&1; rc=$?
assert "summary-missing" "exit code 1 (no .title)" "$rc" "1"
"$DIR/get-ticket-summary.sh" 1 --from-fixture "$FIXTURES/malformed.json" >/dev/null 2>&1; rc=$?
assert "summary-malformed" "exit code 1 (unparseable JSON)" "$rc" "1"
"$DIR/get-ticket-summary.sh" >/dev/null 2>&1; rc=$?
assert "summary-bad-usage" "exit code 2 (no args)" "$rc" "2"

# --------------------------------------------------------------------------------
# get-ticket-description.sh — markdown passthrough, byte-for-byte
# --------------------------------------------------------------------------------
echo
echo "== get-ticket-description.sh =="
md="$("$DIR/get-ticket-description.sh" 4242 --from-fixture "$FIXTURES/ticket-body.json" 2>/dev/null)"; rc=$?
assert "desc-happy" "exit code 0" "$rc" "0"
assert "desc-happy" "heading passes through verbatim" "$(printf '%s\n' "$md" | grep -c '^# Goal$')" "1"
assert "desc-happy" "bold + italic marks untouched" "$(printf '%s\n' "$md" | grep -c '\*\*calibrator\*\* to _prod_')" "1"
assert "desc-happy" "task-list checkbox untouched" "$(printf '%s\n' "$md" | grep -c '^- \[ \] AC one$')" "1"
"$DIR/get-ticket-description.sh" 1 --from-fixture "$FIXTURES/ticket-body-empty.json" >/dev/null 2>&1; rc=$?
assert "desc-empty" "exit code 1 (empty ticket body)" "$rc" "1"
"$DIR/get-ticket-description.sh" >/dev/null 2>&1; rc=$?
assert "desc-bad-usage" "exit code 2 (no args)" "$rc" "2"

# --------------------------------------------------------------------------------
# get-ticket-sprint.sh — sprint = milestone
# --------------------------------------------------------------------------------
echo
echo "== get-ticket-sprint.sh =="
out="$("$DIR/get-ticket-sprint.sh" 400 --from-fixture "$FIXTURES/ticket-milestone.json" 2>/dev/null)"; rc=$?
assert "sprint-of-ticket" "exit code 0" "$rc" "0"
assert "sprint-of-ticket" "prints the milestone number" "$out" "34"
out="$("$DIR/get-ticket-sprint.sh" 401 --from-fixture "$FIXTURES/ticket-milestone-none.json" 2>/dev/null)"; rc=$?
assert "sprint-of-ticket-none" "exit code 0 (no milestone, clean empty)" "$rc" "0"
assert "sprint-of-ticket-none" "stdout empty when no milestone" "$out" ""
out="$("$DIR/get-ticket-sprint.sh" 402 --from-fixture "$FIXTURES/ticket-milestone-closed.json" 2>/dev/null)"
assert "sprint-of-ticket-closed" "a closed milestone is not an active sprint" "$out" ""
"$DIR/get-ticket-sprint.sh" >/dev/null 2>&1; rc=$?
assert "sprint-of-ticket-bad-usage" "exit code 2 (no args)" "$rc" "2"

# --------------------------------------------------------------------------------
# active-sprint.sh — open milestones as <id>\t<name> rows
# --------------------------------------------------------------------------------
echo
echo "== active-sprint.sh =="
out="$("$DIR/active-sprint.sh" 12 --from-fixture "$FIXTURES/milestones-open.json" 2>/dev/null)"; rc=$?
assert "active-sprint-single" "exit code 0" "$rc" "0"
assert "active-sprint-single" "prints id<TAB>name on one line (jira row parity)" "$out" "$(printf '34\tSprint 7')"
out="$("$DIR/active-sprint.sh" 12 --from-fixture "$FIXTURES/milestones-multi.json" 2>/dev/null)"
assert "active-sprint-multi" "two lines, one per open milestone" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" "2"
out="$("$DIR/active-sprint.sh" 12 --from-fixture "$FIXTURES/milestones-none.json" 2>/dev/null)"; rc=$?
assert "active-sprint-none" "exit code 0 (no milestones is not an error)" "$rc" "0"
assert "active-sprint-none" "no lines on stdout" "$out" ""
"$DIR/active-sprint.sh" >/dev/null 2>&1; rc=$?
assert "active-sprint-bad-usage" "exit code 2 (no args)" "$rc" "2"
mock_reset
out="$(PATH="$MOCKBIN:$PATH" GH_REPO= "$DIR/active-sprint.sh" ignored-board-id 2>/dev/null)"; rc=$?
assert "active-sprint-live" "exit code 0" "$rc" "0"
assert "active-sprint-live" "hits the open-milestones REST endpoint" "$(grep -c 'milestones?state=open' "$MOCK_LOG")" "1"
assert "active-sprint-live" "emits the normalized row" "$out" "$(printf '34\tSprint 7')"

# --------------------------------------------------------------------------------
# add-to-sprint.sh — milestone placement by number
# --------------------------------------------------------------------------------
echo
echo "== add-to-sprint.sh =="
"$DIR/add-to-sprint.sh" 34 12 --from-fixture "$FIXTURES/sprint-add-ok.json" >/dev/null 2>&1; rc=$?
assert "sprint-add-ok" "exit code 0 (success fixture)" "$rc" "0"
"$DIR/add-to-sprint.sh" 9999 12 --from-fixture "$FIXTURES/sprint-add-error.json" >/dev/null 2>&1; rc=$?
assert "sprint-add-error" "exit code 3 (error fixture)" "$rc" "3"
"$DIR/add-to-sprint.sh" 12 >/dev/null 2>&1; rc=$?
assert "sprint-add-legacy" "exit code 0 (legacy one-arg stub form)" "$rc" "0"
"$DIR/add-to-sprint.sh" >/dev/null 2>&1; rc=$?
assert "sprint-add-bad-usage" "exit code 2 (no args)" "$rc" "2"
mock_reset
PATH="$MOCKBIN:$PATH" GH_REPO= "$DIR/add-to-sprint.sh" 34 12 >/dev/null 2>&1; rc=$?
assert "sprint-add-live" "exit code 0" "$rc" "0"
assert "sprint-add-live" "resolves the milestone number via REST" "$(grep -c 'milestones/34' "$MOCK_LOG")" "1"
assert "sprint-add-live" "edits the issue with the resolved title" "$(grep -c 'issue edit 12 --milestone Sprint 7' "$MOCK_LOG")" "1"

# --------------------------------------------------------------------------------
# epic-fields.sh — profile-driven classification from the epic issue body
# --------------------------------------------------------------------------------
echo
echo "== epic-fields.sh =="
QUESTIONS='[{"id":"Q1","flag":"security","question":"Does the change affect authentication or authorization?"},{"id":"Q2","flag":"availability","question":"Could the change impact the availability of services?"},{"id":"Q3","flag":"data","question":"Will the change make permanent changes to customer data?"}]'
out="$("$DIR/epic-fields.sh" 100 --questions "$QUESTIONS" --from-fixture "$FIXTURES/epic-body.json" 2>/dev/null)"; rc=$?
assert "epic-fields-body" "exit code 0" "$rc" "0"
assert "epic-fields-body" "Q1 checked -> Yes" "$(echo "$out" | grep '^flag_Q1=')" "flag_Q1=Yes"
assert "epic-fields-body" "Q2 unchecked -> No" "$(echo "$out" | grep '^flag_Q2=')" "flag_Q2=No"
assert "epic-fields-body" "classification lists yes ids" "$(echo "$out" | grep '^classification=')" "classification=Non-standard (Q1 / Q3)"
assert "epic-fields-body" "resolved via body" "$(echo "$out" | grep '^resolved_via=')" "resolved_via=body"
out="$("$DIR/epic-fields.sh" 100 --questions "$QUESTIONS" --from-fixture "$FIXTURES/epic-body-noblock.json" 2>/dev/null)"; rc=$?
assert "epic-fields-noblock" "exit code 0" "$rc" "0"
assert "epic-fields-noblock" "all flags default No" "$(echo "$out" | grep -c '=No$')" "3"
assert "epic-fields-noblock" "classification Standard" "$(echo "$out" | grep '^classification=')" "classification=Standard"
out="$("$DIR/epic-fields.sh" 100 --from-fixture "$FIXTURES/epic-body.json" 2>/dev/null)"; rc=$?
assert "epic-fields-unconfigured" "exit code 0 without --questions" "$rc" "0"
assert "epic-fields-unconfigured" "classification unconfigured" "$(echo "$out" | grep '^classification=')" "classification=unconfigured"
"$DIR/epic-fields.sh" >/dev/null 2>&1; rc=$?
assert "epic-fields-bad-usage" "exit code 2 (no args)" "$rc" "2"
"$DIR/epic-fields.sh" 100 --questions 'not-json' --from-fixture "$FIXTURES/epic-body.json" >/dev/null 2>&1; rc=$?
assert "epic-fields-bad-usage" "exit code 2 (non-array questions)" "$rc" "2"

# --------------------------------------------------------------------------------
# list-children.sh — normalized sub-issue array
# --------------------------------------------------------------------------------
echo
echo "== list-children.sh =="
out="$("$DIR/list-children.sh" 100 --from-fixture "$FIXTURES/children.json" 2>/dev/null)"; rc=$?
assert "children-happy" "exit code 0" "$rc" "0"
assert "children-happy" "returns a 2-element array" "$(printf '%s' "$out" | jq 'length')" "2"
assert "children-happy" "key normalized to a string number" "$(printf '%s' "$out" | jq -r '.[0].key')" "101"
assert "children-happy" "summary normalized" "$(printf '%s' "$out" | jq -r '.[0].summary')" "Wire the scoring endpoint"
assert "children-happy" "OPEN state normalized to To Do" "$(printf '%s' "$out" | jq -r '.[0].status')" "To Do"
assert "children-happy" "CLOSED state normalized to Done" "$(printf '%s' "$out" | jq -r '.[1].status')" "Done"
assert "children-happy" "type normalized from the native issue type" "$(printf '%s' "$out" | jq -r '.[1].type')" "Bug"
assert "children-happy" "exactly the 4 contract fields per entry" "$(printf '%s' "$out" | jq '.[0] | keys | length')" "4"
out="$("$DIR/list-children.sh" 100 --from-fixture "$FIXTURES/children-empty.json" 2>/dev/null)"; rc=$?
assert "children-empty" "exit code 0 (childless epic)" "$rc" "0"
assert "children-empty" "empty JSON array" "$(printf '%s' "$out" | jq 'length')" "0"
"$DIR/list-children.sh" 100 --from-fixture "$FIXTURES/children-missing.json" >/dev/null 2>&1; rc=$?
assert "children-missing" "exit code 1 (no sub-issue array in the payload)" "$rc" "1"
"$DIR/list-children.sh" 100 --from-fixture "$FIXTURES/malformed.json" >/dev/null 2>&1; rc=$?
assert "children-malformed" "exit code 1 (unparseable JSON)" "$rc" "1"
"$DIR/list-children.sh" >/dev/null 2>&1; rc=$?
assert "children-bad-usage" "exit code 2 (no args)" "$rc" "2"

# --------------------------------------------------------------------------------
# ticket-url.sh — canonical browse URL straight from gh (no config)
# --------------------------------------------------------------------------------
echo
echo "== ticket-url.sh =="
mock_reset
out="$(PATH="$MOCKBIN:$PATH" GH_REPO= MOCK_VIEW_JSON='{"url":"https://github.com/acme/widgets/issues/123"}' "$DIR/ticket-url.sh" 123 2>/dev/null)"; rc=$?
assert "ticket-url" "exit code 0" "$rc" "0"
assert "ticket-url" "prints the canonical browse URL" "$out" "https://github.com/acme/widgets/issues/123"
assert "ticket-url" "reads it via gh issue view --json url" "$(grep -c 'issue view 123 --json url' "$MOCK_LOG")" "1"
mock_reset
PATH="$MOCKBIN:$PATH" GH_REPO= MOCK_VIEW_JSON='{}' "$DIR/ticket-url.sh" 123 >/dev/null 2>&1; rc=$?
assert "ticket-url-missing" "exit code 1 (no url in the response)" "$rc" "1"
"$DIR/ticket-url.sh" >/dev/null 2>&1; rc=$?
assert "ticket-url-bad-usage" "exit code 2 (no args)" "$rc" "2"
"$DIR/ticket-url.sh" 123 extra >/dev/null 2>&1; rc=$?
assert "ticket-url-extra-args" "exit code 2 (exactly one arg expected)" "$rc" "2"

rm -rf "$MOCKBIN"

echo
echo "Total: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
