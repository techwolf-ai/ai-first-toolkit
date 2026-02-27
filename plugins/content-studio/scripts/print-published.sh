#!/bin/bash
# Print full content of published posts (metadata + content)
# Usage: ./scripts/print-published.sh              # All published (up to 100)
# Usage: ./scripts/print-published.sh linkedin-post # Only published LinkedIn posts
# Usage: ./scripts/print-published.sh opinion       # Only published opinions

TYPE="$1"
CONTENT_DIR="$(dirname "$0")/../content/posts"
COUNT=0
MAX=100

# Collect all published files with their dates
declare -a files=()

for type_dir in "$CONTENT_DIR"/*/; do
  [ -d "$type_dir" ] || continue

  type_name=$(basename "$type_dir")

  # If type filter provided, skip non-matching types
  if [ -n "$TYPE" ] && [ "$type_name" != "$TYPE" ]; then
    continue
  fi

  for file in "$type_dir"*.yaml; do
    [ -f "$file" ] || continue
    if grep -q "^stage: 03-published" "$file" 2>/dev/null; then
      files+=("$file")
    fi
  done
done

# Sort by filename (which contains timestamp) in reverse order (most recent first)
IFS=$'\n' sorted=($(sort -r <<<"${files[*]}")); unset IFS

# Print each file with separator
for file in "${sorted[@]}"; do
  [ $COUNT -ge $MAX ] && break

  echo "================================================================================"
  echo "FILE: $file"
  echo "================================================================================"
  cat "$file"
  echo ""
  echo ""

  ((COUNT++))
done

echo "================================================================================"
echo "Total: $COUNT published posts"
