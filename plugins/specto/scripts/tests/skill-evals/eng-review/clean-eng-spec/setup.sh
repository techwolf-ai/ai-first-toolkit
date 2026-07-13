#!/usr/bin/env bash
# Negative control for eng-review: a well-formed engineering spec with no
# guideline violations — structural diagram AND a sequenceDiagram for the
# multi-actor flow, §2.3 storage explicit and convention-anchored, §2.6 endpoint
# contract filled, in-scope test-plan sections filled, out-of-scope sections
# marked `*Not applicable*` per the applicability matrix, and §6 decisions in the
# Proposed/Rationale/Open-question/Decision pattern. A guardian that flags this is
# producing false positives. Pure-local: eng-review only reads the file.
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

Structural view:

```mermaid
graph LR
  Console --> API
  API --> Store
  API --> AuditLog
```

Insert flow (console → API → reply store → audit log):

```mermaid
sequenceDiagram
  participant C as Console
  participant A as API
  participant S as Store
  participant L as AuditLog
  C->>A: POST insert-reply {reply_id}
  A->>S: fetch saved reply text
  A->>L: record insert (agent, ticket, reply)
  A-->>C: reply text
```

The diagram is canonical; the console populates the ticket reply box with the
returned text.

### 2.2 Algorithm details
A direct fetch of a stored string by id — no algorithm.

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

## 5. Other affected systems
*Not applicable — change is contained to the agent console + its API.*

## 6. Design decisions for engineering approval

### 6.1 Store the toggle in `feature_flags`, not a new column
- **Proposed (V1):** reuse `team_settings.feature_flags`.
- **Rationale:** matches the `console/AGENTS.md` convention; avoids a migration.
- **Open question for engineering:** no.
- **Decision:** approved by @sam.rivera.
EOF

echo "seeded $SPEC (well-formed eng-spec — negative control)"
