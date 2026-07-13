#!/usr/bin/env bash
# Plant a DoD gap for the dod guardian to catch. dod's canonical source #1 is the
# epic Issue Checklist, which it reads via `acli` — there is no --from-fixture for
# it, so we stub `acli` on PATH ($sandbox/bin, which run-evals.sh prepends). The
# stub returns an epic whose Issue Checklist has an item the branch does NOT
# satisfy (enablement docs under docs/), alongside one it does (unit tests added).
#
# The sandbox is a real git repo with a feature branch one commit ahead of main so
# dod has a branch diff to check the checklist against. Git is configured locally
# with signing off + GIT_CONFIG_GLOBAL=/dev/null so commits don't hit the host's
# 1Password signing agent.
set -eu
SANDBOX="$1"
SPEC_REL="docs/development/specs/2026-01-01-canned-replies"
export GIT_CONFIG_GLOBAL=/dev/null
GIT="git -C $SANDBOX -c user.name=eval -c user.email=eval@example.com -c commit.gpgsign=false -c init.defaultBranch=main"

# --- acli stub: canned epic with an Issue Checklist -------------------------------
mkdir -p "$SANDBOX/bin"
cat > "$SANDBOX/bin/acli" <<'STUB'
#!/usr/bin/env bash
# Offline acli stub for the dod eval. Auth checks succeed; any workitem read
# returns a canned epic with an Issue Checklist custom field. Item 1 (unit tests)
# is satisfied by the branch; items 2 and 3 are NOT — that is the planted gap.
case "$*" in
  *auth*)          echo "✓ Logged in (stub)"; exit 0 ;;
  *search*)        echo '{"issues":[]}'; exit 0 ;;
  *workitem*view*) : ;;   # expected: fall through to the epic payload below
  *)               echo "STUB-FORBIDDEN: unexpected acli call: acli $*" >&2; exit 97 ;;
esac
cat <<'JSON'
{
  "key": "TOY-1",
  "fields": {
    "summary": "Epic — one-click canned replies",
    "customfield_10107": "Issue Checklist:\n- [x] Unit tests added for the changed code\n- [ ] Enablement docs written under docs/\n- [ ] Rollback / downgrade path documented in the engineering spec",
    "description": {"type":"doc","version":1,"content":[{"type":"paragraph","content":[{"type":"text","text":"Epic body."}]}]}
  }
}
JSON
exit 0
STUB
chmod +x "$SANDBOX/bin/acli"

# --- git repo: base commit on main --------------------------------------------
$GIT init -q
mkdir -p "$SANDBOX/$SPEC_REL" "$SANDBOX/.specto"
printf 'epic: TOY-1\n' > "$SANDBOX/$SPEC_REL/.specto-meta.yml"
printf 'jira_project_key: TOY\n' > "$SANDBOX/.specto/config.yml"
cat > "$SANDBOX/$SPEC_REL/engineering-spec.md" <<'EOF'
# Engineering Specifications — one-click canned replies

## 2. Technical approach
The insert action reads the saved reply and populates the ticket reply box.
EOF
$GIT add -A
$GIT commit -qm "base: spec + config on main"

# --- feature branch: one commit ahead (code + a happy-path test, NO docs) -----
$GIT checkout -q -b f-canned-replies
mkdir -p "$SANDBOX/console/tests"
cat > "$SANDBOX/console/replies.py" <<'EOF'
def insert_saved_reply(ticket, reply):
    ticket.reply_box = reply.text
    return ticket.reply_box
EOF
cat > "$SANDBOX/console/tests/test_replies.py" <<'EOF'
from console.replies import insert_saved_reply


def test_insert_populates_reply_box(fake_ticket, fake_reply):
    assert insert_saved_reply(fake_ticket, fake_reply) == fake_reply.text
EOF
$GIT add -A
$GIT commit -qm "feat: insert_saved_reply + happy-path test"

echo "seeded git sandbox ($SPEC_REL) + acli stub"
