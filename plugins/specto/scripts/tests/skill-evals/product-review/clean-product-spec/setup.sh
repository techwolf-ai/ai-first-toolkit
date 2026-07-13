#!/usr/bin/env bash
# Negative control for product-review. Unlike the narrow reviewers (scope / okr /
# classification), product-review reviews WHOLE-SPEC completeness against the
# product-spec template, so a genuinely clean control must be a FULLY
# guidelines-conformant spec — a thin stub draws legitimate "missing section"
# findings (the first cut did; those were the guardian being right, not fabricating).
# This spec matches references/product-spec-guidelines.md section-for-section:
# complete stakeholder table (incl. Platform team + PS), §1.1-1.4 (≤5
# directly-controllable metrics), §2 user stories in the "As a <role>, I want
# <capability>, so that <benefit>" form with Won't-have reasons, §3 functional
# requirements with §3.1 Inputs table + §3.2 endpoint names + §3.3 exports (no
# request/response tables/schema/DDL), §4 design decisions in the
# Proposed→Rationale→Open-question→Decision pattern with a named approver, and §5
# rollout with §5.1 customer demand + §5.2 pilot stakeholders + §5.3 gating + §5.4
# adoption. No AI-flavoured prose, no unexplained codenames. A guardian that
# fabricates a violation on THIS is a false positive. Pure-local.
set -eu
SANDBOX="$1"
SPEC="$SANDBOX/docs/development/specs/2026-01-01-canned-replies"
mkdir -p "$SPEC"

cat > "$SPEC/product-spec.md" <<'EOF'
# Product Specification — one-click canned replies

## Delivery Stakeholders

| Representing / SME  | Representative        | ✓ / ✗ |
| ------------------- | --------------------- | ----- |
| Product manager     | @pm.jordan            |       |
| Engineering manager | @em.riley             |       |
| Engineering team    | @dev.sam              |       |
| Platform team       | @plat.lee             |       |
| PS                  | @ps.morgan            |       |

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
| Typo rate in outgoing replies | ≥ 30% reduction | Quality lift from standardised wording. |

## 2. User stories & scope

### 2.1 Must-have
- As an agent, I want to insert a saved reply into the current ticket in one click, so that I stop retyping the same macro replies.

### 2.2 Should-have
- As an agent, I want to see the five replies I use most at the top of the list, so that my common replies are one click away.

### 2.3 Won't-have (this version)

| Feature | Reason |
|---|---|
| Authoring / editing saved replies | Owned by the admin-console team under their existing settings-surface roadmap. |
| Sharing reply sets across teams | Requires a cross-team permission model that does not exist yet; blocked on that design. |

## 3. Functional requirements

### 3.1 Inputs

| Input | Source | Notes |
|---|---|---|
| Saved reply text | The team's saved-reply store | The text inserted into the reply box. |
| Most-used ranking | Per-agent insert history | Orders the saved-reply list, most-used first. |

### 3.2 Endpoints
- **Insert saved reply** — inserts the chosen reply into the current ticket's reply box.
- **List saved replies** — returns the agent's available saved replies, most-used first.

### 3.3 Exports
_None in this version._

## 4. Design decisions

### 4.1 Insert replaces the draft (does not append)
- **Proposed:** a single click overwrites the reply box with the saved reply's text.
- **Rationale:** starting from the saved text is the expected one-click behaviour; appending would compound with a half-typed draft and force the agent to clean up.
- **Open question:** none.
- **Decision:** approved by @pm.jordan.

## 5. Rollout & adoption

### 5.1 Customer demand
Acme Support asked for one-click canned replies in their Q4 2025 QBR, naming
repeated macro-reply retyping as their top agent handle-time complaint.

### 5.2 Pilot stakeholders
Vendor pilot owner: @ps.morgan (PS). Customer-side champion: @acme.lead, the
Acme Support team lead who raised the request.

### 5.3 Pilot → GA gating
Move from pilot to GA when *median keystrokes per reply* (§1.4) drops ≥ 40% across
the pilot teams for two consecutive weeks with no increase in reply error rate.

### 5.4 Adoption goal
Reach ≥ 20 inserts per agent per day (§1.4) within 30 days of pilot launch.
EOF

echo "seeded $SPEC (fully guidelines-conformant product spec — negative control)"
