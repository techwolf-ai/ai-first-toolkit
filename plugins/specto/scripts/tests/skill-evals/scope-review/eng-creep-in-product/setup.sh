#!/usr/bin/env bash
# Plant TWO known scope defects in a product spec so the scope-review guardian
# has something concrete to catch:
#   1. a Won't-have row with an EMPTY Reason column (wonthave-no-reason);
#   2. engineering creep in a product spec — a `### Storage model` with DDL and a
#      §3.2 endpoint request/response table, both of which belong in the
#      engineering spec, not the product spec.
# Pure-local: scope-review only reads the file. No network, no mocks.
set -eu
SANDBOX="$1"
SPEC="$SANDBOX/docs/development/specs/2026-01-01-canned-replies"
mkdir -p "$SPEC"

cat > "$SPEC/product-spec.md" <<'EOF'
# Product Specification — one-click canned replies

## 1. The value case

### 1.1 Problem
Support agents retype the same macro replies dozens of times a day, costing
handle time and introducing typos.

### 1.2 Who it is for
Front-line support agents working in the agent console.

### 1.3 Value
One click to insert a saved reply cuts keystrokes and standardises wording.

## 2. User stories & scope

### 2.1 Must-have
- As an agent, I can insert a saved reply into the current ticket in one click.

### 2.2 Won't-have (this version)

| Feature | Reason |
|---|---|
| Authoring / editing saved replies | Owned by the admin-console team under their existing settings-surface roadmap. |
| Sharing reply sets across teams |  |

## 3. Interface

### 3.1 Screens
The reply box gains an "Insert saved reply" button.

### 3.2 Endpoints

| Endpoint | Method | Path params | Request body | Response | Errors |
|---|---|---|---|---|---|
| Insert reply | POST | `ticket_id` | `{ "reply_id": int }` | `{ "text": str }` | 404 unknown reply, 409 ticket closed |

### 3.3 Storage model

The saved replies live in a new table:

```sql
CREATE TABLE canned_replies (
  id SERIAL PRIMARY KEY,
  team_id INT NOT NULL,
  body TEXT NOT NULL
);
```
EOF

echo "seeded $SPEC"
