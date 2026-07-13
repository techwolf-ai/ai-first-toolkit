#!/usr/bin/env bash
# Test harness for the plugin-config.sh helper. Uses a temporary CLAUDE_PLUGIN_DATA
# directory so the live config in ~/.claude/plugin-data/specto/ stays untouched.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/.."

# Shared assertion helpers + PASS/FAIL counters.
source "$HERE/lib/assert.sh"

# Sandbox: every invocation reads/writes a fresh temp dir.
export CLAUDE_PLUGIN_DATA="$(mktemp -d -t specto-config-test.XXXXXX)"
trap 'rm -rf "$CLAUDE_PLUGIN_DATA"' EXIT
HELPER="$DIR/plugin-config.sh"

echo "== plugin-config.sh =="

# `get` on an unset key fails with exit 1 and no stdout.
out="$("$HELPER" get jira_project 2>/dev/null)"; rc=$?
assert "get-unset"  "exit code 1" "$rc" "1"
assert "get-unset"  "no stdout" "$out" ""

# `has` on an unset key returns 1.
"$HELPER" has jira_project >/dev/null 2>&1; rc=$?
assert "has-unset"  "exit code 1" "$rc" "1"

# `set` then `get` round-trips.
"$HELPER" set jira_project APP >/dev/null 2>&1; rc=$?
assert "set-fresh"  "exit code 0" "$rc" "0"
out="$("$HELPER" get jira_project 2>/dev/null)"
assert "get-after-set" "round-trips" "$out" "APP"

# `has` after set returns 0.
"$HELPER" has jira_project >/dev/null 2>&1; rc=$?
assert "has-after-set" "exit code 0" "$rc" "0"

# `set` overwrites instead of duplicating.
"$HELPER" set jira_project PROJ >/dev/null 2>&1
out="$("$HELPER" get jira_project)"
assert "set-overwrite" "newest value wins" "$out" "PROJ"
lines="$(grep -c '^jira_project=' "$CLAUDE_PLUGIN_DATA/config.env" 2>/dev/null || echo 0)"
assert "set-overwrite" "stored on a single line" "$lines" "1"

# `set` a second key, then `list` returns both keys (sorted is not guaranteed —
# we just check both rows exist).
"$HELPER" set jira_board_id 209 >/dev/null 2>&1
out="$("$HELPER" list)"
assert "list-keys" "first key present"  "$(printf '%s\n' "$out" | grep -c '^jira_project=PROJ$')"   "1"
assert "list-keys" "second key present" "$(printf '%s\n' "$out" | grep -c '^jira_board_id=209$')" "1"

# `set` with a value containing spaces and equals signs survives round-trip
# (we don't quote on disk — but the value-after-first-= is preserved).
"$HELPER" set fancy "value=with spaces and = signs" >/dev/null 2>&1
out="$("$HELPER" get fancy)"
assert "set-funky-value" "value preserved verbatim" "$out" "value=with spaces and = signs"

# Regex metacharacters in keys MUST NOT cross-match other keys. Previous grep
# implementation matched `^${KEY}=` literally, so keys like `foo.bar` would
# also match `fooXbar`. Awk field comparison fixes it.
"$HELPER" set 'foo.bar' literal-dot-key >/dev/null 2>&1
"$HELPER" set 'fooXbar' literal-x-key   >/dev/null 2>&1
assert "regex-meta-isolation" "dotted key returns its own value (not the X-key's)" \
  "$("$HELPER" get 'foo.bar')" "literal-dot-key"
assert "regex-meta-isolation" "x-key returns its own value (not the dotted key's)" \
  "$("$HELPER" get 'fooXbar')" "literal-x-key"
# Deleting one of these must not remove the other.
"$HELPER" delete 'foo.bar' >/dev/null 2>&1
"$HELPER" has 'foo.bar' >/dev/null 2>&1; rc=$?
assert "regex-meta-isolation" "dotted key gone after delete" "$rc" "1"
"$HELPER" has 'fooXbar' >/dev/null 2>&1; rc=$?
assert "regex-meta-isolation" "x-key still present after deleting dotted key" "$rc" "0"
# Bracket / star / caret metacharacters are equally safe.
"$HELPER" set 'a[1]' bracket-val >/dev/null 2>&1
"$HELPER" set 'a.1'  dot-val    >/dev/null 2>&1
assert "regex-meta-isolation" "bracket key isolates from dot key" \
  "$("$HELPER" get 'a[1]')" "bracket-val"
assert "regex-meta-isolation" "dot key isolates from bracket key" \
  "$("$HELPER" get 'a.1')"  "dot-val"

# `delete` removes the key.
"$HELPER" delete jira_project >/dev/null 2>&1; rc=$?
assert "delete-existing" "exit code 0" "$rc" "0"
"$HELPER" has jira_project >/dev/null 2>&1; rc=$?
assert "delete-then-has" "exit code 1 (key gone)" "$rc" "1"

# `delete` is a no-op for a missing key.
"$HELPER" delete neverset >/dev/null 2>&1; rc=$?
assert "delete-missing" "exit code 0 (idempotent)" "$rc" "0"

# Bad usage.
"$HELPER" >/dev/null 2>&1; rc=$?
assert "bad-no-action" "exit code 2" "$rc" "2"
"$HELPER" get >/dev/null 2>&1; rc=$?
assert "bad-get-no-key" "exit code 2" "$rc" "2"
"$HELPER" set foo >/dev/null 2>&1; rc=$?
assert "bad-set-no-value" "exit code 2" "$rc" "2"
"$HELPER" unknown_action foo >/dev/null 2>&1; rc=$?
assert "bad-unknown-action" "exit code 2" "$rc" "2"

# --------------------------------------------------------------------------------
# doctor.sh --config-only  (preflight: fail loud on missing Jira config)
# --------------------------------------------------------------------------------
echo
echo "== doctor.sh --config-only =="
DOCTOR="$DIR/doctor.sh"
# Start from a clean config: neither Jira key set -> required checks FAIL loudly.
"$HELPER" delete jira_project  >/dev/null 2>&1
"$HELPER" delete jira_board_id >/dev/null 2>&1
out="$("$DOCTOR" --config-only 2>&1)"; rc=$?
assert "doctor-missing" "exit 1 when required config is missing" "$rc" "1"
assert "doctor-missing" "names the missing project key" "$(printf '%s\n' "$out" | grep -c 'Jira project key not set')" "1"
assert "doctor-missing" "names the missing board id"    "$(printf '%s\n' "$out" | grep -c 'Jira board id .* not set')" "1"
assert "doctor-missing" "prints a fix hint"             "$(printf '%s\n' "$out" | grep -c 'set jira_project')" "1"

# With both keys set -> all required config checks pass, exit 0.
"$HELPER" set jira_project APP >/dev/null 2>&1
"$HELPER" set jira_board_id 209 >/dev/null 2>&1
out="$("$DOCTOR" --config-only 2>&1)"; rc=$?
assert "doctor-present" "exit 0 when required config present" "$rc" "0"
assert "doctor-present" "reports the configured project" "$(printf '%s\n' "$out" | grep -c 'Jira project key = APP')" "1"

# Bad usage.
"$DOCTOR" --nonsense >/dev/null 2>&1; rc=$?
assert "doctor-bad-usage" "exit 2 on unknown flag" "$rc" "2"

echo
echo "Total: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
