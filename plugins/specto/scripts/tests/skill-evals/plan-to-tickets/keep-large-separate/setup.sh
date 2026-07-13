#!/usr/bin/env bash
# Inverse of the bundle-small-same-theme PoC: two LARGE, independent tasks that
# each warrant their own MR-sized ticket. The guardian behaviour under test is
# that plan-to-tickets does NOT over-bundle — it keeps them as two tickets, each
# with its own AC and spec link. Runs DRY-RUN only (prompt enforces it); epic is a
# non-existent TOY-1 so the live re-fetch warns-and-continues.
set -eu
SANDBOX="$1"
SPEC="$SANDBOX/docs/development/specs/2026-01-01-search"
mkdir -p "$SANDBOX/.specto" "$SPEC"

cat > "$SANDBOX/.specto/plan.md" <<'EOF'
# Plan — search: two large, independent workstreams

## Task 1: Build the inverted-index ingestion pipeline
- Steps: stream documents from the source topic, tokenise and normalise, build
  and persist the inverted index, add backpressure + retry, wire metrics.
- AC: documents flowing through the source topic are indexed within 5s p95;
  ingestion survives a broker restart without dropping documents.

## Task 2: Build the ranked query API
- Steps: parse the query, fan out to the index shards, merge and rank results,
  paginate, add the HTTP endpoint + auth + request validation.
- AC: `GET /search?q=` returns ranked results with pagination; unauthorised
  requests are rejected with 401.
EOF

printf 'epic: TOY-1\n' > "$SPEC/.specto-meta.yml"
printf 'jira_project_key: TOY\n' > "$SANDBOX/.specto/config.yml"
cat > "$SPEC/engineering-spec.md" <<'EOF'
# Engineering Specifications — search

## 2. Technical approach

### 2.1. Ingestion
The inverted-index ingestion pipeline consumes the source topic and persists the index.

### 2.2. Query
The ranked query API fans out to the index shards, merges, ranks, and paginates.
EOF
echo "seeded $SPEC"
