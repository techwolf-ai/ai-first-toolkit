#!/usr/bin/env bash
# Test harness for the Specto github forge helper scripts.
# Two offline patterns, mirroring the gitlab suite: --from-fixture <dir> mode
# (no gh, no network: fixtures are GitHub-shaped raw API/CLI responses that
# the helpers normalize) and a mock `gh` binary on PATH logging argv + stdin
# so live-path request shapes (GraphQL mutation names, REST payloads, flags)
# can be asserted without any network call.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/.."
FIX="$HERE/fixtures"

# Shared assertion helpers + PASS/FAIL counters.
source "$HERE/../../../tests/lib/assert.sh"

# --------------------------------------------------------------------------------
# mr-fetch.sh info: gh pr view shape -> change-request object
# --------------------------------------------------------------------------------
echo "== mr-fetch.sh info =="
out="$("$DIR/mr-fetch.sh" info --from-fixture "$FIX/pr-open" 2>/dev/null)"; rc=$?
assert "mr-fetch-info" "exit code 0" "$rc" "0"
assert "mr-fetch-info" "iid mapped from PR number" "$(printf '%s' "$out" | jq -r '.iid')" "7"
assert "mr-fetch-info" "web_url mapped from url" "$(printf '%s' "$out" | jq -r '.web_url')" "https://github.com/acme/widgets/pull/7"
assert "mr-fetch-info" "state OPEN -> opened" "$(printf '%s' "$out" | jq -r '.state')" "opened"
assert "mr-fetch-info" "draft mapped from isDraft" "$(printf '%s' "$out" | jq -r '.draft')" "true"
assert "mr-fetch-info" "source_branch mapped from headRefName" "$(printf '%s' "$out" | jq -r '.source_branch')" "f-app-1"
assert "mr-fetch-info" "target_branch mapped from baseRefName" "$(printf '%s' "$out" | jq -r '.target_branch')" "main"
assert "mr-fetch-info" "head_sha = headRefOid" "$(printf '%s' "$out" | jq -r '.diff_refs.head_sha')" "head111"
assert "mr-fetch-info" "base_sha = baseRefOid" "$(printf '%s' "$out" | jq -r '.diff_refs.base_sha')" "base000"
assert "mr-fetch-info" "start_sha = base_sha (no distinct start SHA on GitHub)" "$(printf '%s' "$out" | jq -r '.diff_refs.start_sha')" "base000"
assert "mr-fetch-info" "description carried (mr-describe relies on it)" "$(printf '%s' "$out" | jq -r '.description')" "Existing PR summary."
out="$("$DIR/mr-fetch.sh" info --from-fixture "$FIX/pr-merged" 2>/dev/null)"
assert "mr-fetch-info-merged" "state MERGED -> merged" "$(printf '%s' "$out" | jq -r '.state')" "merged"

# --------------------------------------------------------------------------------
# mr-fetch.sh discussions: GraphQL reviewThreads + issue comments + reviews
# --------------------------------------------------------------------------------
echo
echo "== mr-fetch.sh discussions =="
out="$("$DIR/mr-fetch.sh" discussions --from-fixture "$FIX/pr-open" 2>/dev/null)"; rc=$?
assert "mr-fetch-discussions" "exit code 0" "$rc" "0"
# Two GraphQL pages (1 thread each) + 1 issue comment + 1 non-empty review = 4.
assert "mr-fetch-discussions" "two pages merged + comments + reviews = 4 threads" "$(printf '%s' "$out" | jq 'length')" "4"
assert "mr-fetch-discussions" "thread id = GraphQL node id" "$(printf '%s' "$out" | jq -r '.[0].id')" "PRRT_t1"
assert "mr-fetch-discussions" "second-page thread present (pagination)" "$(printf '%s' "$out" | jq -r '.[1].id')" "PRRT_t2"
assert "mr-fetch-discussions" "note body carried" "$(printf '%s' "$out" | jq -r '.[0].notes[0].body')" "plain human comment about the metric table"
assert "mr-fetch-discussions" "author.username from author.login" "$(printf '%s' "$out" | jq -r '.[0].notes[0].author.username')" "alice"
assert "mr-fetch-discussions" "review-thread notes are resolvable" "$(printf '%s' "$out" | jq -r '.[0].notes[0].resolvable')" "true"
assert "mr-fetch-discussions" "resolved from thread isResolved" "$(printf '%s' "$out" | jq -r '.[1].notes[0].resolved')" "true"
assert "mr-fetch-discussions" "system is false (no system notes on GitHub)" "$(printf '%s' "$out" | jq -r '.[0].notes[0].system')" "false"
assert "mr-fetch-discussions" "position.new_path from thread path" "$(printf '%s' "$out" | jq -r '.[0].notes[0].position.new_path')" "docs/development/specs/x/product-spec.md"
assert "mr-fetch-discussions" "position.new_line from thread line" "$(printf '%s' "$out" | jq -r '.[0].notes[0].position.new_line')" "12"
assert "mr-fetch-discussions" "outdated thread (line null) falls back to originalLine" "$(printf '%s' "$out" | jq -r '.[1].notes[0].position.new_line')" "33"
assert "mr-fetch-discussions" "created_at carried" "$(printf '%s' "$out" | jq -r '.[0].notes[0].created_at')" "2026-07-01T10:00:00Z"
# Synthetic threads: issue comments + review summaries merged in (bot-comment parity).
assert "mr-fetch-discussions" "issue comment merged as a synthetic thread" "$(printf '%s' "$out" | jq -r '.[2].id')" "IC_201"
assert "mr-fetch-discussions" "issue-comment thread is NOT resolvable" "$(printf '%s' "$out" | jq -r '.[2].notes[0].resolvable')" "false"
assert "mr-fetch-discussions" "issue-comment note has no position" "$(printf '%s' "$out" | jq -r '.[2].notes[0].position')" "null"
assert "mr-fetch-discussions" "non-empty review summary merged" "$(printf '%s' "$out" | jq -r '.[3].id')" "PRR_301"
assert "mr-fetch-discussions" "review summary body carried" "$(printf '%s' "$out" | jq -r '.[3].notes[0].body')" "Overall looks solid, two nits inline."
assert "mr-fetch-discussions" "empty-body review (bare approval) is dropped" "$(printf '%s' "$out" | jq '[.[] | select(.id == "PRR_302")] | length')" "0"

# --------------------------------------------------------------------------------
# mr-fetch.sh diff: pulls/{n}/files -> per-file diff array
# --------------------------------------------------------------------------------
echo
echo "== mr-fetch.sh diff =="
out="$("$DIR/mr-fetch.sh" diff --from-fixture "$FIX/pr-open" 2>/dev/null)"; rc=$?
assert "mr-fetch-diff" "exit code 0" "$rc" "0"
assert "mr-fetch-diff" "two fixture pages flattened to 5 entries" "$(printf '%s' "$out" | jq 'length')" "5"
assert "mr-fetch-diff" "new_path from filename" "$(printf '%s' "$out" | jq -r '.[0].new_path')" "docs/development/specs/x/product-spec.md"
assert "mr-fetch-diff" "old_path defaults to filename" "$(printf '%s' "$out" | jq -r '.[0].old_path')" "docs/development/specs/x/product-spec.md"
assert "mr-fetch-diff" "patch passthrough keeps the @@ header" "$(printf '%s' "$out" | jq -r '.[0].diff' | head -1)" "@@ -10,3 +10,5 @@"
assert "mr-fetch-diff" "status added -> new_file" "$(printf '%s' "$out" | jq -r '.[1].new_file')" "true"
assert "mr-fetch-diff" "renamed: old_path from previous_filename" "$(printf '%s' "$out" | jq -r '.[2].old_path')" "src/old-name.py"
assert "mr-fetch-diff" "status renamed -> renamed_file" "$(printf '%s' "$out" | jq -r '.[2].renamed_file')" "true"
assert "mr-fetch-diff" "missing patch (binary) -> empty diff" "$(printf '%s' "$out" | jq -r '.[3].diff')" ""
assert "mr-fetch-diff" "status removed -> deleted_file" "$(printf '%s' "$out" | jq -r '.[4].deleted_file')" "true"

# Live path (mocked gh): the diff read must hit pulls/{n}/files with --paginate
# and flatten the per-page arrays.
MOCKBIN="$(mktemp -d)"; MOCK_LOG="$MOCKBIN/calls.log"
cat > "$MOCKBIN/gh" <<'EOF'
#!/usr/bin/env bash
echo "$@" >> "$MOCK_LOG"
case "$1 ${2:-}" in
  "repo view") echo "acme/widgets"; exit 0 ;;
  "api "*)
    cat "$MOCK_FIX/files.json"
    exit 0 ;;
esac
exit 0
EOF
chmod +x "$MOCKBIN/gh"
out="$(PATH="$MOCKBIN:$PATH" MOCK_LOG="$MOCK_LOG" MOCK_FIX="$FIX/pr-open" "$DIR/mr-fetch.sh" diff --iid 5 2>/dev/null)"; rc=$?
assert "mr-fetch-diff-live" "exit code 0" "$rc" "0"
assert "mr-fetch-diff-live" "hits pulls/5/files with --paginate" "$(grep -c 'repos/acme/widgets/pulls/5/files --paginate' "$MOCK_LOG")" "1"
assert "mr-fetch-diff-live" "pages flattened to one array" "$(printf '%s' "$out" | jq 'length')" "5"
rm -rf "$MOCKBIN"

# Live path (mocked gh): discussions must run the reviewThreads GraphQL query
# (paginated) AND merge the pr view comments,reviews synthetics.
MOCKBIN="$(mktemp -d)"; MOCK_LOG="$MOCKBIN/calls.log"
cat > "$MOCKBIN/gh" <<'EOF'
#!/usr/bin/env bash
echo "$@" >> "$MOCK_LOG"
case "$1 ${2:-}" in
  "repo view") echo "acme/widgets"; exit 0 ;;
  "api graphql") cat "$MOCK_FIX/threads.json"; exit 0 ;;
  "pr view")
    case "$*" in
      *comments,reviews*) cat "$MOCK_FIX/comments.json" ;;
      *"--jq .number"*)   echo "5" ;;
    esac
    exit 0 ;;
esac
exit 0
EOF
chmod +x "$MOCKBIN/gh"
out="$(PATH="$MOCKBIN:$PATH" MOCK_LOG="$MOCK_LOG" MOCK_FIX="$FIX/pr-open" "$DIR/mr-fetch.sh" discussions --iid 5 2>/dev/null)"; rc=$?
assert "mr-fetch-discussions-live" "exit code 0" "$rc" "0"
# The query argument carries embedded newlines, so flatten the log before grepping.
assert "mr-fetch-discussions-live" "runs the reviewThreads GraphQL query with --paginate" "$(tr '\n' ' ' < "$MOCK_LOG" | grep -c -- '--paginate.*reviewThreads')" "1"
assert "mr-fetch-discussions-live" "merges GraphQL threads + pr view synthetics" "$(printf '%s' "$out" | jq 'length')" "4"
rm -rf "$MOCKBIN"

"$DIR/mr-fetch.sh" >/dev/null 2>&1; rc=$?
assert "mr-fetch-bad-usage" "exit code 2 (no subcommand)" "$rc" "2"
"$DIR/mr-fetch.sh" notathing >/dev/null 2>&1; rc=$?
assert "mr-fetch-bad-subcommand" "exit code 2 (unknown subcommand)" "$rc" "2"
out="$("$DIR/mr-fetch.sh" info --iid 42 --from-fixture "$FIX/pr-open" 2>/dev/null)"; rc=$?
assert "mr-fetch-iid" "exit code 0 (--iid accepted alongside fixture)" "$rc" "0"
out="$("$DIR/mr-fetch.sh" info --branch f-foo --from-fixture "$FIX/pr-open" 2>/dev/null)"; rc=$?
assert "mr-fetch-branch" "exit code 0 (--branch accepted alongside fixture)" "$rc" "0"
"$DIR/mr-fetch.sh" info --iid 1 --branch f-foo --from-fixture "$FIX/pr-open" >/dev/null 2>&1; rc=$?
assert "mr-fetch-iid-and-branch" "exit code 2 (--iid + --branch mutually exclusive)" "$rc" "2"
"$DIR/mr-fetch.sh" info --iid --from-fixture "$FIX/pr-open" >/dev/null 2>&1; rc=$?
assert "mr-fetch-iid-no-arg" "exit code 2 (bare --iid rejected)" "$rc" "2"

# --------------------------------------------------------------------------------
# post-mr-comment.sh: idempotent line-anchored review comment
# --------------------------------------------------------------------------------
echo
echo "== post-mr-comment.sh =="
# Deterministic key from (agent, spec-path, section, finding-type): IDENTICAL
# inputs hash to the same sha8 as on gitlab (the marker is backend-invariant):
#   printf '%s\0%s\0%s\0%s' product-review docs/development/specs/x/product-spec.md 1-4 metric-overflow | sha1sum | cut -c1-8
NEWSHA="fdbe77ad"
SPECF="docs/development/specs/x/product-spec.md"

# Added line (12) -> new_line only.
out="$(printf 'x\n' | "$DIR/post-mr-comment.sh" product-review "$SPECF" 12 "§1.4" metric-overflow - --from-fixture "$FIX/post-create" 2>/dev/null)"; rc=$?
assert "post-create-added" "exit code 0" "$rc" "0"
assert "post-create-added" "CREATE + anchors added line with new_line only" "$out" "CREATE sha8=$NEWSHA ANCHOR new_line=12"

# Context line inside the hunk (10) -> both old/new from the hunk walk.
out="$(printf 'x\n' | "$DIR/post-mr-comment.sh" product-review "$SPECF" 10 "§1.4" metric-overflow - --from-fixture "$FIX/post-create" 2>/dev/null)"
assert "post-create-context" "CREATE + anchors hunk context line" "$out" "CREATE sha8=$NEWSHA ANCHOR new_line=10 old_line=10"

# HUNKS-ONLY narrowing (the GitHub difference): line 47 is outside every hunk.
# GitLab would anchor it (old_line=45); GitHub review comments cannot -> GENERAL.
out="$(printf 'x\n' | "$DIR/post-mr-comment.sh" product-review "$SPECF" 47 "§1.4" metric-overflow - --from-fixture "$FIX/post-create" 2>/dev/null)"
assert "post-create-outside-hunk" "line outside all hunks -> GENERAL (hunks-only)" "$out" "CREATE sha8=$NEWSHA GENERAL"

# File not in the PR diff -> general-comment fallback.
out="$(printf 'x\n' | "$DIR/post-mr-comment.sh" product-review docs/development/specs/x/other.md 5 "§2" foo - --from-fixture "$FIX/post-create" 2>/dev/null)"
GSHA="$(printf '%s\0%s\0%s\0%s' product-review docs/development/specs/x/other.md 2 foo | sha1sum | cut -c1-8)"
assert "post-create-general" "file absent from diff -> GENERAL fallback" "$out" "CREATE sha8=$GSHA GENERAL"

# File present but without a patch (binary/huge) -> still GENERAL (not a bogus anchor).
out="$(printf 'x\n' | "$DIR/post-mr-comment.sh" product-review docs/development/specs/x/binary.md 5 "§9" bar - --from-fixture "$FIX/post-create" 2>/dev/null)"
EBSHA="$(printf '%s\0%s\0%s\0%s' product-review docs/development/specs/x/binary.md 9 bar | sha1sum | cut -c1-8)"
assert "post-create-emptydiff" "file with no patch -> GENERAL fallback" "$out" "CREATE sha8=$EBSHA GENERAL"

# Path tolerance: absolute spec-path anchors via repo-relative suffix match.
ABS="/Users/x/checkout/$SPECF"
out="$(printf 'x\n' | "$DIR/post-mr-comment.sh" product-review "$ABS" 12 "§1.4" metric-overflow - --from-fixture "$FIX/post-create" 2>/dev/null)"
ABSSHA="$(printf '%s\0%s\0%s\0%s' product-review "$ABS" 1-4 metric-overflow | sha1sum | cut -c1-8)"
assert "post-create-abspath" "absolute spec-path anchors via suffix match" "$out" "CREATE sha8=$ABSSHA ANCHOR new_line=12"
# A genuinely different file (different basename) must NOT false-match -> GENERAL.
out="$(printf 'x\n' | "$DIR/post-mr-comment.sh" product-review /tmp/some-other-spec-copy.md 12 "§1.4" metric-overflow - --from-fixture "$FIX/post-create" 2>/dev/null)"
OSHA="$(printf '%s\0%s\0%s\0%s' product-review /tmp/some-other-spec-copy.md 1-4 metric-overflow | sha1sum | cut -c1-8)"
assert "post-create-nopath" "unrelated path does not false-match -> GENERAL" "$out" "CREATE sha8=$OSHA GENERAL"

# EDIT: post-edit fixture carries the NEWSHA marker in a review thread -> edits in place.
out="$(printf 'x\n' | "$DIR/post-mr-comment.sh" product-review "$SPECF" 47 "§1.4" metric-overflow - --from-fixture "$FIX/post-edit" 2>/dev/null)"; rc=$?
assert "post-edit" "exit code 0" "$rc" "0"
assert "post-edit" "decides EDIT against the matching review-thread note" "$out" "EDIT sha8=$NEWSHA discussion=PRRT_d9 note=PRRC_900"

# EDIT against a marker in a top-level issue comment (synthetic thread).
out="$(printf 'x\n' | "$DIR/post-mr-comment.sh" product-review "$SPECF" 47 "§1.4" metric-overflow - --from-fixture "$FIX/post-edit-comment" 2>/dev/null)"; rc=$?
assert "post-edit-comment" "exit code 0" "$rc" "0"
assert "post-edit-comment" "decides EDIT against the matching issue comment" "$out" "EDIT sha8=$NEWSHA discussion=IC_900 note=IC_900"

# Deterministic-key stability: same section+type, different wording/casing/spacing -> same sha8.
out2="$(printf 'x\n' | "$DIR/post-mr-comment.sh" product-review "$SPECF" 99 " 1.4 " "Metric Overflow" - --from-fixture "$FIX/post-create" 2>/dev/null)"
assert "post-key-stable" "wording/casing variants hash to the same sha8" "$(printf '%s' "$out2" | sed -E 's/.*sha8=([0-9a-f]+).*/\1/')" "$NEWSHA"

printf '   \n' | "$DIR/post-mr-comment.sh" product-review "$SPECF" 1 "§1" k - --from-fixture "$FIX/post-create" >/dev/null 2>&1; rc=$?
assert "post-empty-body" "exit code 1 (empty body)" "$rc" "1"
"$DIR/post-mr-comment.sh" only three args >/dev/null 2>&1; rc=$?
assert "post-bad-usage" "exit code 2 (too few args)" "$rc" "2"

# Live CREATE (mocked gh): the anchored comment must be a REST POST to
# pulls/{n}/comments carrying {body, commit_id: head_sha, path, line, side:"RIGHT"}.
MOCKBIN="$(mktemp -d)"; MOCK_LOG="$MOCKBIN/calls.log"; MOCK_PAYLOAD="$MOCKBIN/payload.json"
cat > "$MOCKBIN/gh" <<'EOF'
#!/usr/bin/env bash
echo "$@" >> "$MOCK_LOG"
case "$1 ${2:-}" in
  "repo view") echo "acme/widgets"; exit 0 ;;
  "api graphql")
    if [[ -f "$MOCK_FIX/threads.json" ]]; then cat "$MOCK_FIX/threads.json"; fi
    exit 0 ;;
  "pr view")
    case "$*" in
      *comments,reviews*)
        if [[ -f "$MOCK_FIX/comments.json" ]]; then cat "$MOCK_FIX/comments.json"; else echo '{"comments":[],"reviews":[]}'; fi ;;
      *"--jq .number"*)   echo "5" ;;
      *number,url*)       cat "$MOCK_FIX/info.json" ;;
    esac
    exit 0 ;;
  "pr comment") cat > "$MOCK_COMMENT_BODY"; exit 0 ;;
  "api "*)
    if printf '%s\n' "$@" | grep -qx -- '--input'; then
      prev=""; infile=""
      for a in "$@"; do [[ "$prev" == "--input" ]] && infile="$a"; prev="$a"; done
      cat "$infile" >> "$MOCK_PAYLOAD"
      if [[ -n "${MOCK_DROP_LINE:-}" ]]; then
        echo '{"id":55,"line":null}'
      else
        jq '{id:55, line:.line}' "$infile"
      fi
      exit 0
    fi
    cat "$MOCK_FIX/files.json"
    exit 0 ;;
esac
exit 0
EOF
chmod +x "$MOCKBIN/gh"
# Line 12 is an added line inside the hunk -> anchored REST POST.
out="$(printf 'finding body\n' | PATH="$MOCKBIN:$PATH" SOURCE_BRANCH=fake MOCK_LOG="$MOCK_LOG" \
        MOCK_PAYLOAD="$MOCK_PAYLOAD" MOCK_COMMENT_BODY="$MOCKBIN/comment.txt" MOCK_FIX="$FIX/post-create" \
        "$DIR/post-mr-comment.sh" product-review "$SPECF" 12 "§1.4" metric-overflow - 2>/dev/null)"; rc=$?
assert "post-live-anchor" "exit 0 when GitHub returns a positioned comment" "$rc" "0"
assert "post-live-anchor" "POST targets pulls/5/comments" "$(grep -c 'repos/acme/widgets/pulls/5/comments' "$MOCK_LOG")" "1"
assert "post-live-anchor" "payload carries side:RIGHT" "$(jq -r '.side' "$MOCK_PAYLOAD" 2>/dev/null)" "RIGHT"
assert "post-live-anchor" "payload carries the target line" "$(jq -r '.line' "$MOCK_PAYLOAD" 2>/dev/null)" "12"
assert "post-live-anchor" "payload anchors to the head commit" "$(jq -r '.commit_id' "$MOCK_PAYLOAD" 2>/dev/null)" "head111"
assert "post-live-anchor" "payload carries the repo-relative path" "$(jq -r '.path' "$MOCK_PAYLOAD" 2>/dev/null)" "$SPECF"
assert "post-live-anchor" "payload body carries the idempotency marker" "$(jq -r '.body' "$MOCK_PAYLOAD" 2>/dev/null | grep -c "specto:product-review#$NEWSHA")" "1"
assert "post-live-anchor" "no GitLab-style position object in the payload" "$(jq 'has("position")' "$MOCK_PAYLOAD" 2>/dev/null)" "false"
# GitHub returning a comment without a line -> loud exit 3, not silent success.
: > "$MOCK_PAYLOAD"
printf 'b\n' | PATH="$MOCKBIN:$PATH" SOURCE_BRANCH=fake MOCK_LOG="$MOCK_LOG" \
  MOCK_PAYLOAD="$MOCK_PAYLOAD" MOCK_COMMENT_BODY="$MOCKBIN/comment.txt" MOCK_FIX="$FIX/post-create" MOCK_DROP_LINE=1 \
  "$DIR/post-mr-comment.sh" product-review "$SPECF" 12 "§1.4" metric-overflow - >/dev/null 2>&1; rc=$?
assert "post-live-dropped" "exit 3 when GitHub drops the anchor (comment has no line)" "$rc" "3"
# Line outside every hunk -> live GENERAL fallback via gh pr comment (no REST POST).
: > "$MOCK_LOG"; : > "$MOCK_PAYLOAD"
printf 'general body\n' | PATH="$MOCKBIN:$PATH" SOURCE_BRANCH=fake MOCK_LOG="$MOCK_LOG" \
  MOCK_PAYLOAD="$MOCK_PAYLOAD" MOCK_COMMENT_BODY="$MOCKBIN/comment.txt" MOCK_FIX="$FIX/post-create" \
  "$DIR/post-mr-comment.sh" product-review "$SPECF" 47 "§1.4" metric-overflow - >/dev/null 2>&1; rc=$?
assert "post-live-general" "exit code 0" "$rc" "0"
assert "post-live-general" "falls back to gh pr comment" "$(grep -c '^pr comment' "$MOCK_LOG")" "1"
assert "post-live-general" "no anchored POST issued" "$(grep -c 'pulls/5/comments' "$MOCK_LOG")" "0"
assert "post-live-general" "general body still carries the marker" "$(grep -c "specto:product-review#$NEWSHA" "$MOCKBIN/comment.txt")" "1"
# Live EDIT on a review-thread note -> GraphQL updatePullRequestReviewComment.
: > "$MOCK_LOG"
printf 'reworded\n' | PATH="$MOCKBIN:$PATH" SOURCE_BRANCH=fake MOCK_LOG="$MOCK_LOG" \
  MOCK_PAYLOAD="$MOCK_PAYLOAD" MOCK_COMMENT_BODY="$MOCKBIN/comment.txt" MOCK_FIX="$FIX/post-edit" \
  "$DIR/post-mr-comment.sh" product-review "$SPECF" 47 "§1.4" metric-overflow - >/dev/null 2>&1; rc=$?
assert "post-live-edit" "exit code 0" "$rc" "0"
assert "post-live-edit" "edits via updatePullRequestReviewComment" "$(grep -c 'updatePullRequestReviewComment' "$MOCK_LOG")" "1"
assert "post-live-edit" "no new comment POSTed" "$(grep -c 'pulls/5/comments' "$MOCK_LOG")" "0"
# Live EDIT on an issue comment -> GraphQL updateIssueComment.
: > "$MOCK_LOG"
printf 'reworded\n' | PATH="$MOCKBIN:$PATH" SOURCE_BRANCH=fake MOCK_LOG="$MOCK_LOG" \
  MOCK_PAYLOAD="$MOCK_PAYLOAD" MOCK_COMMENT_BODY="$MOCKBIN/comment.txt" MOCK_FIX="$FIX/post-edit-comment" \
  "$DIR/post-mr-comment.sh" product-review "$SPECF" 47 "§1.4" metric-overflow - >/dev/null 2>&1; rc=$?
assert "post-live-edit-comment" "exit code 0" "$rc" "0"
assert "post-live-edit-comment" "edits via updateIssueComment" "$(grep -c 'updateIssueComment' "$MOCK_LOG")" "1"
rm -rf "$MOCKBIN"

# --------------------------------------------------------------------------------
# create-mr.sh: idempotent create-vs-update
# --------------------------------------------------------------------------------
echo
echo "== create-mr.sh =="
out="$(printf 'Summary line.\n' | "$DIR/create-mr.sh" "[APP-1] Title" - --from-fixture "$FIX/create-new" 2>/dev/null)"; rc=$?
assert "create-mr-create" "exit code 0" "$rc" "0"
assert "create-mr-create" "decides CREATE when no PR exists" "$out" "CREATE"
out="$(printf 'Summary line.\n' | "$DIR/create-mr.sh" "[APP-1] Title" - --reviewer alice --reviewer bob --from-fixture "$FIX/create-existing" 2>/dev/null)"; rc=$?
assert "create-mr-update" "exit code 0" "$rc" "0"
assert "create-mr-update" "decides UPDATE when a PR exists (iid= even on GitHub)" "$out" "UPDATE iid=42"
out="$(printf 'Summary line.\n' | "$DIR/create-mr.sh" "[APP-1] Title" - --assignee alice --assignee bob --from-fixture "$FIX/create-new" 2>/dev/null)"; rc=$?
assert "create-mr-assignees" "exit code 0 (--assignee accepted, repeatable)" "$rc" "0"
assert "create-mr-assignees" "still decides CREATE with assignees set" "$out" "CREATE"
printf '  \n' | "$DIR/create-mr.sh" "T" - --from-fixture "$FIX/create-new" >/dev/null 2>&1; rc=$?
assert "create-mr-empty-desc" "exit code 1 (empty description)" "$rc" "1"
"$DIR/create-mr.sh" "only title" >/dev/null 2>&1; rc=$?
assert "create-mr-bad-usage" "exit code 2 (too few args)" "$rc" "2"

# Live create (mocked gh): no PR yet -> gh pr create with --draft, --head, and
# the @me default assignee; prints the PR URL.
MOCKBIN="$(mktemp -d)"; MOCK_LOG="$MOCKBIN/calls.log"
cat > "$MOCKBIN/gh" <<'EOF'
#!/usr/bin/env bash
echo "$@" >> "$MOCK_LOG"
case "$1 ${2:-}" in
  "pr view")
    # First view (existence probe) fails; after a create/edit it returns the URL.
    if grep -qE '^pr (create|edit)' "$MOCK_LOG"; then
      echo "https://github.com/acme/widgets/pull/9"; exit 0
    fi
    exit 1 ;;
  "pr create"|"pr edit") cat >/dev/null; exit 0 ;;
esac
exit 0
EOF
chmod +x "$MOCKBIN/gh"
out="$(printf 'Summary line.\n' | PATH="$MOCKBIN:$PATH" MOCK_LOG="$MOCK_LOG" SOURCE_BRANCH=f-test "$DIR/create-mr.sh" "[APP-1] Title" - 2>/dev/null)"; rc=$?
assert "create-mr-live-create" "exit code 0" "$rc" "0"
assert "create-mr-live-create" "create carries --draft" "$(grep -c '^pr create --draft ' "$MOCK_LOG")" "1"
assert "create-mr-live-create" "create carries --head <branch>" "$(grep -c -- '--head f-test' "$MOCK_LOG")" "1"
assert "create-mr-live-create" "create carries --assignee @me by default" "$(grep -c -- '--assignee @me' "$MOCK_LOG")" "1"
assert "create-mr-live-create" "prints the PR web URL" "$out" "https://github.com/acme/widgets/pull/9"
rm -rf "$MOCKBIN"
# Explicit --assignee replaces the @me default; update path goes through gh pr edit.
MOCKBIN="$(mktemp -d)"; MOCK_LOG="$MOCKBIN/calls.log"
cat > "$MOCKBIN/gh" <<'EOF'
#!/usr/bin/env bash
echo "$@" >> "$MOCK_LOG"
case "$1 ${2:-}" in
  "pr view") echo "https://github.com/acme/widgets/pull/9"; exit 0 ;;   # PR exists
  "pr edit") cat >/dev/null; exit 0 ;;
esac
exit 0
EOF
chmod +x "$MOCKBIN/gh"
out="$(printf 'Summary line.\n' | PATH="$MOCKBIN:$PATH" MOCK_LOG="$MOCK_LOG" SOURCE_BRANCH=f-test "$DIR/create-mr.sh" "[APP-1] Title" - --assignee alice 2>/dev/null)"; rc=$?
assert "create-mr-live-update" "exit code 0" "$rc" "0"
assert "create-mr-live-update" "existing PR -> gh pr edit (idempotent, no create)" "$(grep -c '^pr edit' "$MOCK_LOG")" "1"
assert "create-mr-live-update" "no pr create issued" "$(grep -c '^pr create' "$MOCK_LOG")" "0"
assert "create-mr-live-update" "explicit assignee carried (--add-assignee alice)" "$(grep -c -- '--add-assignee alice' "$MOCK_LOG")" "1"
assert "create-mr-live-update" "@me default NOT added when explicit assignee passed" "$(grep -c -- '--add-assignee @me' "$MOCK_LOG")" "0"
rm -rf "$MOCKBIN"

# --------------------------------------------------------------------------------
# mr-reply.sh: reply to (and optionally resolve) a PR discussion thread
# --------------------------------------------------------------------------------
echo
echo "== mr-reply.sh =="
out="$(printf 'fixed in 1a2b3c\n' | "$DIR/mr-reply.sh" abc123 - --from-fixture "$FIX/mr-reply" 2>/dev/null)"; rc=$?
assert "mr-reply-default" "exit code 0" "$rc" "0"
assert "mr-reply-default" "default decision is REPLY_RESOLVE" "$out" "REPLY_RESOLVE discussion=abc123"
out="$(printf 'deferring: see APP-9999\n' | "$DIR/mr-reply.sh" abc123 - --no-resolve --from-fixture "$FIX/mr-reply" 2>/dev/null)"; rc=$?
assert "mr-reply-no-resolve" "exit code 0" "$rc" "0"
assert "mr-reply-no-resolve" "--no-resolve decision is REPLY only" "$out" "REPLY discussion=abc123"
printf '   \n' | "$DIR/mr-reply.sh" abc123 - --from-fixture "$FIX/mr-reply" >/dev/null 2>&1; rc=$?
assert "mr-reply-empty-body" "exit code 1 (empty body)" "$rc" "1"
"$DIR/mr-reply.sh" only-one-arg >/dev/null 2>&1; rc=$?
assert "mr-reply-bad-usage" "exit code 2 (too few args)" "$rc" "2"
out="$(printf 'fixed\n' | "$DIR/mr-reply.sh" --discussion d99 - --from-fixture "$FIX/mr-reply" 2>/dev/null)"; rc=$?
assert "mr-reply-discussion-flag" "exit code 0" "$rc" "0"
assert "mr-reply-discussion-flag" "decision is REPLY_RESOLVE" "$out" "REPLY_RESOLVE discussion=d99"
out="$(printf 'deferred\n' | "$DIR/mr-reply.sh" --discussion d99 - --no-resolve --from-fixture "$FIX/mr-reply" 2>/dev/null)"
assert "mr-reply-discussion-no-resolve" "decision is REPLY only" "$out" "REPLY discussion=d99"
printf 'x\n' | "$DIR/mr-reply.sh" --discussion d1 - --bogus --from-fixture "$FIX/mr-reply" >/dev/null 2>&1; rc=$?
assert "mr-reply-unknown-flag" "exit code 2 (unknown flag rejected)" "$rc" "2"
out="$(printf 'x\n' | "$DIR/mr-reply.sh" abc123 - --iid 42 --from-fixture "$FIX/mr-reply" 2>/dev/null)"; rc=$?
assert "mr-reply-iid" "exit code 0 (--iid accepted, legacy form)" "$rc" "0"
out="$(printf 'x\n' | "$DIR/mr-reply.sh" abc123 - --branch f-foo --from-fixture "$FIX/mr-reply" 2>/dev/null)"; rc=$?
assert "mr-reply-branch" "exit code 0 (--branch accepted, legacy form)" "$rc" "0"
out="$(printf 'x\n' | "$DIR/mr-reply.sh" --discussion d99 - --iid 42 --from-fixture "$FIX/mr-reply" 2>/dev/null)"; rc=$?
assert "mr-reply-discussion-iid" "exit code 0 (--iid accepted, --discussion form)" "$rc" "0"
printf 'x\n' | "$DIR/mr-reply.sh" abc123 - --iid 1 --branch f-foo --from-fixture "$FIX/mr-reply" >/dev/null 2>&1; rc=$?
assert "mr-reply-iid-and-branch" "exit code 2 (--iid + --branch mutually exclusive)" "$rc" "2"
printf 'x\n' | "$DIR/mr-reply.sh" abc123 - --iid --from-fixture "$FIX/mr-reply" >/dev/null 2>&1; rc=$?
assert "mr-reply-iid-no-arg" "exit code 2 (bare --iid rejected)" "$rc" "2"
out="$("$DIR/mr-reply.sh" --discussion d99 --resolve-only --from-fixture "$FIX/mr-reply" 2>/dev/null)"; rc=$?
assert "mr-reply-resolve-only" "exit code 0" "$rc" "0"
assert "mr-reply-resolve-only" "decision is RESOLVE (no reply)" "$out" "RESOLVE discussion=d99"
"$DIR/mr-reply.sh" --discussion d99 - --resolve-only --from-fixture "$FIX/mr-reply" </dev/null >/dev/null 2>&1; rc=$?
assert "mr-reply-resolve-only-body" "exit code 2 (--resolve-only takes no body)" "$rc" "2"
"$DIR/mr-reply.sh" --discussion d99 --resolve-only --no-resolve --from-fixture "$FIX/mr-reply" >/dev/null 2>&1; rc=$?
assert "mr-reply-resolve-only-conflict" "exit code 2 (--resolve-only + --no-resolve contradict)" "$rc" "2"

# Live paths (mocked gh). The mock serves the post-edit thread fixture, so
# PRRT_d9 is a review thread and IC_900 (post-edit-comment) an issue comment.
MOCKBIN="$(mktemp -d)"; MOCK_LOG="$MOCKBIN/calls.log"
cat > "$MOCKBIN/gh" <<'EOF'
#!/usr/bin/env bash
echo "$@" >> "$MOCK_LOG"
case "$1 ${2:-}" in
  "repo view") echo "acme/widgets"; exit 0 ;;
  "api graphql")
    if printf '%s\n' "$*" | grep -q reviewThreads; then
      if [[ -f "$MOCK_FIX/threads.json" ]]; then cat "$MOCK_FIX/threads.json"; fi
    fi
    exit 0 ;;
  "pr view")
    case "$*" in
      *comments,reviews*)
        if [[ -f "$MOCK_FIX/comments.json" ]]; then cat "$MOCK_FIX/comments.json"; else echo '{"comments":[],"reviews":[]}'; fi ;;
      *"--jq .number"*) echo "5" ;;
    esac
    exit 0 ;;
  "pr comment") cat > "$MOCK_COMMENT_BODY"; exit 0 ;;
esac
exit 0
EOF
chmod +x "$MOCKBIN/gh"
# Default mode on a review thread: threaded reply + resolve mutations.
printf 'fixed\n' | PATH="$MOCKBIN:$PATH" MOCK_LOG="$MOCK_LOG" MOCK_COMMENT_BODY="$MOCKBIN/comment.txt" MOCK_FIX="$FIX/post-edit" \
  "$DIR/mr-reply.sh" --discussion PRRT_d9 - --iid 5 >/dev/null 2>&1; rc=$?
assert "mr-reply-live" "exit code 0" "$rc" "0"
assert "mr-reply-live" "reply via addPullRequestReviewThreadReply" "$(grep -c 'addPullRequestReviewThreadReply' "$MOCK_LOG")" "1"
assert "mr-reply-live" "resolve via resolveReviewThread" "$(grep -c 'resolveReviewThread' "$MOCK_LOG")" "1"
# --no-resolve: reply only.
: > "$MOCK_LOG"
printf 'deferred\n' | PATH="$MOCKBIN:$PATH" MOCK_LOG="$MOCK_LOG" MOCK_COMMENT_BODY="$MOCKBIN/comment.txt" MOCK_FIX="$FIX/post-edit" \
  "$DIR/mr-reply.sh" --discussion PRRT_d9 - --no-resolve --iid 5 >/dev/null 2>&1; rc=$?
assert "mr-reply-live-no-resolve" "exit code 0" "$rc" "0"
assert "mr-reply-live-no-resolve" "reply mutation issued" "$(grep -c 'addPullRequestReviewThreadReply' "$MOCK_LOG")" "1"
assert "mr-reply-live-no-resolve" "no resolve mutation" "$(grep -c 'resolveReviewThread' "$MOCK_LOG")" "0"
# --resolve-only: exactly one resolve mutation, no reply.
: > "$MOCK_LOG"
PATH="$MOCKBIN:$PATH" MOCK_LOG="$MOCK_LOG" MOCK_COMMENT_BODY="$MOCKBIN/comment.txt" MOCK_FIX="$FIX/post-edit" \
  "$DIR/mr-reply.sh" --discussion PRRT_d9 --resolve-only --iid 5 >/dev/null 2>&1; rc=$?
assert "mr-reply-live-resolve-only" "exit code 0" "$rc" "0"
assert "mr-reply-live-resolve-only" "no reply mutation" "$(grep -c 'addPullRequestReviewThreadReply' "$MOCK_LOG")" "0"
assert "mr-reply-live-resolve-only" "exactly one resolve mutation" "$(grep -c 'resolveReviewThread' "$MOCK_LOG")" "1"
# Synthetic issue-comment thread: reply = quote-reply top-level comment.
: > "$MOCK_LOG"
printf 'noted, tracked in APP-9\n' | PATH="$MOCKBIN:$PATH" MOCK_LOG="$MOCK_LOG" MOCK_COMMENT_BODY="$MOCKBIN/comment.txt" MOCK_FIX="$FIX/post-edit-comment" \
  "$DIR/mr-reply.sh" --discussion IC_900 - --no-resolve --iid 5 >/dev/null 2>&1; rc=$?
assert "mr-reply-live-quote" "exit code 0" "$rc" "0"
assert "mr-reply-live-quote" "issue-comment thread replied via gh pr comment" "$(grep -c '^pr comment' "$MOCK_LOG")" "1"
assert "mr-reply-live-quote" "no review-thread reply mutation" "$(grep -c 'addPullRequestReviewThreadReply' "$MOCK_LOG")" "0"
assert "mr-reply-live-quote" "quote-reply body quotes the original" "$(head -1 "$MOCKBIN/comment.txt" | grep -c '^> ')" "1"
rm -rf "$MOCKBIN"

# --------------------------------------------------------------------------------
# mr-ready.sh
# --------------------------------------------------------------------------------
echo
echo "== mr-ready.sh =="
"$DIR/mr-ready.sh" --from-fixture "$FIX/pr-open" >/dev/null 2>&1; rc=$?
assert "mr-ready" "exit code 0 (no-op success in fixture mode)" "$rc" "0"
"$DIR/mr-ready.sh" extra args here >/dev/null 2>&1; rc=$?
assert "mr-ready-bad-usage" "exit code 2 (unexpected args)" "$rc" "2"
MOCKBIN="$(mktemp -d)"; MOCK_LOG="$MOCKBIN/calls.log"
cat > "$MOCKBIN/gh" <<'EOF'
#!/usr/bin/env bash
echo "$@" >> "$MOCK_LOG"
exit 0
EOF
chmod +x "$MOCKBIN/gh"
PATH="$MOCKBIN:$PATH" MOCK_LOG="$MOCK_LOG" SOURCE_BRANCH=f-test "$DIR/mr-ready.sh" >/dev/null 2>&1; rc=$?
assert "mr-ready-live" "exit code 0" "$rc" "0"
assert "mr-ready-live" "runs gh pr ready on the resolved branch" "$(grep -c '^pr ready f-test' "$MOCK_LOG")" "1"
rm -rf "$MOCKBIN"

# --------------------------------------------------------------------------------
# mr-describe.sh: idempotent marker-delimited description section
# --------------------------------------------------------------------------------
echo
echo "== mr-describe.sh =="
BODY=$'## Change walkthrough\n\n```mermaid\nflowchart TD\n  A-->B\n```'
out="$(printf '%s' "$BODY" | "$DIR/mr-describe.sh" - --from-fixture "$FIX/mr-desc-fresh" 2>/dev/null)"; rc=$?
assert "mr-describe-fresh" "exit code 0" "$rc" "0"
assert "mr-describe-fresh" "prior description text preserved" "$(printf '%s\n' "$out" | grep -c 'Existing PR summary.')" "1"
assert "mr-describe-fresh" "exactly one start marker added" "$(printf '%s\n' "$out" | grep -cF '<!-- specto:walkthrough:start -->')" "1"
assert "mr-describe-fresh" "exactly one end marker added" "$(printf '%s\n' "$out" | grep -cF '<!-- specto:walkthrough:end -->')" "1"
assert "mr-describe-fresh" "new body landed inside the block" "$(printf '%s\n' "$out" | grep -c 'flowchart TD')" "1"
out="$(printf '%s' "$BODY" | "$DIR/mr-describe.sh" - --from-fixture "$FIX/mr-desc-existing" 2>/dev/null)"; rc=$?
assert "mr-describe-existing" "exit code 0" "$rc" "0"
assert "mr-describe-existing" "still exactly one start marker (no duplicate)" "$(printf '%s\n' "$out" | grep -cF '<!-- specto:walkthrough:start -->')" "1"
assert "mr-describe-existing" "old block content dropped" "$(printf '%s\n' "$out" | grep -c 'OLD diagram')" "0"
assert "mr-describe-existing" "new body present" "$(printf '%s\n' "$out" | grep -c 'flowchart TD')" "1"
assert "mr-describe-existing" "prior description text preserved" "$(printf '%s\n' "$out" | grep -c 'Existing PR summary.')" "1"
printf '   \n' | "$DIR/mr-describe.sh" - --from-fixture "$FIX/mr-desc-fresh" >/dev/null 2>&1; rc=$?
assert "mr-describe-empty-body" "exit code 1 (empty body)" "$rc" "1"
"$DIR/mr-describe.sh" >/dev/null 2>&1; rc=$?
assert "mr-describe-bad-usage" "exit code 2 (no body arg)" "$rc" "2"
printf 'x\n' | "$DIR/mr-describe.sh" - --iid 1 --branch f-foo --from-fixture "$FIX/mr-desc-fresh" >/dev/null 2>&1; rc=$?
assert "mr-describe-iid-and-branch" "exit code 2 (--iid + --branch mutually exclusive)" "$rc" "2"
# Live path (mocked gh): description updated via gh pr edit --body-file -.
MOCKBIN="$(mktemp -d)"; MOCK_LOG="$MOCKBIN/calls.log"
cat > "$MOCKBIN/gh" <<'EOF'
#!/usr/bin/env bash
echo "$@" >> "$MOCK_LOG"
case "$1 ${2:-}" in
  "pr view") cat "$MOCK_FIX/info.json"; exit 0 ;;
  "pr edit") cat > "$MOCK_EDIT_BODY"; exit 0 ;;
esac
exit 0
EOF
chmod +x "$MOCKBIN/gh"
out="$(printf '%s' "$BODY" | PATH="$MOCKBIN:$PATH" MOCK_LOG="$MOCK_LOG" MOCK_FIX="$FIX/pr-open" MOCK_EDIT_BODY="$MOCKBIN/edit.txt" \
        "$DIR/mr-describe.sh" - --iid 7 2>/dev/null)"; rc=$?
assert "mr-describe-live" "exit code 0" "$rc" "0"
assert "mr-describe-live" "updates via gh pr edit --body-file -" "$(grep -c -- '--body-file -' "$MOCK_LOG")" "1"
assert "mr-describe-live" "spliced body sent (prior text + block)" "$(grep -c 'Existing PR summary.' "$MOCKBIN/edit.txt")" "1"
assert "mr-describe-live" "prints the PR web URL" "$out" "https://github.com/acme/widgets/pull/7"
rm -rf "$MOCKBIN"

# --------------------------------------------------------------------------------
# pipeline-status.sh: gh pr checks buckets -> running|success|failed|none
# --------------------------------------------------------------------------------
echo
echo "== pipeline-status.sh =="
out="$("$DIR/pipeline-status.sh" --from-fixture "$FIX/checks-running" 2>/dev/null)"; rc=$?
assert "pipeline-running" "exit code 0" "$rc" "0"
assert "pipeline-running" "a pending bucket -> running" "$out" "running"
out="$("$DIR/pipeline-status.sh" --from-fixture "$FIX/checks-success" 2>/dev/null)"
assert "pipeline-success" "all pass (skips ignored) -> success" "$out" "success"
out="$("$DIR/pipeline-status.sh" --from-fixture "$FIX/checks-none" 2>/dev/null)"
assert "pipeline-none" "empty checks array -> none" "$out" "none"
out="$("$DIR/pipeline-status.sh" --from-fixture "$FIX/checks-failed" 2>/dev/null)"
assert "pipeline-failed-line1" "first stdout line is 'failed'" "$(printf '%s\n' "$out" | sed -n '1p')" "failed"
assert "pipeline-failed-sep"   "second line is the '---' separator" "$(printf '%s\n' "$out" | sed -n '2p')" "---"
assert "pipeline-failed-jobs"  "Actions job ids parsed from the check links" "$(printf '%s\n' "$out" | sed -n '3,$p' | tr '\n' ',')" "9002,9003,"
err="$("$DIR/pipeline-status.sh" --from-fixture "$FIX/checks-failed" 2>&1 >/dev/null)"
assert "pipeline-failed-warn" "failed check without a job link warned on stderr" "$(printf '%s\n' "$err" | grep -c 'sonar')" "1"
"$DIR/pipeline-status.sh" --from-fixture >/dev/null 2>&1; rc=$?
assert "pipeline-bad-usage" "exit code 2 (--from-fixture without a dir)" "$rc" "2"
# --manual-jobs: pending deployment approvals -> <environment>\t<run>\t<url> rows.
out="$("$DIR/pipeline-status.sh" --manual-jobs --from-fixture "$FIX/manual-pending" 2>/dev/null)"; rc=$?
assert "pipeline-manual-jobs" "exit code 0" "$rc" "0"
assert "pipeline-manual-jobs" "two pending environments listed" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" "2"
assert "pipeline-manual-jobs" "first row environment<TAB>run<TAB>url" "$(printf '%s\n' "$out" | sed -n '1p')" "$(printf 'staging\tDeploy\thttps://github.com/acme/widgets/actions/runs/557')"
out="$("$DIR/pipeline-status.sh" --manual-jobs --from-fixture "$FIX/checks-success" 2>/dev/null)"; rc=$?
assert "pipeline-manual-jobs-none" "exit code 0 with no waiting runs" "$rc" "0"
assert "pipeline-manual-jobs-none" "empty stdout when no pending approvals" "$out" ""
# Live path (mocked gh): gh pr checks exits non-zero on failures: the JSON must
# still be parsed rather than trusting the exit code.
MOCKBIN="$(mktemp -d)"; MOCK_LOG="$MOCKBIN/calls.log"
cat > "$MOCKBIN/gh" <<'EOF'
#!/usr/bin/env bash
echo "$@" >> "$MOCK_LOG"
case "$1 ${2:-}" in
  "pr checks") cat "$MOCK_FIX/checks.json"; exit 8 ;;
esac
exit 0
EOF
chmod +x "$MOCKBIN/gh"
out="$(PATH="$MOCKBIN:$PATH" MOCK_LOG="$MOCK_LOG" MOCK_FIX="$FIX/checks-failed" SOURCE_BRANCH=f-test "$DIR/pipeline-status.sh" 2>/dev/null)"; rc=$?
assert "pipeline-live" "exit code 0 despite gh pr checks exiting 8" "$rc" "0"
assert "pipeline-live" "status parsed from the JSON" "$(printf '%s\n' "$out" | sed -n '1p')" "failed"
rm -rf "$MOCKBIN"

# --------------------------------------------------------------------------------
# job-trace.sh
# --------------------------------------------------------------------------------
echo
echo "== job-trace.sh =="
out="$("$DIR/job-trace.sh" 9002 --from-fixture "$FIX/job-trace" 2>/dev/null)"; rc=$?
assert "job-trace" "exit code 0" "$rc" "0"
assert "job-trace" "trace tail includes the failing assertion" "$(printf '%s\n' "$out" | grep -c 'AssertionError: 0.7 != 0.85')" "1"
assert "job-trace" "output capped at 200 lines" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" "200"
"$DIR/job-trace.sh" >/dev/null 2>&1; rc=$?
assert "job-trace-bad-usage" "exit code 2 (no job id)" "$rc" "2"
"$DIR/job-trace.sh" 404 --from-fixture "$FIX/job-trace" >/dev/null 2>&1; rc=$?
assert "job-trace-missing" "exit code 3 (no trace file for that job id)" "$rc" "3"
# Live path (mocked gh): gh run view first; the raw-logs API as fallback.
MOCKBIN="$(mktemp -d)"; MOCK_LOG="$MOCKBIN/calls.log"
cat > "$MOCKBIN/gh" <<'EOF'
#!/usr/bin/env bash
echo "$@" >> "$MOCK_LOG"
case "$1 ${2:-}" in
  "run view")  exit 1 ;;                                # not indexed yet
  "repo view") echo "acme/widgets"; exit 0 ;;
  "api "*)     echo "fallback log line"; exit 0 ;;
esac
exit 0
EOF
chmod +x "$MOCKBIN/gh"
out="$(PATH="$MOCKBIN:$PATH" MOCK_LOG="$MOCK_LOG" "$DIR/job-trace.sh" 9002 2>/dev/null)"; rc=$?
assert "job-trace-live-fallback" "exit code 0" "$rc" "0"
assert "job-trace-live-fallback" "tried gh run view --job first" "$(grep -c '^run view --job 9002 --log' "$MOCK_LOG")" "1"
assert "job-trace-live-fallback" "fell back to the raw jobs/<id>/logs endpoint" "$(grep -c 'actions/jobs/9002/logs' "$MOCK_LOG")" "1"
assert "job-trace-live-fallback" "prints the fallback log" "$out" "fallback log line"
rm -rf "$MOCKBIN"

# --------------------------------------------------------------------------------
# create-issue.sh: issue create with re-fetch verification, prints the number
# --------------------------------------------------------------------------------
echo
echo "== create-issue.sh =="
out="$(printf 'Friction body.\n' | "$DIR/create-issue.sh" "specto: some gap" - --from-fixture "$FIX/issue-create" 2>/dev/null)"; rc=$?
assert "create-issue-create" "exit code 0" "$rc" "0"
assert "create-issue-create" "prints the new issue number" "$out" "7"
printf '  \n' | "$DIR/create-issue.sh" "T" - --from-fixture "$FIX/issue-create" >/dev/null 2>&1; rc=$?
assert "create-issue-empty-body" "exit code 1 (empty body)" "$rc" "1"
"$DIR/create-issue.sh" "only title" >/dev/null 2>&1; rc=$?
assert "create-issue-bad-usage" "exit code 2 (too few args)" "$rc" "2"
out="$(printf 'Friction body.\n\nMore detail here.\n' | "$DIR/create-issue.sh" "specto: some gap" - --from-fixture "$FIX/issue-create-verified" 2>/dev/null)"; rc=$?
assert "create-issue-verified" "exit code 0 (verify.json matches)" "$rc" "0"
assert "create-issue-verified" "prints the number" "$out" "8"
err="$(printf 'Friction body.\n\nMore detail here.\n' | "$DIR/create-issue.sh" "specto: some gap" - --from-fixture "$FIX/issue-create-desync" 2>&1 >/dev/null)"; rc=$?
out="$(printf 'Friction body.\n\nMore detail here.\n' | "$DIR/create-issue.sh" "specto: some gap" - --from-fixture "$FIX/issue-create-desync" 2>/dev/null)"
assert "create-issue-desync-fixture" "exit code 1 (stored body differs)" "$rc" "1"
assert "create-issue-desync-fixture" "number still printed (do not re-file)" "$out" "9"
assert "create-issue-desync-fixture" "stderr warns against re-filing" "$(printf '%s\n' "$err" | grep -c 'do NOT re-file')" "1"

# Live-path regressions against a mocked gh: false-failure, desync + self-heal,
# unrepairable, hard failure: the verification pattern ported from gitlab.
MOCKBIN="$(mktemp -d)"; MOCK_LOG="$MOCKBIN/calls.log"; MOCK_STATE="$MOCKBIN/state"
mkdir -p "$MOCK_STATE"
cat > "$MOCKBIN/gh" <<'EOF'
#!/usr/bin/env bash
echo "$@" >> "$MOCK_LOG"
if [[ "$1" == "issue" && "$2" == "create" ]]; then
  cat >/dev/null   # consume --body-file -
  if [[ -n "${MOCK_NO_URL:-}" ]]; then
    echo "error: something went wrong" >&2
  else
    echo "https://github.com/acme/toolkit/issues/9"
  fi
  exit "${MOCK_CREATE_RC:-0}"
fi
if [[ "$1" == "api" ]]; then
  if printf '%s\n' "$@" | grep -qx -- '--method'; then
    cat >/dev/null   # consume the --input - body
    [[ -n "${MOCK_PATCH_FAILS:-}" ]] && exit 1
    touch "$MOCK_STATE/repaired"
    exit 0
  fi
  if [[ -n "${MOCK_WRONG_BODY:-}" && ! -e "$MOCK_STATE/repaired" ]]; then
    echo '{"number":9,"title":"specto: gap","body":"WRONG body from the next call"}'
  else
    echo '{"number":9,"title":"specto: gap","body":"Body."}'
  fi
  exit 0
fi
exit 0
EOF
chmod +x "$MOCKBIN/gh"
# Happy path incl. --repo required plumbing.
: > "$MOCK_LOG"
out="$(printf 'Body.\n' | PATH="$MOCKBIN:$PATH" MOCK_LOG="$MOCK_LOG" MOCK_STATE="$MOCK_STATE" \
        "$DIR/create-issue.sh" "specto: gap" - --repo acme/toolkit 2>/dev/null)"; rc=$?
assert "create-issue-live" "exit code 0" "$rc" "0"
assert "create-issue-live" "prints the number parsed from the URL" "$out" "9"
assert "create-issue-live" "create call targets --repo acme/toolkit" "$(grep -c -- '--repo acme/toolkit' "$MOCK_LOG")" "1"
# Live mode without --repo is a usage error (no hardcodable default on GitHub).
printf 'Body.\n' | PATH="$MOCKBIN:$PATH" MOCK_LOG="$MOCK_LOG" MOCK_STATE="$MOCK_STATE" \
  "$DIR/create-issue.sh" "specto: gap" - >/dev/null 2>&1; rc=$?
assert "create-issue-no-repo" "exit code 2 (live mode requires --repo)" "$rc" "2"
# False-failure: gh exits 1 but printed the created-issue URL -> success + warning.
: > "$MOCK_LOG"
out="$(printf 'Body.\n' | PATH="$MOCKBIN:$PATH" MOCK_LOG="$MOCK_LOG" MOCK_STATE="$MOCK_STATE" MOCK_CREATE_RC=1 \
        "$DIR/create-issue.sh" "specto: gap" - --repo acme/toolkit 2>"$MOCKBIN/err")"; rc=$?
assert "create-issue-false-failure" "exit code 0 (URL trumps the non-zero exit)" "$rc" "0"
assert "create-issue-false-failure" "prints the number" "$out" "9"
assert "create-issue-false-failure" "stderr warns the issue WAS created" "$(grep -c 'WAS created' "$MOCKBIN/err")" "1"
# Desync + self-heal: GET returns another call's body, the repair PATCH lands.
: > "$MOCK_LOG"; rm -f "$MOCK_STATE/repaired"
out="$(printf 'Body.\n' | PATH="$MOCKBIN:$PATH" MOCK_LOG="$MOCK_LOG" MOCK_STATE="$MOCK_STATE" MOCK_WRONG_BODY=1 \
        "$DIR/create-issue.sh" "specto: gap" - --repo acme/toolkit 2>/dev/null)"; rc=$?
assert "create-issue-self-heal" "exit code 0 (desync repaired)" "$rc" "0"
assert "create-issue-self-heal" "exactly one repair PATCH issued" "$(grep -c -- '--method PATCH' "$MOCK_LOG")" "1"
# Unrepairable: the repair PATCH fails -> exit 1, number still printed.
: > "$MOCK_LOG"; rm -f "$MOCK_STATE/repaired"
out="$(printf 'Body.\n' | PATH="$MOCKBIN:$PATH" MOCK_LOG="$MOCK_LOG" MOCK_STATE="$MOCK_STATE" MOCK_WRONG_BODY=1 MOCK_PATCH_FAILS=1 \
        "$DIR/create-issue.sh" "specto: gap" - --repo acme/toolkit 2>"$MOCKBIN/err")"; rc=$?
assert "create-issue-unrepairable" "exit code 1 (verify failed, repair failed)" "$rc" "1"
assert "create-issue-unrepairable" "number still printed (do not re-file)" "$out" "9"
assert "create-issue-unrepairable" "stderr warns against re-filing" "$(grep -c 'do NOT re-file' "$MOCKBIN/err")" "1"
# Hard failure: non-zero exit AND no URL anywhere -> exit 3 (the only true failure).
printf 'Body.\n' | PATH="$MOCKBIN:$PATH" MOCK_LOG="$MOCK_LOG" MOCK_STATE="$MOCK_STATE" MOCK_CREATE_RC=1 MOCK_NO_URL=1 \
  "$DIR/create-issue.sh" "specto: gap" - --repo acme/toolkit >/dev/null 2>&1; rc=$?
assert "create-issue-hard-failure" "exit code 3 (no URL + non-zero exit)" "$rc" "3"
rm -rf "$MOCKBIN"

# --------------------------------------------------------------------------------
# find-mr-for-ticket.sh: normalized PR list for a ticket key
# --------------------------------------------------------------------------------
echo
echo "== find-mr-for-ticket.sh =="
out="$("$DIR/find-mr-for-ticket.sh" APP-1234 --from-fixture "$FIX/find-pr/prs.json" 2>/dev/null)"; rc=$?
assert "find-mr" "exit code 0" "$rc" "0"
assert "find-mr" "returns a 2-element array" "$(printf '%s' "$out" | jq 'length')" "2"
assert "find-mr" "iid normalized from number" "$(printf '%s' "$out" | jq -r '.[0].iid')" "42"
assert "find-mr" "web_url normalized from url" "$(printf '%s' "$out" | jq -r '.[0].web_url')" "https://github.com/acme/widgets/pull/42"
assert "find-mr" "title normalized" "$(printf '%s' "$out" | jq -r '.[0].title')" "[APP-1234] Add confidence scoring"
assert "find-mr" "state OPEN -> opened" "$(printf '%s' "$out" | jq -r '.[0].state')" "opened"
assert "find-mr" "draft normalized from isDraft" "$(printf '%s' "$out" | jq -r '.[0].draft')" "true"
assert "find-mr" "source_branch normalized from headRefName" "$(printf '%s' "$out" | jq -r '.[0].source_branch')" "f-app-1234"
assert "find-mr" "target_branch normalized from baseRefName" "$(printf '%s' "$out" | jq -r '.[0].target_branch')" "main"
assert "find-mr" "second PR carries the merged state" "$(printf '%s' "$out" | jq -r '.[1].state')" "merged"
assert "find-mr" "exactly the 7 guaranteed fields per entry" "$(printf '%s' "$out" | jq '.[0] | keys | length')" "7"
BADJSON="$(mktemp -t specto-badprs.XXXXXX)"
echo 'not json' > "$BADJSON"
"$DIR/find-mr-for-ticket.sh" APP-1234 --from-fixture "$BADJSON" >/dev/null 2>&1; rc=$?
assert "find-mr-bad-json" "exit code 1 (unparseable JSON)" "$rc" "1"
rm -f "$BADJSON"
"$DIR/find-mr-for-ticket.sh" >/dev/null 2>&1; rc=$?
assert "find-mr-bad-usage" "exit code 2 (no ticket key)" "$rc" "2"
"$DIR/find-mr-for-ticket.sh" APP-1234 --bogus >/dev/null 2>&1; rc=$?
assert "find-mr-unknown-flag" "exit code 2 (unknown flag rejected)" "$rc" "2"
# Live path (mocked gh): the search must scope to the title and the state must
# map to gh's vocabulary (opened -> open).
MOCKBIN="$(mktemp -d)"; MOCK_LOG="$MOCKBIN/calls.log"
cat > "$MOCKBIN/gh" <<'EOF'
#!/usr/bin/env bash
echo "$@" >> "$MOCK_LOG"
cat "$MOCK_FIX/prs.json"
exit 0
EOF
chmod +x "$MOCKBIN/gh"
out="$(PATH="$MOCKBIN:$PATH" MOCK_LOG="$MOCK_LOG" MOCK_FIX="$FIX/find-pr" "$DIR/find-mr-for-ticket.sh" APP-1234 --state opened 2>/dev/null)"; rc=$?
assert "find-mr-live" "exit code 0" "$rc" "0"
assert "find-mr-live" "searches the key scoped to the title" "$(grep -c -- '--search \[APP-1234\] in:title' "$MOCK_LOG")" "1"
assert "find-mr-live" "state opened mapped to gh's open" "$(grep -c -- '--state open ' "$MOCK_LOG")" "1"
rm -rf "$MOCKBIN"

echo
echo "Total: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
