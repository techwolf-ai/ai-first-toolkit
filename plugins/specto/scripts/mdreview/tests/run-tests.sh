#!/usr/bin/env bash
# Test harness for the Specto markdown-reviewer seam helpers. These helpers are
# pure filesystem (no glab/acli, no network), so most assertions run LIVE
# against throwaway temp repos; --from-fixture covers the read-only decision
# path. Fixture model matches the gitlab harness: a directory of JSON files.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/.."
FIX="$HERE/fixtures"

# Shared assertion helpers + PASS/FAIL counters.
source "$HERE/../../tests/lib/assert.sh"

# A throwaway "repo" with one markdown file to anchor line_text reads.
REPO="$(mktemp -d)"
trap 'rm -rf "$REPO"' EXIT
mkdir -p "$REPO/docs"
printf 'line one\nline two\nline three\n' > "$REPO/docs/spec.md"
STORE="$REPO/.md-review/comments.json"

# --------------------------------------------------------------------------------
# add-local-comment.sh
# --------------------------------------------------------------------------------
echo "== add-local-comment.sh =="

# Fresh store: CREATE, sidecar + self-ignoring .gitignore appear, fields normalized.
out="$(printf 'finding body\n' | "$DIR/add-local-comment.sh" "$REPO" docs/spec.md 2 eng-review "§2.3" over-specified-decision - 2>/dev/null)"; rc=$?
assert "add-create" "exit code 0" "$rc" "0"
assert "add-create" "decision is CREATE" "$(printf '%s' "$out" | grep -oE '^CREATE sha8=[0-9a-f]{8}' | grep -c CREATE)" "1"
assert "add-create" "store file created" "$([[ -f "$STORE" ]] && echo yes)" "yes"
assert "add-create" "self-ignoring .gitignore" "$(cat "$REPO/.md-review/.gitignore")" "*"
assert "add-create" "source carries the agent" "$(jq -r '.comments[0].source' "$STORE")" "specto:eng-review"
assert "add-create" "line_text read from the file" "$(jq -r '.comments[0].line_text' "$STORE")" "line two"
assert "add-create" "marker line carries normalized section+type" "$(jq -r '.comments[0].body' "$STORE" | head -1 | grep -c '^\[specto:eng-review#[0-9a-f]\{8\}\] 2-3 over-specified-decision$')" "1"
assert "add-create" "resolved defaults false" "$(jq -r '.comments[0].resolved' "$STORE")" "false"

# Same-marker rerun: EDIT in place — count stays 1, body refreshed, id/created_at kept.
ID1="$(jq -r '.comments[0].id' "$STORE")"
out="$(printf 'reworded finding\n' | "$DIR/add-local-comment.sh" "$REPO" docs/spec.md 3 eng-review "§2.3" over-specified-decision - 2>/dev/null)"; rc=$?
assert "add-edit" "exit code 0" "$rc" "0"
assert "add-edit" "decision is EDIT with the same id" "$out" "EDIT sha8=$(printf '%s' "$out" | sed -E 's/.*sha8=([0-9a-f]{8}).*/\1/') id=$ID1"
assert "add-edit" "still exactly one comment" "$(jq '.comments | length' "$STORE")" "1"
assert "add-edit" "body refreshed" "$(jq -r '.comments[0].body' "$STORE" | sed -n '2p')" "reworded finding"
assert "add-edit" "source_line refreshed" "$(jq -r '.comments[0].source_line' "$STORE")" "3"

# Append preserves a pre-existing human comment (object-identical after the add).
HUMAN='{"id":"human-1","file":"docs/spec.md","source_line":1,"line_text":"line one","commit_sha":"","body":"my own note","created_at":"2026-06-01T00:00:00Z","resolved":false,"source":"","replies":[]}'
jq --argjson h "$HUMAN" '.comments = [$h] + .comments' "$STORE" > "$STORE.tmp" && mv "$STORE.tmp" "$STORE"
printf 'second finding\n' | "$DIR/add-local-comment.sh" "$REPO" docs/spec.md 1 scope-review "§1" scope-creep - >/dev/null 2>&1; rc=$?
assert "add-append" "exit code 0" "$rc" "0"
assert "add-append" "three comments now" "$(jq '.comments | length' "$STORE")" "3"
assert "add-append" "human comment untouched" "$(jq -c '.comments[] | select(.id == "human-1")' "$STORE")" "$(printf '%s' "$HUMAN" | jq -c .)"

# Different finding-type on the same section: a second specto comment, not an edit.
assert "add-append" "distinct keys create distinct comments" "$(jq '[.comments[] | select(.source == "specto:eng-review" or .source == "specto:scope-review")] | length' "$STORE")" "2"

# Malformed store: refuse to clobber, exit 1, file unchanged.
cp "$STORE" "$STORE.bak"
echo 'not json' > "$STORE"
printf 'x\n' | "$DIR/add-local-comment.sh" "$REPO" docs/spec.md 1 eng-review "§1" foo - >/dev/null 2>&1; rc=$?
assert "add-malformed" "exit code 1 (never clobber)" "$rc" "1"
assert "add-malformed" "store left untouched" "$(cat "$STORE")" "not json"
mv "$STORE.bak" "$STORE"

# Empty body / bad usage.
printf '   \n' | "$DIR/add-local-comment.sh" "$REPO" docs/spec.md 1 eng-review "§1" foo - >/dev/null 2>&1; rc=$?
assert "add-empty-body" "exit code 1 (empty body)" "$rc" "1"
"$DIR/add-local-comment.sh" "$REPO" docs/spec.md >/dev/null 2>&1; rc=$?
assert "add-bad-usage" "exit code 2 (too few args)" "$rc" "2"
printf 'x\n' | "$DIR/add-local-comment.sh" "$REPO" docs/spec.md notanumber eng-review "§1" foo - >/dev/null 2>&1; rc=$?
assert "add-bad-line" "exit code 2 (non-numeric line)" "$rc" "2"

# Fixture mode: decision printed, nothing written.
out="$(printf 'x\n' | "$DIR/add-local-comment.sh" "$REPO" docs/other.md 1 eng-review "§9" new-finding - --from-fixture "$FIX/store-existing" 2>/dev/null)"; rc=$?
assert "add-fixture" "exit code 0" "$rc" "0"
assert "add-fixture" "CREATE decision against the fixture store" "$(printf '%s' "$out" | grep -c '^CREATE ')" "1"
assert "add-fixture" "live store untouched by fixture mode" "$(jq '.comments | length' "$STORE")" "3"

# --------------------------------------------------------------------------------
# list-local-comments.sh
# --------------------------------------------------------------------------------
echo
echo "== list-local-comments.sh =="

out="$("$DIR/list-local-comments.sh" "$REPO" 2>/dev/null)"; rc=$?
assert "list-all" "exit code 0" "$rc" "0"
assert "list-all" "lists every comment" "$(printf '%s\n' "$out" | grep -c .)" "3"

out="$("$DIR/list-local-comments.sh" "$REPO" --specto-only 2>/dev/null)"
assert "list-specto" "filters out the human comment" "$(printf '%s\n' "$out" | grep -c .)" "2"
assert "list-specto" "parses agent from the marker" "$(printf '%s\n' "$out" | jq -r 'select(.agent == "eng-review") | .agent')" "eng-review"
assert "list-specto" "parses normalized section" "$(printf '%s\n' "$out" | jq -r 'select(.agent == "eng-review") | .section')" "2-3"
assert "list-specto" "parses finding_type" "$(printf '%s\n' "$out" | jq -r 'select(.agent == "eng-review") | .finding_type')" "over-specified-decision"
assert "list-specto" "body_clean strips the marker line" "$(printf '%s\n' "$out" | jq -r 'select(.agent == "eng-review") | .body_clean')" "reworded finding"

# Resolve one specto comment in the store; --unresolved drops it.
jq '(.comments[] | select(.source == "specto:eng-review") | .resolved) = true' "$STORE" > "$STORE.tmp" && mv "$STORE.tmp" "$STORE"
out="$("$DIR/list-local-comments.sh" "$REPO" --specto-only --unresolved 2>/dev/null)"
assert "list-unresolved" "resolved (triaged-away) findings are dropped" "$(printf '%s\n' "$out" | grep -c .)" "1"
assert "list-unresolved" "the survivor is the unresolved one" "$(printf '%s\n' "$out" | jq -r '.agent')" "scope-review"

# Missing store = empty list; malformed store = exit 1.
EMPTYREPO="$(mktemp -d)"
out="$("$DIR/list-local-comments.sh" "$EMPTYREPO" 2>/dev/null)"; rc=$?
assert "list-missing" "exit code 0 on missing store" "$rc" "0"
assert "list-missing" "empty output" "$out" ""
rm -rf "$EMPTYREPO"
echo 'junk' > "$STORE"
"$DIR/list-local-comments.sh" "$REPO" >/dev/null 2>&1; rc=$?
assert "list-malformed" "exit code 1 on malformed store" "$rc" "1"
"$DIR/list-local-comments.sh" >/dev/null 2>&1; rc=$?
assert "list-bad-usage" "exit code 2 (no repo root)" "$rc" "2"

echo
echo "Total: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
