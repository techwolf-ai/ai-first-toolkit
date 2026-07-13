#!/usr/bin/env bash
# Seed a spec MR's unresolved review threads for the resolve-spec-comments
# workflow guardian to cluster + classify. The threads are read offline via
# `mr-fetch.sh discussions --from-fixture ./mrfix` (reads ./mrfix/discussions.json);
# they are of three different kinds so clustering has to route each into one of the
# 7 buckets: a style-nit (formatting), a decision-request (needs PM sign-off), and
# a bug (factual error in the spec). A permissive `glab` stub on $sandbox/bin
# satisfies the skill's "an open spec MR exists" prerequisite without a live call.
# The skill is advisory-only: it must produce a revision plan, not resolve threads
# or edit the spec.
set -eu
SANDBOX="$1"
SPEC_REL="docs/development/specs/2026-01-01-canned-replies"
SPEC="$SANDBOX/$SPEC_REL"
mkdir -p "$SPEC" "$SANDBOX/mrfix" "$SANDBOX/bin"

# --- the spec under review (headers so line -> section mapping works) --------------
cat > "$SPEC/product-spec.md" <<'EOF'
# Product Specification — one-click canned replies

## 1. The value case

### 1.1 Problem
Support agents retype the same macro replies dozens of times a day.

### 1.4 Key results / metrics

| Metric | Threshold | Why |
|---|---|---|
| Distinct tenants using canned replies within 30 days | ≥ 6 | Adoption signal. |

## 2. User stories & scope

### 2.1 Must-have
- As an agent, I can insert a saved reply into the current ticket in one click.

## 3. Interface

### 3.1 Screens
The reply box gains an "Insert saved reply" button.
EOF

# --- unresolved discussion threads (three distinct kinds) --------------------------
cat > "$SANDBOX/mrfix/discussions.json" <<'JSON'
[
  {
    "id": "a1b2c3",
    "notes": [
      {
        "id": 101,
        "body": "Nit: use an em-dash here, not a double hyphen — house style. Same on the next line.",
        "author": { "username": "reviewer_a" },
        "resolved": false,
        "position": { "new_path": "docs/development/specs/2026-01-01-canned-replies/product-spec.md", "new_line": 6 }
      }
    ]
  },
  {
    "id": "d4e5f6",
    "notes": [
      {
        "id": 102,
        "body": "The adoption threshold of 6 tenants in §1.4 needs PM sign-off before we commit to it — can @pm confirm the target?",
        "author": { "username": "reviewer_b" },
        "resolved": false,
        "position": { "new_path": "docs/development/specs/2026-01-01-canned-replies/product-spec.md", "new_line": 13 }
      }
    ]
  },
  {
    "id": "g7h8i9",
    "notes": [
      {
        "id": 103,
        "body": "This is factually wrong: the saved reply is inserted into the ticket reply box, not the macro panel. Fix the statement.",
        "author": { "username": "reviewer_c" },
        "resolved": false,
        "position": { "new_path": "docs/development/specs/2026-01-01-canned-replies/product-spec.md", "new_line": 25 }
      }
    ]
  }
]
JSON

# --- glab stub: satisfy the "open spec MR exists" prerequisite offline ------------
cat > "$SANDBOX/bin/glab" <<'STUB'
#!/usr/bin/env bash
# Offline glab stub for resolve-spec-comments' prerequisite check. `mr view`
# returns a minimal open MR whose source branch is the current one; other mr
# subcommands return an empty array. The actual thread read goes through
# mr-fetch.sh --from-fixture, not this stub.
# Allow-fence (offline contract): tolerate any mr-family call, but a NON-mr glab
# call (e.g. an ad-hoc `glab api`) fails loudly rather than silently returning [].
case "$*" in
  *mr*view*|*mr*list*)
    echo '{"iid":7,"web_url":"https://example.test/mr/7","source_branch":"f-canned-replies","title":"canned replies spec","state":"opened"}'
    exit 0 ;;
  *mr*)
    echo '[]'; exit 0 ;;
  *)
    echo "STUB-FORBIDDEN: unexpected glab call: glab $*" >&2; exit 97 ;;
esac
STUB
chmod +x "$SANDBOX/bin/glab"

echo "seeded $SPEC_REL + mrfix/discussions.json (3 unresolved threads) + glab stub"
