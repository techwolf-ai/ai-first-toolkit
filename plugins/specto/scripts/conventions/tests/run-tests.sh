#!/usr/bin/env bash
# Test harness for nearest-agents-md.sh. Builds throwaway fake repos in temp dirs
# at runtime — a committed .git/ marker would confuse the outer repo. Asserts the
# nearest-first, deduped, stop-at-repo-root output contract.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/.."
HELPER="$DIR/nearest-agents-md.sh"

# Shared assertion helpers + PASS/FAIL counters.
source "$HERE/../../tests/lib/assert.sh"

# Canonicalize via `cd && pwd` so paths match the helper's own normalization
# (macOS /var -> /private/var symlink would otherwise break exact string match).
ROOT="$(cd "$(mktemp -d -t specto-conventions-test.XXXXXX)" && pwd)"
trap 'rm -rf "$ROOT"' EXIT
mkdir -p "$ROOT/.git" "$ROOT/orbit_api/customers"
echo "root rules" > "$ROOT/AGENTS.md"
echo "feature flags live in feature_flags JSON" > "$ROOT/orbit_api/customers/AGENTS.md"
echo "claude notes" > "$ROOT/orbit_api/customers/CLAUDE.md"
touch "$ROOT/orbit_api/customers/models.py"

expected="$ROOT/orbit_api/customers/AGENTS.md
$ROOT/orbit_api/customers/CLAUDE.md
$ROOT/AGENTS.md"

echo "== nearest-agents-md.sh =="

# Existing file: nearest-first chain; AGENTS.md before CLAUDE.md at the same level.
out="$("$HELPER" "$ROOT/orbit_api/customers/models.py" 2>/dev/null)"; rc=$?
assert "chain" "exit code 0" "$rc" "0"
assert "chain" "nearest-first; both same-level files surface" "$out" "$expected"

# Non-existent leaf resolves to nearest existing ancestor -> same chain.
out="$("$HELPER" "$ROOT/orbit_api/customers/not_yet_created.py" 2>/dev/null)"
assert "nonexistent-leaf" "resolves to existing parent, same chain" "$out" "$expected"

# Directory target behaves like a file under it.
out="$("$HELPER" "$ROOT/orbit_api/customers" 2>/dev/null)"
assert "dir-target" "directory target yields the same chain" "$out" "$expected"

# Dedup across two deep paths sharing the root: root AGENTS.md printed once.
out="$("$HELPER" "$ROOT/orbit_api/customers/models.py" "$ROOT/orbit_api/customers/views.py" 2>/dev/null)"
count_root="$(printf '%s\n' "$out" | grep -c "^$ROOT/AGENTS.md$")"
assert "dedup" "shared root AGENTS.md emitted once across paths" "$count_root" "1"

# Walk stops AT the repo root (.git dir) — never includes an AGENTS.md above it.
NEST="$(cd "$(mktemp -d -t specto-conventions-nest.XXXXXX)" && pwd)"
mkdir -p "$NEST/inner/.git" "$NEST/inner/sub"
echo "above repo" > "$NEST/AGENTS.md"
echo "inner repo" > "$NEST/inner/AGENTS.md"
touch "$NEST/inner/sub/file.py"
out="$("$HELPER" "$NEST/inner/sub/file.py" 2>/dev/null)"
assert "stops-at-root" "includes the inner-repo AGENTS.md" "$out" "$NEST/inner/AGENTS.md"
above="$(printf '%s\n' "$out" | grep -c "^$NEST/AGENTS.md$")"
assert "stops-at-root" "does NOT include the AGENTS.md above the repo root" "$above" "0"
rm -rf "$NEST"

# Repo with no AGENTS.md anywhere -> empty output, exit 0 (not an error).
BARE="$(cd "$(mktemp -d -t specto-conventions-bare.XXXXXX)" && pwd)"
mkdir -p "$BARE/.git" "$BARE/src"
touch "$BARE/src/x.py"
out="$("$HELPER" "$BARE/src/x.py" 2>/dev/null)"; rc=$?
assert "no-conventions" "empty output when none found" "$out" ""
assert "no-conventions" "exit code 0 (empty is not an error)" "$rc" "0"
rm -rf "$BARE"

# A .jj marker is recognized as a repo root too.
JJ="$(cd "$(mktemp -d -t specto-conventions-jj.XXXXXX)" && pwd)"
mkdir -p "$JJ/.jj" "$JJ/pkg"
echo "jj repo rules" > "$JJ/AGENTS.md"
touch "$JJ/pkg/m.py"
out="$("$HELPER" "$JJ/pkg/m.py" 2>/dev/null)"
assert "jj-root" "stops at a .jj repo root" "$out" "$JJ/AGENTS.md"
rm -rf "$JJ"

# Bad usage: no args -> exit 2.
"$HELPER" >/dev/null 2>&1; rc=$?
assert "bad-usage" "exit code 2 (no path argument)" "$rc" "2"

echo
echo "Total: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
