#!/usr/bin/env bash
# Fail if any of the four required header metadata rows is missing.
# Usage: check-metadata-rows.sh <file>

set -u
if [[ $# -ne 1 ]]; then
  echo "usage: check-metadata-rows.sh <file>" >&2
  exit 2
fi
FILE="$1"
if [[ ! -f "$FILE" ]]; then
  echo "not a file: $FILE" >&2
  exit 2
fi

REQUIRED=("Epic link" "AI feature" "Product opportunity" "Version / scope")
missing=()
for label in "${REQUIRED[@]}"; do
  if ! grep -q "$label" "$FILE"; then
    missing+=("$label")
  fi
done

if (( ${#missing[@]} > 0 )); then
  echo "missing required metadata rows in $FILE:"
  for label in "${missing[@]}"; do
    echo "  - $label"
  done
  exit 1
fi
exit 0
