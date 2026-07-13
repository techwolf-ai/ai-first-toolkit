#!/usr/bin/env bash
# Plant a milestone coverage gap for verify-milestone to catch. Milestone M1
# promises two acceptance criteria: M1-AC1 (one-click insert) has a named covering
# test; M1-AC2 (disabled on a closed ticket) has NO covering test. The test suite
# itself PASSES (test_command = `true`), so the only reason the milestone verdict
# should be `fail` is the uncovered M1-AC2 — a green suite proves the tests pass,
# not that the right tests exist. See NOTES.md: this scenario runs a suite, so it
# is not a pure offline read like the prose guardians (the command is a trivial
# offline `true`).
set -eu
SANDBOX="$1"
SPEC_REL="docs/development/specs/2026-01-01-canned-replies"
SPEC="$SANDBOX/$SPEC_REL"
mkdir -p "$SPEC" "$SANDBOX/.specto" "$SANDBOX/tests"

printf 'epic: TOY-1\n' > "$SPEC/.specto-meta.yml"
# Trivial passing test command so the suite is green but coverage is the gate.
printf 'jira_project_key: TOY\ntest_command: "true"\n' > "$SANDBOX/.specto/config.yml"

cat > "$SPEC/product-spec.md" <<'EOF'
# Product Specification — one-click canned replies

## Milestone M1 — acceptance criteria

- **M1-AC1** — Inserting a saved reply populates the current ticket reply box in one click.
- **M1-AC2** — The insert action is disabled when the ticket is already closed.
EOF

# A test that covers M1-AC1 only. M1-AC2 has no covering test anywhere.
cat > "$SANDBOX/tests/test_m1.py" <<'EOF'
from console.replies import insert_saved_reply


def test_insert_populates_reply_box_one_click(fake_ticket, fake_store):
    # Covers M1-AC1: one-click insert populates the reply box.
    out = insert_saved_reply(fake_ticket, 1, fake_store)
    assert out == fake_store.get_reply(1).text
EOF

# The implementation (present so behaviour "looks" done — but AC2 still untested).
cat > "$SANDBOX/console_replies.py" <<'EOF'
def insert_saved_reply(ticket, reply_id, store):
    reply = store.get_reply(reply_id)
    ticket.reply_box = reply.text
    return ticket.reply_box
EOF

echo "seeded $SPEC_REL (M1-AC1 covered, M1-AC2 uncovered) + .specto/config.yml (test_command=true)"
