#!/usr/bin/env bash
# Snapshot a real spec folder's deterministic artifacts into a golden scenario
# the e2e suite (run-tests.sh) then asserts against.
#
# Skills are LLM-driven, so we cannot re-run them in CI. Instead we capture one
# real run's output here (manually, whenever a skill's shape intentionally
# changes) and let CI assert structural invariants + diffs against the snapshot.
#
# Volatile fields are normalized on capture so re-captures diff cleanly:
#   * 40-hex git SHAs (in `> Spec section:` permalinks)  -> <GITSHA>
#   * ISO-8601 timestamps                                 -> <TIMESTAMP>
#   * the source spec-folder's absolute path              -> <SPEC_FOLDER>
#
# Usage:
#   capture.sh <scenario-name> --spec-folder <path> [--plan <path>]
#
# <scenario-name>  directory created under golden/<scenario-name>/ (overwritten
#                  if it exists — capture is idempotent).
# --spec-folder    a spec folder holding product-spec.md / engineering-spec.md /
#                  .specto-meta.yml (e.g. docs/development/specs/<slug>/).
# --plan           optional path to the plan.md (default: <repo>/.specto/plan.md
#                  if present).
#
# Exit: 0 ok · 1 expected input missing · 2 bad usage.

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # scripts/tests/e2e
GOLDEN="$HERE/golden"

usage() {
  echo "usage: capture.sh <scenario-name> --spec-folder <path> [--plan <path>]" >&2
  exit 2
}

[[ $# -ge 1 ]] || usage
SCENARIO="$1"; shift
case "$SCENARIO" in -*|"" ) usage ;; esac

SPEC_FOLDER=""
PLAN=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --spec-folder) [[ $# -ge 2 ]] || usage; SPEC_FOLDER="$2"; shift 2 ;;
    --plan)        [[ $# -ge 2 ]] || usage; PLAN="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[[ -n "$SPEC_FOLDER" ]] || usage
[[ -d "$SPEC_FOLDER" ]] || { echo "spec folder not found: $SPEC_FOLDER" >&2; exit 1; }
SPEC_FOLDER="$(cd "$SPEC_FOLDER" && pwd)"

# Normalize volatile fields on stdin -> stdout.
normalize() {
  sed -E \
    -e 's#/blob/[0-9a-f]{40}/#/blob/<GITSHA>/#g' \
    -e 's#\b[0-9a-f]{40}\b#<GITSHA>#g' \
    -e 's#[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}(:[0-9]{2})?(Z|[+-][0-9]{2}:?[0-9]{2})?#<TIMESTAMP>#g' \
    -e "s#${SPEC_FOLDER//#/\\#}#<SPEC_FOLDER>#g"
}

DEST="$GOLDEN/$SCENARIO"
rm -rf "$DEST"
mkdir -p "$DEST/spec"

captured=()
copy_norm() {  # <src> <dest>
  [[ -f "$1" ]] || return 1
  normalize < "$1" > "$2"
  captured+=("${2#"$DEST"/}")
  return 0
}

copy_norm "$SPEC_FOLDER/product-spec.md"     "$DEST/spec/product-spec.md"     || true
copy_norm "$SPEC_FOLDER/engineering-spec.md" "$DEST/spec/engineering-spec.md" || true
copy_norm "$SPEC_FOLDER/.specto-meta.yml"    "$DEST/spec/.specto-meta.yml"    || true

# plan.md: explicit --plan, else a sibling/repo default if present.
[[ -z "$PLAN" && -f "$SPEC_FOLDER/../../../.specto/plan.md" ]] && PLAN="$SPEC_FOLDER/../../../.specto/plan.md"
[[ -n "$PLAN" ]] && copy_norm "$PLAN" "$DEST/plan.md" || true

if [[ ${#captured[@]} -eq 0 ]]; then
  echo "nothing captured — no product-spec.md / engineering-spec.md / plan.md under $SPEC_FOLDER" >&2
  rm -rf "$DEST"
  exit 1
fi

# Provenance manifest (source path normalized; no live timestamp so the manifest
# itself stays diff-stable across re-captures).
{
  echo "scenario: $SCENARIO"
  echo "source: <SPEC_FOLDER>"
  echo "files:"
  printf '  - %s\n' "${captured[@]}"
} > "$DEST/MANIFEST"

echo "captured scenario '$SCENARIO' -> ${DEST#"$HERE"/}/ (${#captured[@]} files)"
printf '  %s\n' "${captured[@]}"
