#!/usr/bin/env bash
# Test harness for the Specto gitlab helper scripts.
# All assertions run the helpers in --from-fixture <dir> mode (no glab, no network).
# Fixture model: a fixture is a DIRECTORY under tests/fixtures/ holding the JSON/txt
# files the helper would otherwise fetch (info.json, discussions.json, mr.json,
# pipelines.json, jobs.json, trace-<id>.txt — depending on the helper).

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/.."
FIX="$HERE/fixtures"

# Shared assertion helpers + PASS/FAIL counters.
source "$HERE/../../../tests/lib/assert.sh"

# --------------------------------------------------------------------------------
# mr-fetch.sh
# --------------------------------------------------------------------------------
echo "== mr-fetch.sh =="
out="$("$DIR/mr-fetch.sh" discussions --from-fixture "$FIX/mr-basic" 2>/dev/null)"; rc=$?
assert "mr-fetch-discussions" "exit code 0" "$rc" "0"
assert "mr-fetch-discussions" "returns a 2-element array" "$(printf '%s' "$out" | jq 'length')" "2"
out="$("$DIR/mr-fetch.sh" info --from-fixture "$FIX/mr-basic" 2>/dev/null)"; rc=$?
assert "mr-fetch-info" "exit code 0" "$rc" "0"
assert "mr-fetch-info" "head_sha resolved from diff_refs" "$(printf '%s' "$out" | jq -r '.diff_refs.head_sha')" "head111"
out="$("$DIR/mr-fetch.sh" diff --from-fixture "$FIX/mr-basic" 2>/dev/null)"; rc=$?
assert "mr-fetch-diff" "exit code 0" "$rc" "0"
assert "mr-fetch-diff" "returns the file's diff entry" "$(printf '%s' "$out" | jq -r '.[0].new_path')" "docs/development/specs/x/product-spec.md"
# Live-path regression: the GitLab /diffs endpoint COLLAPSES large per-file
# diffs (empty .diff + collapsed:true), which silently stripped the hunks needed to
# anchor a line. The diff read path must instead hit /changes?access_raw_diffs=true
# (raw, uncollapsed) and extract the inner `.changes[]` array. Mock glab to assert
# both the endpoint and the extraction (fixture mode can't exercise the live URL).
MOCKBIN="$(mktemp -d)"; MOCK_LOG="$MOCKBIN/calls.log"
cat > "$MOCKBIN/glab" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  repo) echo '{"id":123}'; exit 0 ;;                       # repo view --output json
  api)  echo "$@" >> "$MOCK_LOG"                            # record the API path
        echo '{"changes":[{"old_path":"a.md","new_path":"a.md","diff":"@@ -1 +1 @@\n-x\n+y\n"}]}' ;;
esac
EOF
chmod +x "$MOCKBIN/glab"
out="$(PATH="$MOCKBIN:$PATH" MOCK_LOG="$MOCK_LOG" "$DIR/mr-fetch.sh" diff --iid 2 2>/dev/null)"; rc=$?
assert "mr-fetch-diff-live" "exit code 0" "$rc" "0"
assert "mr-fetch-diff-live" "hits /changes?access_raw_diffs=true (not collapsed /diffs)" "$(grep -c 'merge_requests/2/changes?access_raw_diffs=true' "$MOCK_LOG")" "1"
assert "mr-fetch-diff-live" "never hits the collapsing /diffs endpoint" "$(grep -c 'merge_requests/2/diffs' "$MOCK_LOG")" "0"
assert "mr-fetch-diff-live" "extracts the inner .changes[] as a flat array" "$(printf '%s' "$out" | jq -r '.[0].new_path')" "a.md"
rm -rf "$MOCKBIN"
"$DIR/mr-fetch.sh" >/dev/null 2>&1; rc=$?
assert "mr-fetch-bad-usage" "exit code 2 (no subcommand)" "$rc" "2"
"$DIR/mr-fetch.sh" notathing >/dev/null 2>&1; rc=$?
assert "mr-fetch-bad-subcommand" "exit code 2 (unknown subcommand)" "$rc" "2"
# --iid and --branch accepted (fixture mode bypasses the live lookup, so we just
# verify the parser surface and the bad-usage rejections).
out="$("$DIR/mr-fetch.sh" info --iid 42 --from-fixture "$FIX/mr-basic" 2>/dev/null)"; rc=$?
assert "mr-fetch-iid" "exit code 0 (--iid accepted alongside fixture)" "$rc" "0"
out="$("$DIR/mr-fetch.sh" info --branch f-foo --from-fixture "$FIX/mr-basic" 2>/dev/null)"; rc=$?
assert "mr-fetch-branch" "exit code 0 (--branch accepted alongside fixture)" "$rc" "0"
"$DIR/mr-fetch.sh" info --iid 1 --branch f-foo --from-fixture "$FIX/mr-basic" >/dev/null 2>&1; rc=$?
assert "mr-fetch-iid-and-branch" "exit code 2 (--iid + --branch mutually exclusive)" "$rc" "2"
"$DIR/mr-fetch.sh" info --iid --from-fixture "$FIX/mr-basic" >/dev/null 2>&1; rc=$?
assert "mr-fetch-iid-no-arg" "exit code 2 (bare --iid rejected)" "$rc" "2"

# --------------------------------------------------------------------------------
# post-mr-comment.sh — idempotent line-anchored discussion
# --------------------------------------------------------------------------------
echo
echo "== post-mr-comment.sh =="
# Deterministic key from (agent, spec-path, section, finding-type). §1.4 normalizes
# to 1-4; metric-overflow is already normalized. Recompute if inputs change:
#   printf '%s\0%s\0%s\0%s' product-review docs/development/specs/x/product-spec.md 1-4 metric-overflow | sha1sum | cut -c1-8
NEWSHA="fdbe77ad"
SPECF="docs/development/specs/x/product-spec.md"

# CREATE on an unchanged line OUTSIDE the hunk (line 47): old_line = 47 - delta(=2) = 45.
out="$(printf 'x\n' | "$DIR/post-mr-comment.sh" product-review "$SPECF" 47 "§1.4" metric-overflow - --from-fixture "$FIX/post-create" 2>/dev/null)"; rc=$?
assert "post-create" "exit code 0" "$rc" "0"
assert "post-create" "CREATE + anchors unchanged line with both old/new" "$out" "CREATE sha8=$NEWSHA ANCHOR new_line=47 old_line=45"

# Added line (12) -> new_line only.
out="$(printf 'x\n' | "$DIR/post-mr-comment.sh" product-review "$SPECF" 12 "§1.4" metric-overflow - --from-fixture "$FIX/post-create" 2>/dev/null)"
assert "post-create-added" "CREATE + anchors added line with new_line only" "$out" "CREATE sha8=$NEWSHA ANCHOR new_line=12"

# Context line inside the hunk (10) -> both old/new from the hunk walk.
out="$(printf 'x\n' | "$DIR/post-mr-comment.sh" product-review "$SPECF" 10 "§1.4" metric-overflow - --from-fixture "$FIX/post-create" 2>/dev/null)"
assert "post-create-context" "CREATE + anchors hunk context line" "$out" "CREATE sha8=$NEWSHA ANCHOR new_line=10 old_line=10"

# File not in the MR diff -> general-note fallback.
out="$(printf 'x\n' | "$DIR/post-mr-comment.sh" product-review docs/development/specs/x/other.md 5 "§2" foo - --from-fixture "$FIX/post-create" 2>/dev/null)"
GSHA="$(printf '%s\0%s\0%s\0%s' product-review docs/development/specs/x/other.md 2 foo | sha1sum | cut -c1-8)"
assert "post-create-general" "file absent from diff -> GENERAL fallback" "$out" "CREATE sha8=$GSHA GENERAL"

# File present in the diff but with an empty/hunk-less diff -> still GENERAL (not a bogus anchor).
out="$(printf 'x\n' | "$DIR/post-mr-comment.sh" product-review docs/development/specs/x/binary.md 5 "§9" bar - --from-fixture "$FIX/post-create" 2>/dev/null)"
EBSHA="$(printf '%s\0%s\0%s\0%s' product-review docs/development/specs/x/binary.md 9 bar | sha1sum | cut -c1-8)"
assert "post-create-emptydiff" "file with empty diff -> GENERAL fallback" "$out" "CREATE sha8=$EBSHA GENERAL"

# Path tolerance: reviewer agents are handed an ABSOLUTE spec_path, but the diff
# entry's path is repo-relative. The helper must match by repo-relative suffix and
# still anchor (not silently degrade to a general note). Absolute path -> same anchor
# decision as the repo-relative form (line 47 -> unchanged-outside-hunk, old=45).
ABS="/Users/x/checkout/$SPECF"
out="$(printf 'x\n' | "$DIR/post-mr-comment.sh" product-review "$ABS" 47 "§1.4" metric-overflow - --from-fixture "$FIX/post-create" 2>/dev/null)"
ABSSHA="$(printf '%s\0%s\0%s\0%s' product-review "$ABS" 1-4 metric-overflow | sha1sum | cut -c1-8)"
assert "post-create-abspath" "absolute spec-path anchors via repo-relative suffix match" "$out" "CREATE sha8=$ABSSHA ANCHOR new_line=47 old_line=45"
# A genuinely different file (different basename) must NOT false-match -> GENERAL.
out="$(printf 'x\n' | "$DIR/post-mr-comment.sh" product-review /tmp/some-other-spec-copy.md 47 "§1.4" metric-overflow - --from-fixture "$FIX/post-create" 2>/dev/null)"
OSHA="$(printf '%s\0%s\0%s\0%s' product-review /tmp/some-other-spec-copy.md 1-4 metric-overflow | sha1sum | cut -c1-8)"
assert "post-create-nopath" "unrelated path does not false-match -> GENERAL" "$out" "CREATE sha8=$OSHA GENERAL"

# Live POST regression: the anchor position MUST be POSTed as nested JSON via
# --input. glab's `-f position[new_line]=…` serializes a flat JSON key GitLab ignores,
# silently producing a general DiscussionNote. Mock glab to (a) capture the request
# body and assert it carries a nested position.new_line with NO flat "position[" key,
# and (b) confirm the helper fails loudly when GitLab returns a note without a position.
MOCKBIN="$(mktemp -d)"; MOCK_PAYLOAD="$MOCKBIN/payload.json"
cat > "$MOCKBIN/glab" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  repo) echo '{"id":123}'; exit 0 ;;
  mr) case "$2" in view) echo '{"iid":2}';; list) echo '[{"iid":2}]';; esac; exit 0 ;;
  api)
    if printf '%s\n' "$@" | grep -qx -- '--input'; then   # the create POST (only call using --input)
      prev=""; infile=""
      for a in "$@"; do [[ "$prev" == "--input" ]] && infile="$a"; prev="$a"; done
      cat "$infile" >> "$MOCK_PAYLOAD"
      if [[ -n "${MOCK_DROP_POSITION:-}" ]]; then
        echo '{"id":"d1","notes":[{"id":1,"type":"DiscussionNote","position":null}]}'
      else
        jq -n --argjson p "$(jq -c '.position // null' "$infile")" '{id:"d1",notes:[{id:1,position:$p}]}'
      fi
      exit 0
    fi
    case "$*" in
      *changes*)     echo '{"changes":[{"old_path":"docs/x/spec.md","new_path":"docs/x/spec.md","diff":"@@ -1,2 +1,3 @@\n ctx\n+added\n ctx2\n"}]}' ;;
      *discussions*) echo '[]' ;;
      *)             echo '{"diff_refs":{"base_sha":"b","head_sha":"h","start_sha":"s"}}' ;;
    esac
    exit 0 ;;
esac
exit 0
EOF
chmod +x "$MOCKBIN/glab"
# line 2 of the mock diff is an added line -> ADDED anchor -> position.new_line=2
out="$(printf 'finding body\n' | PATH="$MOCKBIN:$PATH" SOURCE_BRANCH=fake MOCK_PAYLOAD="$MOCK_PAYLOAD" \
        "$DIR/post-mr-comment.sh" product-review docs/x/spec.md 2 "§1" topic - 2>/dev/null)"; rc=$?
assert "post-live-anchor" "exit 0 when GitLab returns a positioned note" "$rc" "0"
assert "post-live-anchor" "POST body carries nested position.new_line" "$(jq -r '.position.new_line' "$MOCK_PAYLOAD" 2>/dev/null)" "2"
assert "post-live-anchor" "POST body has NO flat 'position[' key (not -f encoded)" "$(jq -r 'paths|join(".")' "$MOCK_PAYLOAD" 2>/dev/null | grep -c '\[')" "0"
: > "$MOCK_PAYLOAD"
PATH="$MOCKBIN:$PATH" SOURCE_BRANCH=fake MOCK_PAYLOAD="$MOCK_PAYLOAD" MOCK_DROP_POSITION=1 \
  bash -c 'printf "b\n" | "$0" product-review docs/x/spec.md 2 "§1" topic -' "$DIR/post-mr-comment.sh" >/dev/null 2>&1; rc=$?
assert "post-live-dropped" "exit 3 when GitLab drops the anchor (note has no position)" "$rc" "3"
rm -rf "$MOCKBIN"

# EDIT: post-edit fixture carries the NEWSHA marker -> edits in place.
out="$(printf 'x\n' | "$DIR/post-mr-comment.sh" product-review "$SPECF" 47 "§1.4" metric-overflow - --from-fixture "$FIX/post-edit" 2>/dev/null)"; rc=$?
assert "post-edit" "exit code 0" "$rc" "0"
assert "post-edit" "decides EDIT against the matching note" "$out" "EDIT sha8=$NEWSHA discussion=d9 note=900"

# Deterministic-key stability: same section+type, different wording/casing/spacing -> same sha8.
out2="$(printf 'x\n' | "$DIR/post-mr-comment.sh" product-review "$SPECF" 99 " 1.4 " "Metric Overflow" - --from-fixture "$FIX/post-create" 2>/dev/null)"
assert "post-key-stable" "wording/casing variants hash to the same sha8" "$(printf '%s' "$out2" | sed -E 's/.*sha8=([0-9a-f]+).*/\1/')" "$NEWSHA"

printf '   \n' | "$DIR/post-mr-comment.sh" product-review docs/development/specs/x/product-spec.md 1 "§1" k - --from-fixture "$FIX/post-create" >/dev/null 2>&1; rc=$?
assert "post-empty-body" "exit code 1 (empty body)" "$rc" "1"
"$DIR/post-mr-comment.sh" only three args >/dev/null 2>&1; rc=$?
assert "post-bad-usage" "exit code 2 (too few args)" "$rc" "2"

# --------------------------------------------------------------------------------
# create-mr.sh — idempotent create-vs-update
# --------------------------------------------------------------------------------
echo
echo "== create-mr.sh =="
out="$(printf 'Summary line.\n' | "$DIR/create-mr.sh" "[APP-1] Title" - --from-fixture "$FIX/create-new" 2>/dev/null)"; rc=$?
assert "create-mr-create" "exit code 0" "$rc" "0"
assert "create-mr-create" "decides CREATE when no MR exists" "$out" "CREATE"
out="$(printf 'Summary line.\n' | "$DIR/create-mr.sh" "[APP-1] Title" - --reviewer alice --reviewer bob --from-fixture "$FIX/create-existing" 2>/dev/null)"; rc=$?
assert "create-mr-update" "exit code 0" "$rc" "0"
assert "create-mr-update" "decides UPDATE when an MR exists" "$out" "UPDATE iid=42"
out="$(printf 'Summary line.\n' | "$DIR/create-mr.sh" "[APP-1] Title" - --assignee alice --assignee bob --from-fixture "$FIX/create-new" 2>/dev/null)"; rc=$?
assert "create-mr-assignees" "exit code 0 (--assignee accepted, repeatable)" "$rc" "0"
assert "create-mr-assignees" "still decides CREATE with assignees set" "$out" "CREATE"
# Live-path regression: verify the implementer is assigned by default — the
# user's friction was a no-assignee MR. Mock glab so the script reaches the
# create branch (first `mr view` exits 1 → no MR), then assert the recorded
# `mr create` carries `--assignee @me`.
MOCKBIN="$(mktemp -d)"; MOCK_LOG="$MOCKBIN/calls.log"
cat > "$MOCKBIN/glab" <<'EOF'
#!/usr/bin/env bash
echo "$@" >> "$MOCK_LOG"
case "$1 $2" in
  "mr view")
    # Second view (after a successful create) returns the MR URL.
    if [[ $(grep -c '^mr create' "$MOCK_LOG") -ge 1 ]]; then
      echo '{"web_url":"https://gitlab.example/mr/1"}'; exit 0
    fi
    exit 1
    ;;
  "mr create") exit 0 ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$MOCKBIN/glab"
out="$(printf 'Summary line.\n' | PATH="$MOCKBIN:$PATH" MOCK_LOG="$MOCK_LOG" SOURCE_BRANCH=f-test "$DIR/create-mr.sh" "[APP-1] Title" - 2>/dev/null)"; rc=$?
assert "create-mr-default-assignee" "exit code 0" "$rc" "0"
assert "create-mr-default-assignee" "create call carries --assignee @me by default" "$(grep -c '^mr create.* --assignee @me ' "$MOCK_LOG")" "1"
rm -rf "$MOCKBIN"
# And explicit --assignee replaces the @me default (single replace, not augment).
MOCKBIN="$(mktemp -d)"; MOCK_LOG="$MOCKBIN/calls.log"
cat > "$MOCKBIN/glab" <<'EOF'
#!/usr/bin/env bash
echo "$@" >> "$MOCK_LOG"
case "$1 $2" in
  "mr view")
    if [[ $(grep -c '^mr create' "$MOCK_LOG") -ge 1 ]]; then
      echo '{"web_url":"https://gitlab.example/mr/1"}'; exit 0
    fi
    exit 1
    ;;
  "mr create") exit 0 ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$MOCKBIN/glab"
out="$(printf 'Summary line.\n' | PATH="$MOCKBIN:$PATH" MOCK_LOG="$MOCK_LOG" SOURCE_BRANCH=f-test "$DIR/create-mr.sh" "[APP-1] Title" - --assignee alice 2>/dev/null)"; rc=$?
assert "create-mr-explicit-assignee" "exit code 0" "$rc" "0"
assert "create-mr-explicit-assignee" "explicit --assignee carries through" "$(grep -c '^mr create.* --assignee alice ' "$MOCK_LOG")" "1"
assert "create-mr-explicit-assignee" "@me default is NOT added when explicit assignee passed" "$(grep -c '^mr create.* --assignee @me ' "$MOCK_LOG")" "0"
rm -rf "$MOCKBIN"
printf '  \n' | "$DIR/create-mr.sh" "T" - --from-fixture "$FIX/create-new" >/dev/null 2>&1; rc=$?
assert "create-mr-empty-desc" "exit code 1 (empty description)" "$rc" "1"
"$DIR/create-mr.sh" "only title" >/dev/null 2>&1; rc=$?
assert "create-mr-bad-usage" "exit code 2 (too few args)" "$rc" "2"

# --------------------------------------------------------------------------------
# mr-reply.sh — reply to (and optionally resolve) an MR discussion thread
# --------------------------------------------------------------------------------
echo
echo "== mr-reply.sh =="
out="$(printf 'fixed in 1a2b3c\n' | "$DIR/mr-reply.sh" abc123 - --from-fixture "$FIX/mr-reply" 2>/dev/null)"; rc=$?
assert "mr-reply-default" "exit code 0" "$rc" "0"
assert "mr-reply-default" "default decision is REPLY_RESOLVE" "$out" "REPLY_RESOLVE discussion=abc123"
out="$(printf 'deferring — see APP-9999\n' | "$DIR/mr-reply.sh" abc123 - --no-resolve --from-fixture "$FIX/mr-reply" 2>/dev/null)"; rc=$?
assert "mr-reply-no-resolve" "exit code 0" "$rc" "0"
assert "mr-reply-no-resolve" "--no-resolve decision is REPLY only" "$out" "REPLY discussion=abc123"
printf '   \n' | "$DIR/mr-reply.sh" abc123 - --from-fixture "$FIX/mr-reply" >/dev/null 2>&1; rc=$?
assert "mr-reply-empty-body" "exit code 1 (empty body)" "$rc" "1"
"$DIR/mr-reply.sh" only-one-arg >/dev/null 2>&1; rc=$?
assert "mr-reply-bad-usage" "exit code 2 (too few args)" "$rc" "2"
# --discussion flag form mirrors the legacy positional form.
out="$(printf 'fixed\n' | "$DIR/mr-reply.sh" --discussion d99 - --from-fixture "$FIX/mr-reply" 2>/dev/null)"; rc=$?
assert "mr-reply-discussion-flag" "exit code 0" "$rc" "0"
assert "mr-reply-discussion-flag" "decision is REPLY_RESOLVE" "$out" "REPLY_RESOLVE discussion=d99"
out="$(printf 'deferred\n' | "$DIR/mr-reply.sh" --discussion d99 - --no-resolve --from-fixture "$FIX/mr-reply" 2>/dev/null)"
assert "mr-reply-discussion-no-resolve" "decision is REPLY only" "$out" "REPLY discussion=d99"
# Non-resolvable discussions (bot threads, MR description note, …) use the
# same endpoint as resolvable ones — just with --no-resolve to skip the
# resolve PUT that would otherwise 4xx. (Earlier V0.9 drafts tried a separate
# --note <NOTE_ID> mode hitting POST .../notes/:note_id/notes; that endpoint
# does not exist in the GitLab API. Single-discussion-endpoint is the right
# model. This assertion locks the contract in.)
out="$(printf 'bot reply\n' | "$DIR/mr-reply.sh" --discussion bot_d99 - --no-resolve --from-fixture "$FIX/mr-reply" 2>/dev/null)"
assert "mr-reply-nonresolvable-thread" "non-resolvable discussions use --discussion + --no-resolve" "$out" "REPLY discussion=bot_d99"
# Unknown flag still rejected.
printf 'x\n' | "$DIR/mr-reply.sh" --discussion d1 - --bogus --from-fixture "$FIX/mr-reply" >/dev/null 2>&1; rc=$?
assert "mr-reply-unknown-flag" "exit code 2 (unknown flag rejected)" "$rc" "2"
# --iid / --branch MR-targeting flags (parity with mr-fetch.sh). Fixture mode
# bypasses the live MR lookup, so these verify the parser surface + bad-usage
# rejections under BOTH the legacy positional and the --discussion forms.
out="$(printf 'x\n' | "$DIR/mr-reply.sh" abc123 - --iid 42 --from-fixture "$FIX/mr-reply" 2>/dev/null)"; rc=$?
assert "mr-reply-iid" "exit code 0 (--iid accepted, legacy form)" "$rc" "0"
out="$(printf 'x\n' | "$DIR/mr-reply.sh" abc123 - --branch f-foo --from-fixture "$FIX/mr-reply" 2>/dev/null)"; rc=$?
assert "mr-reply-branch" "exit code 0 (--branch accepted, legacy form)" "$rc" "0"
out="$(printf 'x\n' | "$DIR/mr-reply.sh" --discussion d99 - --iid 42 --from-fixture "$FIX/mr-reply" 2>/dev/null)"; rc=$?
assert "mr-reply-discussion-iid" "exit code 0 (--iid accepted, --discussion form)" "$rc" "0"
out="$(printf 'x\n' | "$DIR/mr-reply.sh" --discussion d99 - --branch f-foo --from-fixture "$FIX/mr-reply" 2>/dev/null)"; rc=$?
assert "mr-reply-discussion-branch" "exit code 0 (--branch accepted, --discussion form)" "$rc" "0"
printf 'x\n' | "$DIR/mr-reply.sh" abc123 - --iid 1 --branch f-foo --from-fixture "$FIX/mr-reply" >/dev/null 2>&1; rc=$?
assert "mr-reply-iid-and-branch" "exit code 2 (--iid + --branch mutually exclusive)" "$rc" "2"
printf 'x\n' | "$DIR/mr-reply.sh" abc123 - --iid --from-fixture "$FIX/mr-reply" >/dev/null 2>&1; rc=$?
assert "mr-reply-iid-no-arg" "exit code 2 (bare --iid rejected)" "$rc" "2"

# Live path (mocked glab): --iid <N> must target that MR DIRECTLY — no branch/cwd
# guessing. Regression for #12: replying by IID on a detached HEAD / wrong cwd
# previously exited 3 ("no open MR for branch ..."). Assert the reply POST hits
# merge_requests/42/... and `glab mr` (view/list) is never consulted.
MOCKBIN="$(mktemp -d)"; MOCK_LOG="$MOCKBIN/calls.log"
cat > "$MOCKBIN/glab" <<'EOF'
#!/usr/bin/env bash
echo "$@" >> "$MOCK_LOG"
case "$1" in
  repo) echo '{"id":123}'; exit 0 ;;
esac
exit 0
EOF
chmod +x "$MOCKBIN/glab"
printf 'reply body\n' | PATH="$MOCKBIN:$PATH" MOCK_LOG="$MOCK_LOG" \
  "$DIR/mr-reply.sh" --discussion abc123 - --iid 42 --no-resolve >/dev/null 2>&1; rc=$?
assert "mr-reply-iid-live" "exit code 0" "$rc" "0"
assert "mr-reply-iid-live" "reply POST targets merge_requests/42" "$(grep -c 'merge_requests/42/discussions/abc123/notes' "$MOCK_LOG")" "1"
assert "mr-reply-iid-live" "never consults 'glab mr' (no branch guessing)" "$(grep -cE '^mr ' "$MOCK_LOG")" "0"
rm -rf "$MOCKBIN"

# --resolve-only: resolve the thread WITHOUT posting a reply — for feedback
# already fixed in the pushed commit, where a "resolved" note is noise.
out="$("$DIR/mr-reply.sh" --discussion d99 --resolve-only --from-fixture "$FIX/mr-reply" 2>/dev/null)"; rc=$?
assert "mr-reply-resolve-only" "exit code 0" "$rc" "0"
assert "mr-reply-resolve-only" "decision is RESOLVE (no reply)" "$out" "RESOLVE discussion=d99"
"$DIR/mr-reply.sh" --discussion d99 - --resolve-only --from-fixture "$FIX/mr-reply" </dev/null >/dev/null 2>&1; rc=$?
assert "mr-reply-resolve-only-body" "exit code 2 (--resolve-only takes no body)" "$rc" "2"
"$DIR/mr-reply.sh" --discussion d99 --resolve-only --no-resolve --from-fixture "$FIX/mr-reply" >/dev/null 2>&1; rc=$?
assert "mr-reply-resolve-only-conflict" "exit code 2 (--resolve-only + --no-resolve contradict)" "$rc" "2"
# Live path (mocked glab): no POST to /notes, exactly one resolve PUT.
MOCKBIN="$(mktemp -d)"; MOCK_LOG="$MOCKBIN/calls.log"
cat > "$MOCKBIN/glab" <<'EOF'
#!/usr/bin/env bash
echo "$@" >> "$MOCK_LOG"
case "$1" in
  repo) echo '{"id":123}'; exit 0 ;;
esac
exit 0
EOF
chmod +x "$MOCKBIN/glab"
PATH="$MOCKBIN:$PATH" MOCK_LOG="$MOCK_LOG" \
  "$DIR/mr-reply.sh" --discussion abc123 --resolve-only --iid 42 >/dev/null 2>&1; rc=$?
assert "mr-reply-resolve-only-live" "exit code 0" "$rc" "0"
assert "mr-reply-resolve-only-live" "no reply POST to /notes" "$(grep -c '/notes' "$MOCK_LOG")" "0"
assert "mr-reply-resolve-only-live" "exactly one resolve PUT" "$(grep -c 'discussions/abc123?resolved=true' "$MOCK_LOG")" "1"
rm -rf "$MOCKBIN"

# --------------------------------------------------------------------------------
# create-issue.sh — --repo issue create, prints the new IID
# --------------------------------------------------------------------------------
echo
echo "== create-issue.sh =="
out="$(printf 'Friction body.\n' | "$DIR/create-issue.sh" "specto: some gap" - --from-fixture "$FIX/issue-create" 2>/dev/null)"; rc=$?
assert "create-issue-create" "exit code 0" "$rc" "0"
assert "create-issue-create" "prints the new issue IID" "$out" "7"
printf '  \n' | "$DIR/create-issue.sh" "T" - --from-fixture "$FIX/issue-create" >/dev/null 2>&1; rc=$?
assert "create-issue-empty-body" "exit code 1 (empty body)" "$rc" "1"
"$DIR/create-issue.sh" "only title" >/dev/null 2>&1; rc=$?
assert "create-issue-bad-usage" "exit code 2 (too few args)" "$rc" "2"

# Live path (mocked glab on PATH): current glab prints a /-/work_items/<n> URL, not
# /-/issues/<n>. The IID must still be parsed from it. Faithful regression test for #9.
MOCKBIN="$(mktemp -d)"
cat > "$MOCKBIN/glab" <<'EOF'
#!/usr/bin/env bash
echo "https://gitlab.com/acme/tools/specto/-/work_items/9"
EOF
chmod +x "$MOCKBIN/glab"
out="$(printf 'Body.\n' | PATH="$MOCKBIN:$PATH" "$DIR/create-issue.sh" "specto: gap" - --repo acme/tools/specto 2>/dev/null)"; rc=$?
assert "create-issue-workitems-url" "exit code 0 (work_items URL)" "$rc" "0"
assert "create-issue-workitems-url" "parses IID from work_items URL" "$out" "9"
# The legacy /-/issues/<n> shape must keep working.
cat > "$MOCKBIN/glab" <<'EOF'
#!/usr/bin/env bash
echo "https://gitlab.com/acme/tools/specto/-/issues/7"
EOF
out="$(printf 'Body.\n' | PATH="$MOCKBIN:$PATH" "$DIR/create-issue.sh" "specto: gap" - --repo acme/tools/specto 2>/dev/null)"
assert "create-issue-issues-url" "parses IID from legacy issues URL" "$out" "7"
rm -rf "$MOCKBIN"

# Post-create verification. Fixture mode: an optional verify.json runs the
# title + body-fingerprint check against the submitted values (no repair possible
# in fixture mode — a mismatch reports and exits 1, IID still printed).
out="$(printf 'Friction body.\n\nMore detail here.\n' | "$DIR/create-issue.sh" "specto: some gap" - --from-fixture "$FIX/issue-create-verified" 2>/dev/null)"; rc=$?
assert "create-issue-verified" "exit code 0 (verify.json matches)" "$rc" "0"
assert "create-issue-verified" "prints the IID" "$out" "8"
err="$(printf 'Friction body.\n\nMore detail here.\n' | "$DIR/create-issue.sh" "specto: some gap" - --from-fixture "$FIX/issue-create-desync" 2>&1 >/dev/null)"; rc=$?
out="$(printf 'Friction body.\n\nMore detail here.\n' | "$DIR/create-issue.sh" "specto: some gap" - --from-fixture "$FIX/issue-create-desync" 2>/dev/null)"
assert "create-issue-desync-fixture" "exit code 1 (stored body differs)" "$rc" "1"
assert "create-issue-desync-fixture" "IID still printed (do not re-file)" "$out" "9"
assert "create-issue-desync-fixture" "stderr warns against re-filing" "$(printf '%s\n' "$err" | grep -c 'do NOT re-file')" "1"

# Live-path regressions for the two observed #23 failures, against a mocked glab.
# Scenarios driven by env vars: MOCK_CREATE_RC (issue create exit code),
# MOCK_NO_URL (create prints no URL), MOCK_WRONG_BODY (GET returns another call's
# body until a repair PUT lands), MOCK_PUT_FAILS (the repair PUT errors).
MOCKBIN="$(mktemp -d)"; MOCK_LOG="$MOCKBIN/calls.log"; MOCK_STATE="$MOCKBIN/state"
mkdir -p "$MOCK_STATE"
cat > "$MOCKBIN/glab" <<'EOF'
#!/usr/bin/env bash
echo "$@" >> "$MOCK_LOG"
if [[ "$1" == "issue" && "$2" == "create" ]]; then
  if [[ -n "${MOCK_NO_URL:-}" ]]; then
    echo "error: something went wrong" >&2
  else
    echo "https://gitlab.com/acme/tools/specto/-/work_items/9"
  fi
  exit "${MOCK_CREATE_RC:-0}"
fi
if [[ "$1" == "api" ]]; then
  if printf '%s\n' "$@" | grep -qx -- '--method'; then
    cat >/dev/null   # consume the --input - body
    [[ -n "${MOCK_PUT_FAILS:-}" ]] && exit 1
    touch "$MOCK_STATE/repaired"
    exit 0
  fi
  if [[ -n "${MOCK_WRONG_BODY:-}" && ! -e "$MOCK_STATE/repaired" ]]; then
    echo '{"iid":9,"title":"specto: gap","description":"WRONG body from the next call"}'
  else
    echo '{"iid":9,"title":"specto: gap","description":"Body."}'
  fi
  exit 0
fi
exit 0
EOF
chmod +x "$MOCKBIN/glab"
# False-failure: glab exits 1 but printed the created-issue URL -> success + warning.
: > "$MOCK_LOG"
out="$(printf 'Body.\n' | PATH="$MOCKBIN:$PATH" MOCK_LOG="$MOCK_LOG" MOCK_STATE="$MOCK_STATE" MOCK_CREATE_RC=1 \
        "$DIR/create-issue.sh" "specto: gap" - --repo acme/tools/specto 2>"$MOCKBIN/err")"; rc=$?
assert "create-issue-false-failure" "exit code 0 (URL trumps the non-zero exit)" "$rc" "0"
assert "create-issue-false-failure" "prints the IID" "$out" "9"
assert "create-issue-false-failure" "stderr warns the issue WAS created" "$(grep -c 'WAS created' "$MOCKBIN/err")" "1"
# Desync + self-heal: GET returns another call's body, the repair PUT lands, re-verify passes.
: > "$MOCK_LOG"; rm -f "$MOCK_STATE/repaired"
out="$(printf 'Body.\n' | PATH="$MOCKBIN:$PATH" MOCK_LOG="$MOCK_LOG" MOCK_STATE="$MOCK_STATE" MOCK_WRONG_BODY=1 \
        "$DIR/create-issue.sh" "specto: gap" - --repo acme/tools/specto 2>/dev/null)"; rc=$?
assert "create-issue-self-heal" "exit code 0 (desync repaired)" "$rc" "0"
assert "create-issue-self-heal" "prints the IID" "$out" "9"
assert "create-issue-self-heal" "exactly one repair PUT issued" "$(grep -c -- '--method PUT' "$MOCK_LOG")" "1"
# Unrepairable: the repair PUT fails -> exit 1, IID still printed, loud do-NOT-re-file.
: > "$MOCK_LOG"; rm -f "$MOCK_STATE/repaired"
out="$(printf 'Body.\n' | PATH="$MOCKBIN:$PATH" MOCK_LOG="$MOCK_LOG" MOCK_STATE="$MOCK_STATE" MOCK_WRONG_BODY=1 MOCK_PUT_FAILS=1 \
        "$DIR/create-issue.sh" "specto: gap" - --repo acme/tools/specto 2>"$MOCKBIN/err")"; rc=$?
assert "create-issue-unrepairable" "exit code 1 (verify failed, repair failed)" "$rc" "1"
assert "create-issue-unrepairable" "IID still printed (do not re-file)" "$out" "9"
assert "create-issue-unrepairable" "stderr warns against re-filing" "$(grep -c 'do NOT re-file' "$MOCKBIN/err")" "1"
# Hard failure: non-zero exit AND no URL anywhere -> exit 3 (the only true failure).
: > "$MOCK_LOG"
printf 'Body.\n' | PATH="$MOCKBIN:$PATH" MOCK_LOG="$MOCK_LOG" MOCK_STATE="$MOCK_STATE" MOCK_CREATE_RC=1 MOCK_NO_URL=1 \
  "$DIR/create-issue.sh" "specto: gap" - --repo acme/tools/specto >/dev/null 2>&1; rc=$?
assert "create-issue-hard-failure" "exit code 3 (no URL + non-zero exit)" "$rc" "3"
rm -rf "$MOCKBIN"

# --------------------------------------------------------------------------------
# mr-ready.sh
# --------------------------------------------------------------------------------
echo
echo "== mr-ready.sh =="
"$DIR/mr-ready.sh" --from-fixture "$FIX/mr-basic" >/dev/null 2>&1; rc=$?
assert "mr-ready" "exit code 0 (no-op success in fixture mode)" "$rc" "0"
"$DIR/mr-ready.sh" extra args here >/dev/null 2>&1; rc=$?
assert "mr-ready-bad-usage" "exit code 2 (unexpected args)" "$rc" "2"

# --------------------------------------------------------------------------------
# pipeline-status.sh
# --------------------------------------------------------------------------------
echo
echo "== pipeline-status.sh =="
out="$("$DIR/pipeline-status.sh" --from-fixture "$FIX/pipeline-running" 2>/dev/null)"; rc=$?
assert "pipeline-running" "exit code 0" "$rc" "0"
assert "pipeline-running" "newest pipeline 'running' -> running" "$out" "running"
out="$("$DIR/pipeline-status.sh" --from-fixture "$FIX/pipeline-success" 2>/dev/null)"
assert "pipeline-success" "newest pipeline 'success' -> success" "$out" "success"
out="$("$DIR/pipeline-status.sh" --from-fixture "$FIX/pipeline-none" 2>/dev/null)"
assert "pipeline-none" "empty pipeline list -> none" "$out" "none"
out="$("$DIR/pipeline-status.sh" --from-fixture "$FIX/pipeline-failed" 2>/dev/null)"
assert "pipeline-failed-line1" "first stdout line is 'failed'" "$(printf '%s\n' "$out" | sed -n '1p')" "failed"
assert "pipeline-failed-sep"   "second line is the '---' separator" "$(printf '%s\n' "$out" | sed -n '2p')" "---"
assert "pipeline-failed-jobs"  "failed job ids follow, one per line" "$(printf '%s\n' "$out" | sed -n '3,$p' | tr '\n' ',')" "9002,9003,"
"$DIR/pipeline-status.sh" --from-fixture >/dev/null 2>&1; rc=$?
assert "pipeline-bad-usage" "exit code 2 (--from-fixture without a dir)" "$rc" "2"
# --manual-jobs mode: emits <stage>\t<name>\t<web_url> for each manual job; no
# output when there are no manual jobs.
out="$("$DIR/pipeline-status.sh" --manual-jobs --from-fixture "$FIX/pipeline-with-manual" 2>/dev/null)"; rc=$?
assert "pipeline-manual-jobs"        "exit code 0" "$rc" "0"
assert "pipeline-manual-jobs"        "two manual jobs listed" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" "2"
assert "pipeline-manual-jobs"        "first row stage<TAB>name<TAB>url" "$(printf '%s\n' "$out" | sed -n '1p')" "$(printf 'deploy\tstaging-deploy\thttps://gitlab.example/-/jobs/9102')"
out="$("$DIR/pipeline-status.sh" --manual-jobs --from-fixture "$FIX/pipeline-success" 2>/dev/null)"
assert "pipeline-manual-jobs-none"   "empty stdout when no manual jobs" "$out" ""

# --------------------------------------------------------------------------------
# job-trace.sh
# --------------------------------------------------------------------------------
echo
echo "== job-trace.sh =="
out="$("$DIR/job-trace.sh" 9002 --from-fixture "$FIX/job-trace" 2>/dev/null)"; rc=$?
assert "job-trace" "exit code 0" "$rc" "0"
assert "job-trace" "trace tail includes the failing assertion" "$(printf '%s\n' "$out" | grep -c 'AssertionError: 0.7 != 0.85')" "1"
"$DIR/job-trace.sh" >/dev/null 2>&1; rc=$?
assert "job-trace-bad-usage" "exit code 2 (no job id)" "$rc" "2"
"$DIR/job-trace.sh" 404 --from-fixture "$FIX/job-trace" >/dev/null 2>&1; rc=$?
assert "job-trace-missing" "exit code 3 (no trace file for that job id)" "$rc" "3"

# --------------------------------------------------------------------------------
# find-mr-for-ticket.sh — normalized MR list for a ticket key
# --------------------------------------------------------------------------------
echo
echo "== find-mr-for-ticket.sh =="
out="$("$DIR/find-mr-for-ticket.sh" APP-1234 --from-fixture "$FIX/find-mr/mrs.json" 2>/dev/null)"; rc=$?
assert "find-mr" "exit code 0" "$rc" "0"
assert "find-mr" "returns a 2-element array" "$(printf '%s' "$out" | jq 'length')" "2"
assert "find-mr" "iid normalized" "$(printf '%s' "$out" | jq -r '.[0].iid')" "42"
assert "find-mr" "web_url normalized" "$(printf '%s' "$out" | jq -r '.[0].web_url')" "https://gitlab.example/x/-/merge_requests/42"
assert "find-mr" "title normalized" "$(printf '%s' "$out" | jq -r '.[0].title')" "[APP-1234] Add confidence scoring"
assert "find-mr" "state normalized" "$(printf '%s' "$out" | jq -r '.[0].state')" "opened"
assert "find-mr" "draft normalized" "$(printf '%s' "$out" | jq -r '.[0].draft')" "true"
assert "find-mr" "source_branch normalized" "$(printf '%s' "$out" | jq -r '.[0].source_branch')" "f-app-1234"
assert "find-mr" "target_branch normalized" "$(printf '%s' "$out" | jq -r '.[0].target_branch')" "main"
assert "find-mr" "second MR carries the merged state" "$(printf '%s' "$out" | jq -r '.[1].state')" "merged"
# Guaranteed fields only — extra glab fields must not leak through.
assert "find-mr" "exactly the 7 guaranteed fields per entry" "$(printf '%s' "$out" | jq '.[0] | keys | length')" "7"
BADJSON="$(mktemp -t specto-badmrs.XXXXXX)"
echo 'not json' > "$BADJSON"
"$DIR/find-mr-for-ticket.sh" APP-1234 --from-fixture "$BADJSON" >/dev/null 2>&1; rc=$?
assert "find-mr-bad-json" "exit code 1 (unparseable JSON)" "$rc" "1"
rm -f "$BADJSON"
"$DIR/find-mr-for-ticket.sh" >/dev/null 2>&1; rc=$?
assert "find-mr-bad-usage" "exit code 2 (no ticket key)" "$rc" "2"
"$DIR/find-mr-for-ticket.sh" APP-1234 --bogus >/dev/null 2>&1; rc=$?
assert "find-mr-unknown-flag" "exit code 2 (unknown flag rejected)" "$rc" "2"

echo
echo "== mr-describe.sh — idempotent marker-delimited description section =="
# Fresh description (no markers yet): the section is appended, prior text preserved.
BODY=$'## Change walkthrough\n\n```mermaid\nflowchart TD\n  A-->B\n```'
out="$(printf '%s' "$BODY" | "$DIR/mr-describe.sh" - --from-fixture "$FIX/mr-desc-fresh" 2>/dev/null)"; rc=$?
assert "mr-describe-fresh" "exit code 0" "$rc" "0"
assert "mr-describe-fresh" "prior description text preserved" "$(printf '%s\n' "$out" | grep -c 'Existing MR summary.')" "1"
assert "mr-describe-fresh" "exactly one start marker added" "$(printf '%s\n' "$out" | grep -cF '<!-- specto:walkthrough:start -->')" "1"
assert "mr-describe-fresh" "exactly one end marker added" "$(printf '%s\n' "$out" | grep -cF '<!-- specto:walkthrough:end -->')" "1"
assert "mr-describe-fresh" "new body landed inside the block" "$(printf '%s\n' "$out" | grep -c 'flowchart TD')" "1"
# Existing block: it is REPLACED in place (idempotent), not duplicated.
out="$(printf '%s' "$BODY" | "$DIR/mr-describe.sh" - --from-fixture "$FIX/mr-desc-existing" 2>/dev/null)"; rc=$?
assert "mr-describe-existing" "exit code 0" "$rc" "0"
assert "mr-describe-existing" "still exactly one start marker (no duplicate)" "$(printf '%s\n' "$out" | grep -cF '<!-- specto:walkthrough:start -->')" "1"
assert "mr-describe-existing" "old block content dropped" "$(printf '%s\n' "$out" | grep -c 'OLD diagram')" "0"
assert "mr-describe-existing" "new body present" "$(printf '%s\n' "$out" | grep -c 'flowchart TD')" "1"
assert "mr-describe-existing" "prior description text preserved" "$(printf '%s\n' "$out" | grep -c 'Existing MR summary.')" "1"
# Empty body / bad usage.
printf '   \n' | "$DIR/mr-describe.sh" - --from-fixture "$FIX/mr-desc-fresh" >/dev/null 2>&1; rc=$?
assert "mr-describe-empty-body" "exit code 1 (empty body)" "$rc" "1"
"$DIR/mr-describe.sh" >/dev/null 2>&1; rc=$?
assert "mr-describe-bad-usage" "exit code 2 (no body arg)" "$rc" "2"
printf 'x\n' | "$DIR/mr-describe.sh" - --iid 1 --branch f-foo --from-fixture "$FIX/mr-desc-fresh" >/dev/null 2>&1; rc=$?
assert "mr-describe-iid-and-branch" "exit code 2 (--iid + --branch mutually exclusive)" "$rc" "2"

echo
echo "Total: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
