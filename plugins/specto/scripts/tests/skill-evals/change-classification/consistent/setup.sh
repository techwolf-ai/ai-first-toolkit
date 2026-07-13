#!/usr/bin/env bash
# Negative control for change-classification-review: the spec header reads
# `Standard` and the linked epic answers Q1/Q2/Q3 all = No — so the header is
# consistent with the epic. The spec body is also free of auth / availability /
# customer-data keywords, so no body-vs-epic drift fires either. A guardian that
# flags this is producing false positives. The acli stub shadows the live
# epic-fields.sh path (run-evals.sh prepends $sandbox/bin to PATH).
set -eu
SANDBOX="$1"
SPEC_REL="docs/development/specs/2026-01-01-canned-replies"
SPEC="$SANDBOX/$SPEC_REL"
mkdir -p "$SPEC" "$SANDBOX/bin"

# --- acli stub: canned epic with all-No answers ----------------------------------
cat > "$SANDBOX/bin/acli" <<'STUB'
#!/usr/bin/env bash
# Offline acli stub: auth succeeds; a workitem view returns an epic whose
# non-standard-change custom fields are all No (Standard change), with matching
# metadata. The compliance profile below maps Q1/Q2/Q3 to these field ids.
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
    "summary": "Epic — one-click canned replies",
    "customfield_10101": { "value": "No" },
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
# Product Specification — one-click canned replies

| | |
|---|---|
| **Epic link in Jira** | TOY-1 |
| **Change classification** | Standard |
| **Development Stage** | Pre-production |
| **Epic Type / Delivery cycle** | Feature / Standard |

## 1. The value case

### 1.1 Problem
Support agents retype the same macro replies dozens of times a day, costing
handle time and introducing typos.

### 1.2 Who it is for
Front-line support agents working in the agent console.

## 2. User stories & scope

### 2.1 Must-have
- As an agent, I can insert a saved reply into the current ticket in one click.

## 3. Interface

### 3.1 Screens
The reply box gains an "Insert saved reply" button that opens the saved-reply list.
EOF

echo "seeded $SPEC + acli stub (epic all-No, header Standard — consistent)"
