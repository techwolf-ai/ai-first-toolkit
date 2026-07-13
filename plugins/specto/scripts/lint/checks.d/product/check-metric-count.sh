#!/usr/bin/env bash
# Fail if §1.4 metric count exceeds 5.
# Usage: check-metric-count.sh <file>

set -u
if [[ $# -ne 1 ]]; then
  echo "usage: check-metric-count.sh <file>" >&2
  exit 2
fi
FILE="$1"
if [[ ! -f "$FILE" ]]; then
  echo "not a file: $FILE" >&2
  exit 2
fi

# Extract lines between '## 1.4' and the next '## ' heading.
section=$(awk '
  /^## 1\.4/ { in_section = 1; next }
  /^## / && in_section { in_section = 0 }
  in_section { print }
' "$FILE")

if [[ -z "$section" ]]; then
  # No §1.4 section: not a violation here (other lints catch missing sections).
  exit 0
fi

# Count table rows that are not header / separator / empty.
# A "data row" starts with `| ` and the first non-`|` char is not `-` or `:` (separator) and not bold (`**`).
metric_rows=$(printf '%s\n' "$section" \
  | grep -E '^\|' \
  | grep -vE '^\| *(-+|:?-+:?) *(\|.*)?$' \
  | grep -vE '^\| *Metric *\|' \
  | wc -l \
  | tr -d ' ')

if (( metric_rows > 5 )); then
  echo "§1.4 has $metric_rows metric rows (max 5)"
  exit 1
fi
exit 0
