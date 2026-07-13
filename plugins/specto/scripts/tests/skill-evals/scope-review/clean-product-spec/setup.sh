#!/usr/bin/env bash
# Negative control for scope-review: a well-formed product spec with NO scope
# violations — every Won't-have has a concrete Reason, MoSCoW buckets are
# consistent, and §3 lists endpoint/export NAMES only (no schema, no request/
# response tables, no DDL). A guardian that flags this is producing false
# positives. Pure-local; scope-review only reads the file.
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

### 2.2 Should-have
- As an agent, I see the five replies I use most at the top of the list.

### 2.3 Won't-have (this version)

| Feature | Reason |
|---|---|
| Authoring / editing saved replies | Owned by the admin-console team under their existing settings-surface roadmap. |
| Sharing reply sets across teams | Requires a cross-team permission model that does not exist yet; blocked on that design. |

## 3. Interface

### 3.1 Screens
The reply box gains an "Insert saved reply" button that opens the saved-reply list.

### 3.2 Endpoints
- **Insert saved reply** — inserts the chosen reply into the current ticket's reply box.
- **List saved replies** — returns the agent's available saved replies, most-used first.

### 3.3 Exports
_None in this version._
EOF

echo "seeded $SPEC"
