#!/usr/bin/env bash
# Fail if the spec has a stakeholder/reviewer table but no row mentioning the
# data-platform / platform team. If there is no such table, this check passes —
# it is only a gate when the table exists.
#
# Note: the Q3=Yes conditionality (only *require* the data-platform reviewer when
# the linked epic's Q3 answer is Yes) is enforced by the caller (review-spec runs
# the eng-lint only when appropriate). This check just validates table contents.
# Usage: check-stakeholder-table.sh <file>

set -u
if [[ $# -ne 1 ]]; then
  echo "usage: check-stakeholder-table.sh <file>" >&2
  exit 2
fi
FILE="$1"
if [[ ! -f "$FILE" ]]; then
  echo "not a file: $FILE" >&2
  exit 2
fi

# Find a heading containing "stakeholder" or "reviewer" (case-insensitive), then
# capture the markdown table block that follows it (lines starting with `|`,
# allowing blank/prose lines until the first `|` row, stopping at the next heading).
table=$(awk '
  BEGIN { in_section = 0; in_table = 0 }
  tolower($0) ~ /^#+ .*(stakeholder|reviewer)/ { in_section = 1; in_table = 0; next }
  /^#+ / && in_section { in_section = 0; in_table = 0 }
  in_section && /^[[:space:]]*\|/ { in_table = 1; print; next }
  in_section && in_table && !/^[[:space:]]*\|/ { in_table = 0; in_section = 0 }
' "$FILE")

if [[ -z "$table" ]]; then
  # No stakeholder/reviewer table found — nothing to gate.
  exit 0
fi

# Does any row mention the data-platform / platform team?
if printf '%s\n' "$table" | grep -qiE 'data[ -]?platform|platform team'; then
  exit 0
fi

echo "stakeholder/reviewer table has no data-platform / platform-team row — add one (required when the epic's Q3 answer is Yes)"
exit 1
