#!/usr/bin/env bash
# Cross-backend contract-conformance suite for the forge dispatcher verbs.
#
# Every case runs the SAME verb with the SAME argv through the dispatcher shim
# (scripts/forge/<verb>.sh) once per backend, pinned via
# SPECTO_BACKEND_OVERRIDE_FORGE, and asserts the decision lines / guaranteed
# JSON fields against ONE shared expected value (docs/adapter-contract.md:
# fixtures are backend-shaped, decision lines are backend-neutral).
#
# Fixture resolution per case+backend: a case fixture under
# tests/fixtures/<case>/<backend>/ wins when present; otherwise the backend
# suite's own fixture (scripts/forge/<backend>/tests/fixtures/<name>) is
# reused. Fully offline: fixture mode only, no glab/gh, no network.
#
# Adding a forge backend = adding it to BACKENDS plus fixtures; the expected
# strings below must never fork per backend.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"    # scripts/forge/tests
FORGE="$(cd "$HERE/.." && pwd)"          # scripts/forge (dispatcher shims)
FIX="$HERE/fixtures"

# Shared assertion helpers + PASS/FAIL counters.
source "$HERE/../../tests/lib/assert.sh"

BACKENDS=(gitlab github)

# fix_for <case> <backend> <backend-fixture-name>: case fixture dir if present,
# else the backend suite's own fixture dir.
fix_for() {
  if [[ -d "$FIX/$1/$2" ]]; then echo "$FIX/$1/$2"; else echo "$FORGE/$2/tests/fixtures/$3"; fi
}

# --------------------------------------------------------------------------------
# create-mr.sh: CREATE when no MR/PR exists, UPDATE iid=<n> when one does
# --------------------------------------------------------------------------------
echo "== create-mr.sh: decision parity =="
EXPECTED_CREATE="CREATE"
EXPECTED_UPDATE="UPDATE iid=42"
for b in "${BACKENDS[@]}"; do
  out="$(printf 'Summary line.\n' | SPECTO_BACKEND_OVERRIDE_FORGE="$b" \
         bash "$FORGE/create-mr.sh" "[APP-1] Title" - \
         --from-fixture "$(fix_for create-mr-new "$b" create-new)" 2>/dev/null)"; rc=$?
  assert "create-mr-create[$b]" "exit code 0" "$rc" "0"
  assert "create-mr-create[$b]" "decision line" "$out" "$EXPECTED_CREATE"

  out="$(printf 'Summary line.\n' | SPECTO_BACKEND_OVERRIDE_FORGE="$b" \
         bash "$FORGE/create-mr.sh" "[APP-1] Title" - \
         --from-fixture "$(fix_for create-mr-existing "$b" create-existing)" 2>/dev/null)"; rc=$?
  assert "create-mr-update[$b]" "exit code 0" "$rc" "0"
  assert "create-mr-update[$b]" "decision line" "$out" "$EXPECTED_UPDATE"
done

# --------------------------------------------------------------------------------
# post-mr-comment.sh: idempotent EDIT, anchored CREATE, GENERAL fallback
# --------------------------------------------------------------------------------
echo
echo "== post-mr-comment.sh: decision parity =="
SPECF="docs/development/specs/x/product-spec.md"
# The marker key is backend-invariant:
#   printf '%s\0%s\0%s\0%s' product-review $SPECF 1-4 metric-overflow | sha1sum | cut -c1-8
NEWSHA="fdbe77ad"

# Idempotent EDIT: the fixture thread carries the marker as discussion d9 / note
# 900 on every backend (github case fixture crafted with matching opaque ids).
EXPECTED_EDIT="EDIT sha8=$NEWSHA discussion=d9 note=900"
for b in "${BACKENDS[@]}"; do
  out="$(printf 'x\n' | SPECTO_BACKEND_OVERRIDE_FORGE="$b" \
         bash "$FORGE/post-mr-comment.sh" product-review "$SPECF" 47 "§1.4" metric-overflow - \
         --from-fixture "$(fix_for post-edit "$b" post-edit)" 2>/dev/null)"; rc=$?
  assert "post-edit[$b]" "exit code 0" "$rc" "0"
  assert "post-edit[$b]" "decision line" "$out" "$EXPECTED_EDIT"
done

# Anchored CREATE on an added line (12): inside a hunk on every backend, so no
# hunks-only divergence can leak into the line.
EXPECTED_ANCHOR="CREATE sha8=$NEWSHA ANCHOR new_line=12"
for b in "${BACKENDS[@]}"; do
  out="$(printf 'x\n' | SPECTO_BACKEND_OVERRIDE_FORGE="$b" \
         bash "$FORGE/post-mr-comment.sh" product-review "$SPECF" 12 "§1.4" metric-overflow - \
         --from-fixture "$(fix_for post-create "$b" post-create)" 2>/dev/null)"; rc=$?
  assert "post-anchor[$b]" "exit code 0" "$rc" "0"
  assert "post-anchor[$b]" "decision line" "$out" "$EXPECTED_ANCHOR"
done

# GENERAL fallback: the file is absent from the diff on every backend.
GSHA="$(printf '%s\0%s\0%s\0%s' product-review docs/development/specs/x/other.md 2 foo | sha1sum | cut -c1-8)"
EXPECTED_GENERAL="CREATE sha8=$GSHA GENERAL"
for b in "${BACKENDS[@]}"; do
  out="$(printf 'x\n' | SPECTO_BACKEND_OVERRIDE_FORGE="$b" \
         bash "$FORGE/post-mr-comment.sh" product-review docs/development/specs/x/other.md 5 "§2" foo - \
         --from-fixture "$(fix_for post-create "$b" post-create)" 2>/dev/null)"; rc=$?
  assert "post-general[$b]" "exit code 0" "$rc" "0"
  assert "post-general[$b]" "decision line" "$out" "$EXPECTED_GENERAL"
done

# --------------------------------------------------------------------------------
# mr-reply.sh: REPLY_RESOLVE (default) / REPLY (--no-resolve) / RESOLVE (--resolve-only)
# --------------------------------------------------------------------------------
echo
echo "== mr-reply.sh: decision parity =="
EXPECTED_REPLY_RESOLVE="REPLY_RESOLVE discussion=abc123"
EXPECTED_REPLY="REPLY discussion=abc123"
EXPECTED_RESOLVE="RESOLVE discussion=abc123"
for b in "${BACKENDS[@]}"; do
  mrfix="$(fix_for mr-reply "$b" mr-reply)"
  out="$(printf 'fixed in 1a2b3c\n' | SPECTO_BACKEND_OVERRIDE_FORGE="$b" \
         bash "$FORGE/mr-reply.sh" abc123 - --from-fixture "$mrfix" 2>/dev/null)"; rc=$?
  assert "mr-reply-default[$b]" "exit code 0" "$rc" "0"
  assert "mr-reply-default[$b]" "decision line" "$out" "$EXPECTED_REPLY_RESOLVE"

  out="$(printf 'deferring: see APP-9999\n' | SPECTO_BACKEND_OVERRIDE_FORGE="$b" \
         bash "$FORGE/mr-reply.sh" abc123 - --no-resolve --from-fixture "$mrfix" 2>/dev/null)"; rc=$?
  assert "mr-reply-no-resolve[$b]" "exit code 0" "$rc" "0"
  assert "mr-reply-no-resolve[$b]" "decision line" "$out" "$EXPECTED_REPLY"

  out="$(SPECTO_BACKEND_OVERRIDE_FORGE="$b" \
         bash "$FORGE/mr-reply.sh" --discussion abc123 --resolve-only --from-fixture "$mrfix" 2>/dev/null)"; rc=$?
  assert "mr-reply-resolve-only[$b]" "exit code 0" "$rc" "0"
  assert "mr-reply-resolve-only[$b]" "decision line" "$out" "$EXPECTED_RESOLVE"
done

# --------------------------------------------------------------------------------
# mr-fetch.sh info: every guaranteed change-request field present and normalized
# --------------------------------------------------------------------------------
echo
echo "== mr-fetch.sh info: guaranteed-field parity =="
# The case fixtures describe the SAME logical change request in each backend's
# raw shape; the guaranteed-field projection must come out byte-identical
# (state lowercased, start_sha = base_sha where the backend has no distinct one).
INFO_PROJ='{iid,web_url,title,state,draft,source_branch,target_branch,diff_refs:(.diff_refs|{base_sha,head_sha,start_sha})}'
EXPECTED_INFO='{"diff_refs":{"base_sha":"base000","head_sha":"head111","start_sha":"base000"},"draft":true,"iid":7,"source_branch":"f-app-1","state":"opened","target_branch":"main","title":"[APP-1] Add confidence scoring","web_url":"https://forge.example/acme/widgets/pull/7"}'
for b in "${BACKENDS[@]}"; do
  raw="$(SPECTO_BACKEND_OVERRIDE_FORGE="$b" \
         bash "$FORGE/mr-fetch.sh" info --from-fixture "$FIX/mr-fetch-info/$b" 2>/dev/null)"; rc=$?
  assert "mr-fetch-info[$b]" "exit code 0" "$rc" "0"
  assert "mr-fetch-info[$b]" "guaranteed fields projection" \
    "$(printf '%s' "$raw" | jq -S -c "$INFO_PROJ" 2>/dev/null)" "$EXPECTED_INFO"
done

assert_summary
