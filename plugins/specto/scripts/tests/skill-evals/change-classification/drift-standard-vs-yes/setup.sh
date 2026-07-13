#!/usr/bin/env bash
# Plant one known defect for change-classification-review: the spec header's
# `Change classification` row reads `Standard`, but the linked epic answers Q1
# (auth/authz) = Yes. change-classification-review resolves the epic via
# epic-fields.sh <epic> (the LIVE path — no --from-fixture flag when a skill
# drives it), which shells out to `acli jira workitem view <epic> --json --fields
# '*all'`. There is no fixture flag to inject here, so we stub `acli` on
# $sandbox/bin (which run-evals.sh prepends to PATH). The stub returns an epic
# whose customfield_10101 (Q1) = Yes while Q2/Q3 = No — so the correct
# classification is `Non-standard (Q1)`, and the `Standard` header is drift.
set -eu
SANDBOX="$1"
SPEC_REL="docs/development/specs/2026-01-01-canned-replies"
SPEC="$SANDBOX/$SPEC_REL"
mkdir -p "$SPEC" "$SANDBOX/bin"

# --- acli stub: canned epic with Q1=Yes ------------------------------------------
cat > "$SANDBOX/bin/acli" <<'STUB'
#!/usr/bin/env bash
# Offline acli stub for the change-classification eval. Auth checks succeed; a
# workitem view returns a canned epic whose non-standard-change custom fields are
# Q1=Yes, Q2=No, Q3=No (plus matching metadata so only the classification row
# drifts). epic-fields.sh reads customfield_10101/10129/10128.
case "$*" in
  # Allow-fence (offline contract): answer only the expected acli subcommands; any
  # other invocation fails loudly instead of silently returning the epic payload.
  *auth*)          echo "✓ Logged in (stub)"; exit 0 ;;
  *workitem*view*) : ;;   # expected: fall through to the epic payload below
  *)               echo "STUB-FORBIDDEN: unexpected acli call: acli $*" >&2; exit 97 ;;
esac
cat <<'JSON'
{
  "key": "TOY-1",
  "fields": {
    "summary": "Epic — canned replies with per-role visibility",
    "customfield_10101": { "value": "Yes" },
    "customfield_10103": { "value": "No" },
    "customfield_10102": { "value": "No" },
    "customfield_10104": { "value": "Pre-production" },
    "customfield_10105": { "value": "Feature" },
    "customfield_10106": { "value": "Standard" },
    "description": {"type":"doc","version":1,"content":[{"type":"paragraph","content":[{"type":"text","text":"Epic body."}]}]}
  }
}
JSON
exit 0
STUB
chmod +x "$SANDBOX/bin/acli"

# --- compliance profile: the agent gates on this block; the epic_field_ids
# match the stubbed tenant's customfield ids above ------------------------------
mkdir -p "$SANDBOX/.specto"
cat > "$SANDBOX/.specto/config.yml" <<'YML'
compliance:
  epic_label: non-standard-change
  questions:
    - id: Q1
      flag: security
      question: "Does the change affect authentication or authorization?"
      epic_field_id: customfield_10101
      keywords: [auth, authn, authz, permission, RBAC, JWT, SSO, access control]
      rigor:
        - security reviewer assigned in the engineering-spec stakeholder table
    - id: Q2
      flag: availability
      question: "Could the change impact the availability of services?"
      epic_field_id: customfield_10103
      keywords: [SLO, availability, uptime, latency, capacity, failover, canary]
      rigor:
        - platform reviewer assigned in the engineering-spec stakeholder table
    - id: Q3
      flag: data
      question: "Will the change make permanent changes to customer data?"
      epic_field_id: customfield_10102
      keywords: [PII, customer data, migration, schema change, retention]
      rigor:
        - data-migration reversibility addressed in engineering-spec section 4
YML

# --- spec folder: .specto-meta.yml links the epic; header says Standard ----------
printf 'epic: TOY-1\n' > "$SPEC/.specto-meta.yml"

cat > "$SPEC/product-spec.md" <<'EOF'
# Product Specification — canned replies with per-role visibility

| | |
|---|---|
| **Epic link in Jira** | TOY-1 |
| **Change classification** | Standard |
| **Development Stage** | Pre-production |
| **Epic Type / Delivery cycle** | Feature / Standard |

## 1. The value case

### 1.1 Problem
Support agents retype the same macro replies dozens of times a day, and some
replies must only be visible to agents holding a given role.

### 1.2 Who it is for
Front-line support agents working in the agent console.

## 2. User stories & scope

### 2.1 Must-have
- As an agent, I can insert a saved reply into the current ticket in one click.
- As an admin, I can restrict a saved reply to agents holding a specific role.

## 3. Interface

### 3.1 Screens
The reply list only shows replies the agent's role is permitted to see; the insert
action enforces the same role-based permission check server-side.
EOF

echo "seeded $SPEC + acli stub (epic Q1=Yes, header says Standard — drift)"
