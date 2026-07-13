#!/usr/bin/env bash
# Seed a toy plan with two trivially-small, same-theme tasks so the eval can
# check that plan-to-tickets bundles them into one MR-sized ticket. Runs DRY-RUN
# only (the prompt enforces it), and the epic key is a non-existent TOY-1 so the
# live re-fetch warns-and-continues instead of touching a real epic.
set -eu
SANDBOX="$1"
SPEC="$SANDBOX/docs/development/specs/toy"
mkdir -p "$SANDBOX/.specto" "$SPEC"

cat > "$SANDBOX/.specto/plan.md" <<'EOF'
# Plan — toy: two tiny same-theme config tweaks

## Task 1: Rename the `foo_flag` config key to `feature_foo`
- Steps: rename the key in the team-settings config schema.
- AC: `feature_foo` replaces `foo_flag` everywhere it is read.

## Task 2: Default `feature_foo` to false for new tenants
- Steps: set the default value in the same config schema.
- AC: newly created tenants get `feature_foo=false`.
EOF

printf 'epic: TOY-1\n' > "$SPEC/.specto-meta.yml"
printf 'jira_project_key: TOY\n' > "$SANDBOX/.specto/config.yml"
cat > "$SPEC/engineering-spec.md" <<'EOF'
# Engineering Specifications

## 2. Technical approach

### 2.3. Storage model

Both flags live on the existing team-settings record; no new table.
EOF
echo "seeded $SPEC"
