#!/usr/bin/env bash
# Cross-backend contract-conformance suite for the tracker dispatcher verbs.
#
# Every case runs the SAME verb through the dispatcher shim
# (scripts/tracker/<verb>.sh) once per backend, pinned via
# SPECTO_BACKEND_OVERRIDE_TRACKER, and asserts the normalized stdout contract
# (docs/adapter-contract.md) against ONE shared expected value. Ticket keys are
# opaque tokens, so where the key itself would leak into the output the
# assertion is a shape check (bare token / URL) shared across backends.
#
# Fixture resolution per case+backend: a case fixture at
# tests/fixtures/<case>/<backend>.json wins when present; otherwise the backend
# suite's own fixture (scripts/tracker/<backend>/tests/fixtures/<name>) is
# reused. Fully offline: fixture mode, JIRA_SITE env, or a mocked gh binary.
#
# Adding a tracker backend = adding it to BACKENDS plus fixtures; the expected
# strings below must never fork per backend.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"      # scripts/tracker/tests
TRACKER="$(cd "$HERE/.." && pwd)"          # scripts/tracker (dispatcher shims)
FIX="$HERE/fixtures"

# Shared assertion helpers + PASS/FAIL counters.
source "$HERE/../../tests/lib/assert.sh"

BACKENDS=(jira github linear)

# tfix <case> <backend> <backend-fixture-name>: case fixture file if present,
# else the backend suite's own fixture file.
tfix() {
  if [[ -f "$FIX/$1/$2.json" ]]; then echo "$FIX/$1/$2.json"; else echo "$TRACKER/$2/tests/fixtures/$3"; fi
}

# run_t <backend> <verb> [args…]: dispatcher invocation with the backend pinned.
run_t() {
  local b="$1" verb="$2"; shift 2
  SPECTO_BACKEND_OVERRIDE_TRACKER="$b" bash "$TRACKER/$verb.sh" "$@"
}

# Shape helpers (shared expected: "ok").
one_line_url() {  # $1=key $2=output: exactly one https URL line containing the key
  local lines; lines="$(printf '%s\n' "$2" | wc -l | tr -d ' ')"
  if [[ "$lines" == "1" && "$2" == https://*"$1"* ]]; then echo ok; else echo bad; fi
}
key_token() {     # $1=output: one bare ticket-key token, nothing else
  if [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]]; then echo ok; else echo bad; fi
}

# --------------------------------------------------------------------------------
# list-children.sh: normalized [{key, summary, status, type}] on every backend
# --------------------------------------------------------------------------------
echo "== list-children.sh: normalized-shape parity =="
children_fixture() { case "$1" in jira) echo children-bare.json ;; *) echo children.json ;; esac; }
EXPECTED_KEYS='[["key","status","summary","type"]]'
for b in "${BACKENDS[@]}"; do
  out="$(run_t "$b" list-children EPIC-1 --from-fixture "$(tfix list-children "$b" "$(children_fixture "$b")")" 2>/dev/null)"; rc=$?
  assert "children[$b]" "exit code 0" "$rc" "0"
  assert "children[$b]" "non-empty array" "$(printf '%s' "$out" | jq 'length > 0' 2>/dev/null)" "true"
  assert "children[$b]" "every entry carries exactly the 4 contract keys" \
    "$(printf '%s' "$out" | jq -c '[.[]|keys]|unique' 2>/dev/null)" "$EXPECTED_KEYS"
done

# --------------------------------------------------------------------------------
# get-ticket-status.sh: bare status string (one shared value across backends)
# --------------------------------------------------------------------------------
echo
echo "== get-ticket-status.sh: bare-status parity =="
# jira/linear reuse their own ticket-status.json ("In Progress"); github has a
# case fixture (open + status:in_progress label) so all three print one value.
EXPECTED_STATUS="In Progress"
for b in "${BACKENDS[@]}"; do
  out="$(run_t "$b" get-ticket-status KEY-1 --from-fixture "$(tfix ticket-status "$b" ticket-status.json)" 2>/dev/null)"; rc=$?
  assert "status[$b]" "exit code 0" "$rc" "0"
  assert "status[$b]" "bare status string" "$out" "$EXPECTED_STATUS"
done

# --------------------------------------------------------------------------------
# get-ticket-summary.sh: bare title string (one shared value across backends)
# --------------------------------------------------------------------------------
echo
echo "== get-ticket-summary.sh: bare-title parity =="
summary_fixture() { case "$1" in jira) echo ticket-adf.json ;; *) echo ticket-summary.json ;; esac; }
EXPECTED_SUMMARY="Add confidence scoring to skill timeline"
for b in "${BACKENDS[@]}"; do
  out="$(run_t "$b" get-ticket-summary KEY-1 --from-fixture "$(tfix ticket-summary "$b" "$(summary_fixture "$b")")" 2>/dev/null)"; rc=$?
  assert "summary[$b]" "exit code 0" "$rc" "0"
  assert "summary[$b]" "bare title string" "$out" "$EXPECTED_SUMMARY"
done

# --------------------------------------------------------------------------------
# ticket-url.sh: exactly one https URL containing the (opaque) ticket key
# --------------------------------------------------------------------------------
echo
echo "== ticket-url.sh: URL-shape parity =="
# Offline source differs per backend (JIRA_SITE env / mocked gh / fixture); the
# shape assertion is shared.
MOCKBIN="$(mktemp -d)"
cat > "$MOCKBIN/gh" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "issue" && "${2:-}" == "view" ]]; then
  printf '{"url":"https://github.com/acme/widgets/issues/%s"}\n' "$3"
fi
exit 0
EOF
chmod +x "$MOCKBIN/gh"

out="$(JIRA_SITE=jira.example.com run_t jira ticket-url APP-1 2>/dev/null)"; rc=$?
assert "ticket-url[jira]" "exit code 0" "$rc" "0"
assert "ticket-url[jira]" "one https URL containing the key" "$(one_line_url APP-1 "$out")" "ok"

out="$(PATH="$MOCKBIN:$PATH" GH_REPO= run_t github ticket-url 123 2>/dev/null)"; rc=$?
assert "ticket-url[github]" "exit code 0" "$rc" "0"
assert "ticket-url[github]" "one https URL containing the key" "$(one_line_url 123 "$out")" "ok"

out="$(run_t linear ticket-url ENG-123 --from-fixture "$TRACKER/linear/tests/fixtures/url.json" 2>/dev/null)"; rc=$?
assert "ticket-url[linear]" "exit code 0" "$rc" "0"
assert "ticket-url[linear]" "one https URL containing the key" "$(one_line_url ENG-123 "$out")" "ok"
rm -rf "$MOCKBIN"

# --------------------------------------------------------------------------------
# create-ticket.sh: identical argv accepted everywhere, prints one bare key token
# --------------------------------------------------------------------------------
echo
echo "== create-ticket.sh: key-token parity =="
for b in "${BACKENDS[@]}"; do
  out="$(printf 'body text\n' | run_t "$b" create-ticket ENG - "Cross-backend summary" - \
         --from-fixture "$(tfix create-ticket "$b" create-ok.json)" 2>/dev/null)"; rc=$?
  assert "create[$b]" "exit code 0" "$rc" "0"
  assert "create[$b]" "stdout is one bare key token" "$(key_token "$out")" "ok"
done

# --------------------------------------------------------------------------------
# usage parity: wrong-arg-count exits 2 on every backend (before any I/O)
# --------------------------------------------------------------------------------
echo
echo "== usage parity: wrong-arg-count exits 2 =="
for b in "${BACKENDS[@]}"; do
  run_t "$b" transition-ticket KEY-1 >/dev/null 2>&1; rc=$?
  assert "usage-transition[$b]" "transition-ticket with 1 arg exits 2" "$rc" "2"
  run_t "$b" link-tickets blocks KEY-1 >/dev/null 2>&1; rc=$?
  assert "usage-link[$b]" "link-tickets with 2 args exits 2" "$rc" "2"
done

# --------------------------------------------------------------------------------
# exit-4 parity: unsupported capabilities are a uniform exit 4, never a silent 0
# --------------------------------------------------------------------------------
echo
echo "== exit-4 parity: unsupported capabilities =="
# Without --questions, every backend reports the classification feature as
# unconfigured with exit 0 (parity contract; questions come from the repo's
# compliance profile).
for be in jira github linear; do
  case "$be" in
    jira)   fx="$TRACKER/jira/tests/fixtures/epic-standard.json"; key=ABC-1 ;;
    github) fx="$TRACKER/github/tests/fixtures/epic-body.json"; key=100 ;;
    linear) fx="$TRACKER/linear/tests/fixtures/epic-description.json"; key=ENG-1 ;;
  esac
  out="$(run_t "$be" epic-fields "$key" --from-fixture "$fx" 2>/dev/null)"; rc=$?
  assert "unconfigured-epic-fields[$be]" "exit 0 without --questions" "$rc" "0"
  assert "unconfigured-epic-fields[$be]" "classification=unconfigured" "$(echo "$out" | grep '^classification=')" "classification=unconfigured"
done
run_t github link-tickets relates 100 200 \
  --from-fixture "$TRACKER/github/tests/fixtures/link-ok.json" >/dev/null 2>&1; rc=$?
assert "exit4-relates[github]" "relates link exits 4 (no native concept)" "$rc" "4"

assert_summary
