#!/usr/bin/env bash
# Lane-discipline negative control for product-review (regression-guards the found
# lane-leak — a reviewer straying into a neighbour's lane). The spec is CLEAN on
# every product-review axis (≤5 metrics, Won't-haves have concrete Reasons,
# §3.2/§3.3 names only, no AI prose, no unexplained codename) but carries a pure
# V1/V2 scope-bucket blur: the Must-have "insert a saved reply in one click" ALSO
# appears as a Won't-have row (with a reason). That MoSCoW contradiction is
# scope-review's lane, NOT product-review's — product-review must stay silent.
# Pure-local: product-review only reads the file.
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

### 1.2 Solution
One click to insert a saved reply into the current ticket, cutting keystrokes and
standardising wording.

### 1.3 Objectives

| # | Objective | Customer / segment | OKR |
|---|---|---|---|
| 1 | Cut keystrokes per reply so agents resolve tickets faster | Pilot support teams | O1.KR1 |

### 1.4 Key results / metrics

| Metric | Threshold | Why this matters |
|---|---|---|
| Median keystrokes per reply | ≥ 40% reduction | Direct measure of the effort saved. |
| Inserts per agent per day | ≥ 20 within 30 days | Shows the feature is actually used. |

## 2. User stories & scope

### 2.1 Must-have
- As an agent, I can insert a saved reply into the current ticket in one click.

### 2.2 Should-have
- As an agent, I see the five replies I use most at the top of the list.

### 2.3 Won't-have (this version)

| Feature | Reason |
|---|---|
| As an agent, I can insert a saved reply into the current ticket in one click | Deferred to V2 pending the reply-permissions design. |
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

echo "seeded $SPEC (product-clean spec; Must item also in Won't-have — scope-review's lane)"
