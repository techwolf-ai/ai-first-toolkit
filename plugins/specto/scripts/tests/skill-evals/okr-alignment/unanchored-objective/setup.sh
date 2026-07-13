#!/usr/bin/env bash
# Plant one known defect for okr-alignment-review: a §1.3 Objectives row claims to
# contribute to `O4.KR1`, but the team's OKR source (`.specto/okrs.md`) lists only
# O1.KR1 and O2.KR1 — so O4.KR1 does not exist. One other row DOES anchor
# (O1.KR1), making it a realistic mix. Pure-local: the agent reads the spec + the
# okrs_md_path passed in the prompt.
set -eu
SANDBOX="$1"
SPEC="$SANDBOX/docs/development/specs/2026-01-01-canned-replies"
mkdir -p "$SPEC" "$SANDBOX/.specto"

cat > "$SANDBOX/.specto/okrs.md" <<'EOF'
O1.KR1 — Cut median agent handle time by 15% across pilot teams.
O2.KR1 — Reach 60% weekly-active adoption of the agent console in pilot teams.
EOF

cat > "$SPEC/product-spec.md" <<'EOF'
# Product Specification — one-click canned replies

## 1. The value case

### 1.1 Problem
Support agents retype the same macro replies dozens of times a day, costing
handle time and introducing typos.

### 1.2 Who it is for
Front-line support agents working in the agent console.

### 1.3 Objectives

| # | Objective | Customer / segment | OKR |
|---|---|---|---|
| 1 | Cut keystrokes per reply so agents resolve tickets faster | Pilot support teams | O1.KR1 |
| 2 | Standardise reply wording to lift answer quality | Pilot support teams | O4.KR1 |

### 1.4 Key results / metrics

| Metric | Threshold |
|---|---|
| Median keystrokes per reply | ≥ 40% reduction |
| Inserts per agent per day | ≥ 20 within 30 days |

## 2. User stories & scope

### 2.1 Must-have
- As an agent, I can insert a saved reply into the current ticket in one click.

### 2.2 Won't-have (this version)

| Feature | Reason |
|---|---|
| Authoring / editing saved replies | Owned by the admin-console team under their existing settings-surface roadmap. |

## 3. Interface

### 3.1 Screens
The reply box gains an "Insert saved reply" button.

### 3.2 Endpoints
- **Insert saved reply** — inserts the chosen reply into the current ticket.
EOF

echo "seeded $SPEC + .specto/okrs.md (O4.KR1 objective is unanchored)"
