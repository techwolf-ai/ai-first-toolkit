#!/usr/bin/env bash
# Plant one known defect for eng-review: the spec header declares this an AI
# feature (AI feature = YES), so the applicability matrix requires §3.2 (AI test
# plan) to be filled — but §3.2 is ABSENT from the spec entirely. Every other
# in-scope section is well-formed (incl. §3.3 load testing, which AI feature=Yes
# also requires) so the missing AI test plan is the salient finding. Pure-local.
set -eu
SANDBOX="$1"
SPEC="$SANDBOX/docs/development/specs/2026-01-01-canned-replies"
mkdir -p "$SPEC"

cat > "$SPEC/engineering-spec.md" <<'EOF'
| | |
|---|---|
| **Epic link in Jira** | TOY-1 |
| **Product spec link** | [product-spec.md](product-spec.md) |
| **Version / scope** | V1 — smart canned-reply suggestions |
| **AI feature** | YES — suggests the most relevant saved replies via embedding similarity to the ticket text. |
| **Change classification** | Standard |
| **Development Stage** | Pre-production |

# Engineering Specifications — smart canned-reply suggestions

## 1. Non-functional requirements

### 1.1 Latency, throughput, scale targets
Suggest endpoint p99 ≤ 300ms including embedding lookup.

### 1.2 Availability and SLOs
*Not applicable — pre-production stage.*

### 1.3 Cost envelope
*Not applicable — reuses the existing embedding service; no new infra, Q2 = No.*

## 2. Technical approach

### 2.1 Architecture

```mermaid
graph LR
  Console --> API
  API --> EmbeddingSvc
  API --> Store
```

The console requests suggestions; the API embeds the ticket text via the existing
embedding service, ranks the team's saved replies by cosine similarity, and
returns the top five.

### 2.2 Algorithm details
Cosine similarity between the ticket-text embedding and each saved reply's cached
embedding; return top-5 above a 0.6 threshold.

### 2.3 Storage model and schema changes
Cache each saved reply's embedding as a `pgvector` column on the existing
`saved_replies` row, per the `console/AGENTS.md` convention for derived vectors.

## 3. Test plan

### 3.1 Unit and integration coverage
Unit tests for the ranking function; one integration test through the endpoint.

### 3.3 Load testing
100 rps for 10 min against the suggest endpoint; pass if p99 ≤ 300ms and error
rate < 0.5%.

### 3.4 Canary and rollout plan
Ship behind `smart_suggestions_enabled`, canary to 5% of teams; success: CTR on a
suggested reply ≥ 20%; rollback trigger: suggest error-rate ≥ 1%.

## 4. Rollback plan

### 4.1 Failure indicators
`suggest_error_rate` alert > 1%; `suggest_latency_p99` alert > 500ms.

### 4.2 Rollback procedure
Disable `smart_suggestions_enabled` (one config flip, ~2 min).

### 4.3 Data migration reversibility
The embedding cache column is additive and nullable; dropping it is reversible.

## 6. Design decisions for engineering approval

### 6.1 Cache embeddings on the saved-reply row
- **Proposed (V1):** a `pgvector` column on `saved_replies`.
- **Rationale:** matches the `console/AGENTS.md` derived-vector convention.
- **Open question for engineering:** no.
- **Decision:** approved by @sam.rivera.
EOF

echo "seeded $SPEC (AI-feature eng-spec with §3.2 AI test plan absent)"
