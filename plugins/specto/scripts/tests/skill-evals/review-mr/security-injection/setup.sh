#!/usr/bin/env bash
# Plant one known defect for the code-mr-review guardian's SECURITY axis: the diff
# builds a SQL query by f-string interpolation of a caller-supplied id
# (`f"SELECT … WHERE id = {reply_id}"`) on a changed path — a textbook SQL
# injection. The spec §2.6 fixes the endpoint contract and ticket TOY-2's AC is
# fully satisfied by the diff, so the salient finding is the injection, not spec
# adherence or AC coverage. Offline: the diff is a raw text file and the AC is
# read via get-ticket-description.sh --from-fixture ac.json.
set -eu
SANDBOX="$1"
SPEC="$SANDBOX/docs/development/specs/2026-01-01-canned-replies"
mkdir -p "$SPEC"

cat > "$SPEC/engineering-spec.md" <<'EOF'
# Engineering Specifications — one-click canned replies

## 2. Technical approach

### 2.6. Endpoint contracts

**Insert saved reply** — `POST /tickets/{id}/insert-reply`, body `{reply_id:int}`,
returns `{text:str}`. Looks up the saved reply by id and returns its text for the
console to insert. Errors: 404 unknown reply, 409 ticket closed.
EOF

cat > "$SANDBOX/branch_diff.txt" <<'EOF'
diff --git a/console/replies.py b/console/replies.py
new file mode 100644
index 0000000..2222222
--- /dev/null
+++ b/console/replies.py
@@ -0,0 +1,14 @@
+def get_reply_text(cur, reply_id):
+    """Return the saved reply's text for the given id (AC1)."""
+    cur.execute(f"SELECT text FROM saved_replies WHERE id = {reply_id}")
+    row = cur.fetchone()
+    if row is None:
+        raise NotFound("unknown reply")
+    return row[0]
+
+
+def insert_saved_reply(ticket, reply_id, cur):
+    if ticket.is_closed:
+        raise Conflict("ticket closed")
+    ticket.reply_box = get_reply_text(cur, reply_id)
+    return ticket.reply_box
diff --git a/console/tests/test_replies.py b/console/tests/test_replies.py
new file mode 100644
index 0000000..3333333
--- /dev/null
+++ b/console/tests/test_replies.py
@@ -0,0 +1,14 @@
+from console.replies import insert_saved_reply
+
+
+def test_insert_populates_reply_box(fake_ticket, fake_cursor):
+    out = insert_saved_reply(fake_ticket, 1, fake_cursor)
+    assert out == "hello"
+
+
+def test_insert_blocked_on_closed_ticket(closed_ticket, fake_cursor):
+    with pytest.raises(Conflict):
+        insert_saved_reply(closed_ticket, 1, fake_cursor)
EOF

cat > "$SANDBOX/ac.json" <<'EOF'
{
  "key": "TOY-2",
  "fields": {
    "summary": "One-click insert saved reply",
    "description": {
      "type": "doc",
      "version": 1,
      "content": [
        { "type": "heading", "attrs": { "level": 2 },
          "content": [ { "type": "text", "text": "Acceptance criteria" } ] },
        { "type": "bulletList", "content": [
          { "type": "listItem", "content": [ { "type": "paragraph",
            "content": [ { "type": "text", "text": "Inserting a saved reply populates the current ticket reply box in one click." } ] } ] },
          { "type": "listItem", "content": [ { "type": "paragraph",
            "content": [ { "type": "text", "text": "The insert action is disabled when the ticket is already closed." } ] } ] }
        ] }
      ]
    }
  }
}
EOF

echo "seeded $SPEC + branch_diff.txt (SQL injection) + ac.json"
