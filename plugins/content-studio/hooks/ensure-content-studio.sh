#!/bin/bash
# Hook: Ensure Content Studio is running on session start
# Scans ports 3000-3010 for the Content Studio fingerprint,
# since Next.js auto-increments the port if the default is taken.

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
CONTENT_STUDIO_DIR="$PROJECT_DIR/content-studio"

FINGERPRINT="Content Studio"

find_content_studio() {
  for port in $(seq 3000 3010); do
    local response
    response=$(curl -s --max-time 1 "http://localhost:$port" 2>/dev/null)
    if echo "$response" | grep -q "$FINGERPRINT"; then
      echo "$port"
      return 0
    fi
  done
  return 1
}

# Check if it's already running on any nearby port
FOUND_PORT=$(find_content_studio)
if [ -n "$FOUND_PORT" ]; then
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"SessionStart\",\"additionalContext\":\"Content Studio is running at http://localhost:$FOUND_PORT\"}}"
  exit 0
fi

# Not running, start it in the background
cd "$CONTENT_STUDIO_DIR" || exit 0

nohup npm run dev > /tmp/content-studio.log 2>&1 &

# Wait for it to become available (up to 25 seconds)
for i in $(seq 1 25); do
  FOUND_PORT=$(find_content_studio)
  if [ -n "$FOUND_PORT" ]; then
    open "http://localhost:$FOUND_PORT"
    echo "{\"hookSpecificOutput\":{\"hookEventName\":\"SessionStart\",\"additionalContext\":\"Content Studio was not running. Started it and opened http://localhost:$FOUND_PORT in your browser.\"}}"
    exit 0
  fi
  sleep 1
done

# Timed out, don't block the session
echo '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"Content Studio startup was attempted but may still be loading. Check http://localhost:3000 or run: cd content-studio && npm run dev"}}'
exit 0
