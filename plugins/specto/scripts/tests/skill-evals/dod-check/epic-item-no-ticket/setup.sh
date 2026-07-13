#!/usr/bin/env bash
# Plant an epic-creation DoD coverage gap for the dod guardian (mode=epic-creation)
# to catch. dod-check --mode=epic-creation reads TWO acli sources: the epic's
# Issue Checklist (source #1, via `acli jira workitem view <epic>`) and the epic's
# child tickets (via `acli jira workitem search --jql "parent = <epic>"`), then
# checks whether any child ticket references each checklist item. There is no
# --from-fixture for either read, so we stub `acli` on PATH ($sandbox/bin, which
# run-evals.sh prepends). The stub answers both subcommands:
#   - workitem search  -> two child tickets (TOY-2 insert endpoint, TOY-3 unit tests)
#   - workitem view    -> an epic whose Issue Checklist has "Write enablement docs"
#                         (referenced by NO child = the planted gap) and "Add unit
#                         tests" (referenced by TOY-3 = covered).
set -eu
SANDBOX="$1"
SPEC_REL="docs/development/specs/2026-01-01-canned-replies"
SPEC="$SANDBOX/$SPEC_REL"
mkdir -p "$SPEC" "$SANDBOX/.specto" "$SANDBOX/bin"

# --- spec folder + config ---------------------------------------------------------
printf 'epic: TOY-1\n' > "$SPEC/.specto-meta.yml"
printf 'jira_project_key: TOY\n' > "$SANDBOX/.specto/config.yml"
cat > "$SPEC/engineering-spec.md" <<'EOF'
# Engineering Specifications — one-click canned replies

## 2. Technical approach
The insert action reads the saved reply and populates the ticket reply box.
EOF

# --- acli stub: epic Issue Checklist + child-ticket search ------------------------
cat > "$SANDBOX/bin/acli" <<'STUB'
#!/usr/bin/env bash
# Offline acli stub for the epic-creation dod eval. Auth checks succeed. A
# workitem SEARCH returns the epic's two child tickets (neither mentions
# "enablement docs"). Any other workitem read returns the epic, whose Issue
# Checklist has an item ("Write enablement docs") that no child ticket covers —
# the planted coverage gap — plus one ("Add unit tests") that TOY-3 does cover.
# The search branch is tested BEFORE the default view payload.
case "$*" in
  *auth*)
    echo "✓ Logged in (stub)"; exit 0 ;;
  *search*)
    cat <<'JSON'
{
  "issues": [
    { "key": "TOY-2", "fields": { "summary": "Insert saved reply endpoint", "description": "Implement the one-click insert action that populates the ticket reply box." } },
    { "key": "TOY-3", "fields": { "summary": "Add unit tests for insert", "description": "Add unit tests for the changed code on the insert path." } }
  ]
}
JSON
    exit 0 ;;
  *workitem*view*) : ;;   # expected: fall through to the epic payload below
  *)               echo "STUB-FORBIDDEN: unexpected acli call: acli $*" >&2; exit 97 ;;
esac
cat <<'JSON'
{
  "key": "TOY-1",
  "fields": {
    "summary": "Epic — one-click canned replies",
    "customfield_10107": "Issue Checklist:\n- [ ] Write enablement docs under docs/\n- [x] Add unit tests for the changed code",
    "description": {"type":"doc","version":1,"content":[{"type":"paragraph","content":[{"type":"text","text":"Epic body."}]}]}
  }
}
JSON
exit 0
STUB
chmod +x "$SANDBOX/bin/acli"

echo "seeded $SPEC_REL + .specto/config.yml + acli stub (epic checklist + child search)"
