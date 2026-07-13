#!/usr/bin/env bash
# Plant two known defects for the code-mr-review guardian to catch, anchored in a
# spec + ticket AC:
#   1. spec adherence — engineering-spec.md §2.3 fixes the storage as a JSON
#      `feature_flags` entry on the existing team_settings row ("no new table or
#      column"); the branch_diff adds a brand-new column, a fixed-decision divergence.
#   2. AC coverage — ticket TOY-2 has two AC lines; the diff implements the first
#      (one-click insert) but omits the second (disable the action on a closed ticket).
# Offline: the diff is a raw text file (no live branch), and the AC is read via
# get-ticket-description.sh --from-fixture ac.json.
set -eu
SANDBOX="$1"
SPEC="$SANDBOX/docs/development/specs/2026-01-01-canned-replies"
mkdir -p "$SPEC"

cat > "$SPEC/engineering-spec.md" <<'EOF'
# Engineering Specifications — one-click canned replies

## 2. Technical approach

### 2.3. Storage model

**Decision (V1):** the canned-reply feature flags live on the existing
`team_settings` row as entries in its `feature_flags` JSON column
(`FeatureFlag("canned_replies_enabled")`). **No new table or column is added** —
the team-settings record already carries every per-team toggle, and the
customers/AGENTS.md convention is that new per-team flags go in `feature_flags`,
not a bespoke column.
EOF

cat > "$SANDBOX/branch_diff.txt" <<'EOF'
diff --git a/migrations/0007_canned_replies.py b/migrations/0007_canned_replies.py
new file mode 100644
index 0000000..1111111
--- /dev/null
+++ b/migrations/0007_canned_replies.py
@@ -0,0 +1,9 @@
+from django.db import migrations, models
+
+
+class Migration(migrations.Migration):
+    operations = [
+        migrations.AddField(
+            model_name="teamsettings",
+            name="canned_replies_enabled",
+            field=models.BooleanField(default=False),
+        ),
+    ]
diff --git a/console/replies.py b/console/replies.py
new file mode 100644
index 0000000..2222222
--- /dev/null
+++ b/console/replies.py
@@ -0,0 +1,12 @@
+def insert_saved_reply(ticket, reply_id, store):
+    """Insert the saved reply's text into the ticket's reply box (AC1)."""
+    reply = store.get_reply(reply_id)
+    ticket.reply_box = reply.text
+    return ticket.reply_box
diff --git a/console/tests/test_replies.py b/console/tests/test_replies.py
new file mode 100644
index 0000000..3333333
--- /dev/null
+++ b/console/tests/test_replies.py
@@ -0,0 +1,10 @@
+from console.replies import insert_saved_reply
+
+
+def test_insert_populates_reply_box(fake_ticket, fake_store):
+    out = insert_saved_reply(fake_ticket, 1, fake_store)
+    assert out == fake_store.get_reply(1).text
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

echo "seeded $SPEC + branch_diff.txt + ac.json"
