#!/usr/bin/env bash
# Seed a toy spec folder for the staged value-first drafting eval. Pure-local:
# new-spec's product-spec-writer only writes files, so this scenario needs no
# network and no mocks — just a brainstorm artefact and an empty spec folder.
set -eu
SANDBOX="$1"
SPEC="$SANDBOX/docs/development/specs/2026-01-01-canned-replies"
mkdir -p "$SPEC/context/compiled" "$SPEC/context/raw"

cat > "$SPEC/context/compiled/brainstorm.md" <<'EOF'
# Brainstorm — one-click canned replies

ceremony: full

## Goal
Support agents retype the same macro replies dozens of times a day. Give them a
one-click "insert saved reply" action in the agent console.

## In scope
- Insert a saved reply into the current ticket reply box in one click.

## Won't have
- Authoring/editing saved replies — reason: separate settings surface, out of scope for v1.

## Stakeholders
- PM: A. Example
- EM: B. Example

## Open questions
_None._
EOF

# product-spec.md intentionally absent — the writer drafts it.
echo "seeded $SPEC"
