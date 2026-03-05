#!/bin/bash
# List all published content files
# Usage: ./scripts/list-published.sh              # All published
# Usage: ./scripts/list-published.sh opinion      # Only published opinions
# Usage: ./scripts/list-published.sh linkedin-post # Only published LinkedIn posts

TYPE="$1"
CONTENT_DIR="$(dirname "$0")/../content/posts"

# Search all type folders
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
      echo "$file"
    fi
  done
done
