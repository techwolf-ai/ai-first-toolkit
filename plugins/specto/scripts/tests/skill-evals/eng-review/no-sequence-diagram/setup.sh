#!/usr/bin/env bash
# Plant one known defect for the eng-review guardian to catch: §2.1 describes a
# multi-actor flow (4 actors, ≥4 steps: console → API → store → audit-log) in
# PROSE ONLY, with a structural mermaid `graph` present but NO `sequenceDiagram`.
# Per engineering-spec-guidelines principle / anti-pattern "Multi-step flow
# described in prose", a ≥3-actor / ≥4-step flow must carry a mermaid
# `sequenceDiagram`. Every other section is well-formed so the missing sequence
# diagram is the salient finding. Pure-local: eng-review only reads the file.
set -eu
SANDBOX="$1"
SPEC="$SANDBOX/docs/development/specs/2026-01-01-canned-replies"
mkdir -p "$SPEC"

cat > "$SPEC/engineering-spec.md" <<'EOF'
| | |
|---|---|
| **Epic link in Jira** | TOY-1 |
| **Product spec link** | [product-spec.md](product-spec.md) |
| **Version / scope** | V1 — one-click canned replies |
| **AI feature** | NO — no model inference in this change. |
| **Change classification** | Standard |
| **Development Stage** | Pre-production |

# Engineering Specifications — one-click canned replies

## 1. Non-functional requirements

### 1.1 Latency, throughput, scale targets
Insert-reply endpoint p99 ≤ 150ms; list-replies endpoint p99 ≤ 200ms.

### 1.2 Availability and SLOs
*Not applicable — pre-production stage.*

### 1.3 Cost envelope
*Not applicable — no new infra, Q2 = No.*

## 2. Technical approach

### 2.1 Architecture

```mermaid
graph LR
  Console --> API
  API --> Store
  API --> AuditLog
```

When an agent clicks "Insert saved reply", the agent console posts the reply id
to the canned-replies API. The API then loads the saved reply from the reply
store, writes an audit-log entry recording which agent inserted which reply on
which ticket, and finally returns the reply text to the console, which populates
the ticket reply box. Four participants take part in this flow — the console,
the API, the reply store, and the audit log — across four ordered steps.

### 2.2 Algorithm details
No algorithm — a direct fetch of a stored string by id.

### 2.3 Storage model and schema changes
The per-team enable toggle is stored as a `FeatureFlag("canned_replies_enabled")`
entry in the existing `team_settings.feature_flags` JSON column, per the
`console/AGENTS.md` convention that new per-team flags go in `feature_flags` (no
new column or table).

### 2.6 Endpoint contracts

| Endpoint | Method | Path | Body | Response | Errors | Caps |
|---|---|---|---|---|---|---|
| Insert reply | POST | `/tickets/{id}/insert-reply` | `{reply_id:int}` | `{text:str}` | 404 unknown reply, 409 closed ticket | 60 req/min |

## 3. Test plan

### 3.1 Unit and integration coverage
Unit tests for the fetch + audit-write path; one integration test posting through
the endpoint. See `console/tests/test_replies.py`.

### 3.2 AI test plan
*Not an AI feature.*

### 3.3 Load testing
*Not applicable — Q2 = No, not an AI feature.*

### 3.4 Canary and rollout plan
Ship behind `canned_replies_enabled`, canary to 5% of teams, success criterion:
insert error-rate < 0.5% over 24h; rollback trigger: error-rate ≥ 1%.

## 4. Rollback plan

### 4.1 Failure indicators
`insert_reply_error_rate` alert > 1%; `insert_reply_latency_p99` alert > 300ms.

### 4.2 Rollback procedure
Disable `canned_replies_enabled` for all teams (one config flip, ~2 min). No data
migration to unwind.

### 4.3 Data migration reversibility
*Not applicable — §2.3 adds no schema changes.*

## 6. Design decisions for engineering approval

### 6.1 Store the toggle in `feature_flags`, not a new column
- **Proposed (V1):** reuse `team_settings.feature_flags`.
- **Rationale:** matches the `console/AGENTS.md` convention; avoids a migration.
- **Open question for engineering:** no.
- **Decision:** approved by @sam.rivera.
EOF

echo "seeded $SPEC (eng-spec with a prose-only multi-actor flow, no sequenceDiagram)"
