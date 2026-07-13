#!/usr/bin/env bash
# Plant two genuinely product-review-OWNED defects (unlike too-many-metrics, which
# product-review defers to the lint pre-pass — G-4). Both are in product-review's
# lane per references/product-spec-guidelines.md:
#   1. AI-flavoured prose (anti-patterns table) — a flowery, marketing-flavoured
#      §1.1 sentence that says nothing concrete.
#   2. cold-reader-gap — an unexplained internal codename ("Project Cormorant")
#      that a reader without the author's context cannot follow.
# Every other surface is well-formed (Won't-haves have reasons, ≤5 metrics, §3
# lists names only, no engineering creep) so these two are the salient findings.
# Pure-local: product-review only reads the file.
set -eu
SANDBOX="$1"
SPEC="$SANDBOX/docs/development/specs/2026-01-01-canned-replies"
mkdir -p "$SPEC"

cat > "$SPEC/product-spec.md" <<'EOF'
# Product Specification — one-click canned replies

## 1. The value case

### 1.1 Problem
In today's fast-paced support landscape, this game-changing capability empowers
agents to deliver seamless, best-in-class experiences that delight customers at
scale and unlock transformative operational synergies. This ships as part of
Project Cormorant.

### 1.2 Who it is for
Front-line support agents working in the agent console.

### 1.3 Objectives

| # | Objective | Customer / segment | OKR |
|---|---|---|---|
| 1 | Cut keystrokes per reply so agents resolve tickets faster | Pilot support teams | — |

### 1.4 Key results / metrics

| Metric | Threshold | Why this matters |
|---|---|---|
| Median keystrokes per reply | ≥ 40% reduction | Direct measure of the effort saved. |
| Inserts per agent per day | ≥ 20 within 30 days | Shows the feature is actually used. |

## 2. User stories & scope

### 2.1 Must-have
- As an agent, I can insert a saved reply into the current ticket in one click.

### 2.2 Won't-have (this version)

| Feature | Reason |
|---|---|
| Authoring / editing saved replies | Owned by the admin-console team under their existing settings-surface roadmap. |

## 3. Interface

### 3.1 Screens
The reply box gains an "Insert saved reply" button that opens the saved-reply list.

### 3.2 Endpoints
- **Insert saved reply** — inserts the chosen reply into the current ticket's reply box.
EOF

echo "seeded $SPEC (AI-flavoured prose + unexplained codename — product-review's lane)"
