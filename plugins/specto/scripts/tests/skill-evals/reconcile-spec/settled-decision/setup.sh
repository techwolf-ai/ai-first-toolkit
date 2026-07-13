#!/usr/bin/env bash
# Plant spec drift for the reconcile-spec guardian: engineering-spec.md §2.3 still
# says the storage decision is `Proposed` / `TODO(eng-approval)`, but a later
# commit on the branch SHIPPED it (the migration + model landed). reconcile-spec
# should propose turning the provisional decision into a "Decision (shipped)" that
# cites the commit as evidence, keeping the engineering fact in engineering-spec.md.
#
# NOTE: reconcile-spec is NEW in the specto v1 stack (not yet installed). Headless
# evals load the INSTALLED plugin, so this scenario only exercises the real skill
# once the branch is installed (local marketplace / branch install) or the stack
# merges. It is built now to lock the behaviour going forward — see NOTES.md.
#
# Offline: a real git repo with a commit range (main..HEAD) as the shipped surface.
set -eu
SANDBOX="$1"
SPEC_REL="docs/development/specs/2026-01-01-canned-replies"
export GIT_CONFIG_GLOBAL=/dev/null
GIT="git -C $SANDBOX -c user.name=eval -c user.email=eval@example.com -c commit.gpgsign=false -c init.defaultBranch=main"

$GIT init -q
mkdir -p "$SANDBOX/$SPEC_REL"
printf 'epic: TOY-1\n' > "$SANDBOX/$SPEC_REL/.specto-meta.yml"

cat > "$SANDBOX/$SPEC_REL/product-spec.md" <<'EOF'
# Product Specification — one-click canned replies

## 1. The value case
Agents insert a saved reply in one click, cutting handle time.
EOF

cat > "$SANDBOX/$SPEC_REL/engineering-spec.md" <<'EOF'
# Engineering Specifications — one-click canned replies

## 2. Technical approach

### 2.3. Storage model

**Proposed:** store the per-team `canned_replies_enabled` toggle either as a new
column on `team_settings` or as an entry in its existing `feature_flags` JSON
column. `TODO(eng-approval)`: platform to confirm which before implementation.
EOF
$GIT add -A
$GIT commit -qm "spec: canned replies — storage decision still proposed"

# --- what shipped: the feature_flags approach landed on a feature branch, so the
#     range main..HEAD is exactly the shipped work the spec should reconcile to.
$GIT checkout -q -b f-canned-replies-storage
mkdir -p "$SANDBOX/console/migrations"
cat > "$SANDBOX/console/migrations/0007_canned_replies_flag.py" <<'EOF'
from django.db import migrations

from console.feature_flags import FeatureFlag


def add_flag(apps, schema_editor):
    # canned_replies_enabled ships as a feature_flags JSON entry on team_settings
    # (no new column) — the proposed decision, now settled.
    FeatureFlag.set_default("canned_replies_enabled", False)


class Migration(migrations.Migration):
    operations = [migrations.RunPython(add_flag, migrations.RunPython.noop)]
EOF
$GIT add -A
$GIT commit -qm "feat: ship canned_replies_enabled as a feature_flags entry"

echo "seeded git sandbox ($SPEC_REL) with a shipped commit range"
