#!/bin/bash
# List all posts of a specific type (any stage)
# Usage: ./scripts/list-by-type.sh opinion
# Usage: ./scripts/list-by-type.sh linkedin-post

TYPE="$1"

if [ -z "$TYPE" ]; then
  echo "Usage: $0 <type>"
  echo "Types: linkedin-post, opinion, article, blog-post, thread, newsletter"
  exit 1
fi

CONTENT_DIR="$(dirname "$0")/../content/posts"

# Check type-specific folder first
TYPE_DIR="$CONTENT_DIR/$TYPE"
if [ -d "$TYPE_DIR" ]; then
  for file in "$TYPE_DIR"/*.yaml; do
    [ -f "$file" ] || continue
    title=$(grep "^title:" "$file" | head -1 | sed 's/^title: //' | sed 's/^"//' | sed 's/"$//')
    stage=$(grep "^stage:" "$file" | head -1 | sed 's/^stage: //')
    echo "[$stage] $title"
    echo "  File: $file"
    echo ""
  done
fi

# Also check root posts folder for backwards compatibility
for file in "$CONTENT_DIR"/*.yaml; do
  [ -f "$file" ] || continue
  if grep -q "^type: $TYPE" "$file" 2>/dev/null; then
    title=$(grep "^title:" "$file" | head -1 | sed 's/^title: //' | sed 's/^"//' | sed 's/"$//')
    stage=$(grep "^stage:" "$file" | head -1 | sed 's/^stage: //')
    echo "[$stage] $title"
    echo "  File: $file"
    echo ""
  fi
done
