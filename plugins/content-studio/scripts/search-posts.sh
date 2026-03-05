#!/bin/bash
# Search posts by keyword, optionally filter by type
# Usage: ./scripts/search-posts.sh "AI"                    # Search all
# Usage: ./scripts/search-posts.sh "AI" --type opinion     # Search only opinions
# Usage: ./scripts/search-posts.sh "AI" --type linkedin-post

if [ -z "$1" ]; then
  echo "Usage: $0 <search term> [--type <type>]"
  echo "Searches all posts for matching text in title, content, tags, or coreInsight"
  echo "Types: linkedin-post, opinion, blog-post"
  exit 1
fi

SEARCH_TERM="$1"
TYPE=""

# Parse arguments
shift
while [[ $# -gt 0 ]]; do
  case $1 in
    --type)
      TYPE="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

CONTENT_DIR="$(dirname "$0")/../content/posts"

echo "Searching for: $SEARCH_TERM"
[ -n "$TYPE" ] && echo "Type filter: $TYPE"
echo "---"

# Function to process a file
process_file() {
  local file="$1"
  local type_filter="$2"

  if grep -qi "$SEARCH_TERM" "$file" 2>/dev/null; then
    # If type filter provided, check it matches
    if [ -n "$type_filter" ]; then
      if ! grep -q "^type: $type_filter" "$file" 2>/dev/null; then
        return
      fi
    fi

    title=$(grep "^title:" "$file" | head -1 | sed 's/^title: //' | sed 's/^"//' | sed 's/"$//')
    stage=$(grep "^stage:" "$file" | head -1 | sed 's/^stage: //')
    type=$(grep "^type:" "$file" | head -1 | sed 's/^type: //')
    slug=$(grep "^slug:" "$file" | head -1 | sed 's/^slug: //')

    echo "[$stage] [$type] $title"
    echo "  File: $file"
    echo ""
  fi
}

# Search in type folders
for type_dir in "$CONTENT_DIR"/*/; do
  [ -d "$type_dir" ] || continue

  type_name=$(basename "$type_dir")

  # If type filter provided, skip non-matching types
  if [ -n "$TYPE" ] && [ "$type_name" != "$TYPE" ]; then
    continue
  fi

  for file in "$type_dir"*.yaml; do
    [ -f "$file" ] || continue
    process_file "$file" "$TYPE"
  done
done
