#!/usr/bin/env bash
# Negative control for code-mr-review, guidelines principle 9 (respect granted
# freedom). Spec §2.4 marks the reply cache an `*Implementer's choice — must
# satisfy:*` harness with three VERIFIABLE criteria. The diff picks a valid but
# DIFFERENT implementation (an in-memory LRU keyed by reply id, invalidated on
# edit, no new table) that MEETS every criterion, with a test asserting them. The
# diff is otherwise clean (AC covered, no injection). code-mr-review must VERIFY
# the criteria and NOT litigate the implementation choice — a spec-adherence
# finding here would be a false positive. Offline: raw diff + --from-fixture AC.
set -eu
SANDBOX="$1"
SPEC="$SANDBOX/docs/development/specs/2026-01-01-canned-replies"
mkdir -p "$SPEC"

cat > "$SPEC/engineering-spec.md" <<'EOF'
# Engineering Specifications — one-click canned replies

## 2. Technical approach

### 2.4. Reply-text caching

*Implementer's choice — must satisfy:* the reply-text cache is under-determined;
any implementation is acceptable provided it satisfies all of:

- (a) returns the correct saved-reply text for a given reply id;
- (b) is invalidated when a saved reply is edited (a subsequent read returns the
  new text, never a stale value);
- (c) adds no new database table or column (caching is in-process only).
EOF

cat > "$SANDBOX/branch_diff.txt" <<'EOF'
diff --git a/console/reply_cache.py b/console/reply_cache.py
new file mode 100644
index 0000000..2222222
--- /dev/null
+++ b/console/reply_cache.py
@@ -0,0 +1,26 @@
+from functools import lru_cache
+
+
+class ReplyCache:
+    """In-process LRU cache of saved-reply text, keyed by reply id.
+
+    Implementer's choice per spec §2.4: in-memory only (criterion c — no new
+    table/column), correct-by-id (criterion a), invalidated on edit (criterion b).
+    """
+
+    def __init__(self, store, maxsize=512):
+        self._store = store
+        self._get = lru_cache(maxsize=maxsize)(self._load)
+
+    def _load(self, reply_id):
+        return self._store.get_reply(reply_id).text
+
+    def get_text(self, reply_id):
+        return self._get(reply_id)
+
+    def invalidate(self, reply_id):
+        # Called by the reply-edit path so a later read returns fresh text.
+        self._get.cache_clear()
diff --git a/console/tests/test_reply_cache.py b/console/tests/test_reply_cache.py
new file mode 100644
index 0000000..3333333
--- /dev/null
+++ b/console/tests/test_reply_cache.py
@@ -0,0 +1,18 @@
+from console.reply_cache import ReplyCache
+
+
+def test_returns_correct_text_by_id(fake_store):
+    cache = ReplyCache(fake_store)
+    assert cache.get_text(1) == fake_store.get_reply(1).text
+
+
+def test_invalidated_on_edit(fake_store):
+    cache = ReplyCache(fake_store)
+    assert cache.get_text(1) == "hello"
+    fake_store.edit_reply(1, "goodbye")
+    cache.invalidate(1)
+    assert cache.get_text(1) == "goodbye"
EOF

cat > "$SANDBOX/ac.json" <<'EOF'
{
  "key": "TOY-2",
  "fields": {
    "summary": "Cache saved-reply text",
    "description": {
      "type": "doc",
      "version": 1,
      "content": [
        { "type": "heading", "attrs": { "level": 2 },
          "content": [ { "type": "text", "text": "Acceptance criteria" } ] },
        { "type": "bulletList", "content": [
          { "type": "listItem", "content": [ { "type": "paragraph",
            "content": [ { "type": "text", "text": "Reading a saved reply returns the correct text for its id." } ] } ] },
          { "type": "listItem", "content": [ { "type": "paragraph",
            "content": [ { "type": "text", "text": "After a saved reply is edited, a subsequent read returns the updated text, not a stale value." } ] } ] }
        ] }
      ]
    }
  }
}
EOF

echo "seeded $SPEC (implementer's-choice §2.4) + branch_diff.txt (valid alt impl) + ac.json"
