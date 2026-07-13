#!/usr/bin/env bash
# Negative control for test-critic: the SAME function as uncovered-edge-case, but
# the diff now ships tests for every edge case the spec §2.1 names — the None
# error path, both boundary rejections, and non-integer input. A guardian that
# still reports an in-scope ✗ here is producing a false positive. Offline.
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
@@ -0,0 +1,40 @@
+import pytest
+
+from api.paging import parse_page_size
+
+
+def test_parse_page_size_happy_path():
+    assert parse_page_size("20") == 20
+
+
+def test_none_is_required_error():
+    with pytest.raises(ValueError):
+        parse_page_size(None)
+
+
+def test_non_integer_rejected():
+    with pytest.raises(ValueError):
+        parse_page_size("abc")
+
+
+def test_negative_rejected():
+    with pytest.raises(ValueError):
+        parse_page_size("-5")
+
+
+def test_zero_below_lower_bound_rejected():
+    with pytest.raises(ValueError):
+        parse_page_size("0")
+
+
+def test_lower_boundary_one_accepted():
+    assert parse_page_size("1") == 1
+
+
+def test_upper_boundary_hundred_accepted():
+    assert parse_page_size("100") == 100
+
+
+def test_above_upper_bound_rejected():
+    with pytest.raises(ValueError):
+        parse_page_size("101")
EOF

echo "seeded $SPEC + branch_diff.txt"
