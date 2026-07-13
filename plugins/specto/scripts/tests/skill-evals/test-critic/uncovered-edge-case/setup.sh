#!/usr/bin/env bash
# Plant an uncovered edge case for the test-critic guardian: a diff that adds a
# function with a null path, boundary limits, and an error path, but ships only a
# happy-path test. The linked spec §2 names the 1..100 bound and the
# required/error behaviour, so the uncovered cases are unambiguous. Offline: the
# diff is a raw text file (test-critic reads branch_diff + spec_path).
set -eu
SANDBOX="$1"
SPEC="$SANDBOX/docs/development/specs/2026-01-01-paging"
mkdir -p "$SPEC"

cat > "$SPEC/engineering-spec.md" <<'EOF'
# Engineering Specifications — page-size parsing

## 2. Technical approach

### 2.1. `parse_page_size`

Parses the requested page size from a raw query-string value.

- **Required:** a missing (None) value is an error — the caller must supply one.
- **Bounds:** the size must be between 1 and 100 inclusive; 0, negative, and
  values above 100 are rejected.
- **Type:** non-integer input is rejected.
EOF

cat > "$SANDBOX/branch_diff.txt" <<'EOF'
diff --git a/api/paging.py b/api/paging.py
new file mode 100644
index 0000000..1111111
--- /dev/null
+++ b/api/paging.py
@@ -0,0 +1,12 @@
+def parse_page_size(raw):
+    """Parse and validate the requested page size (spec §2.1)."""
+    if raw is None:
+        raise ValueError("page size is required")
+    n = int(raw)
+    if n < 1 or n > 100:
+        raise ValueError("page size must be between 1 and 100")
+    return n
diff --git a/api/tests/test_paging.py b/api/tests/test_paging.py
new file mode 100644
index 0000000..2222222
--- /dev/null
+++ b/api/tests/test_paging.py
@@ -0,0 +1,6 @@
+from api.paging import parse_page_size
+
+
+def test_parse_page_size_happy_path():
+    assert parse_page_size("20") == 20
EOF

echo "seeded $SPEC + branch_diff.txt"
