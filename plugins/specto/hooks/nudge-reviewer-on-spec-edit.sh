#!/usr/bin/env bash
# PostToolUse hook (Edit, Write, MultiEdit): when the assistant just edited or
# wrote to docs/development/specs/**/*.md:
#   1. touch .specto/.last-spec-edit  — the marker the load-okrs hook debounces on.
#   2. emit a one-line "consider review-spec" tip, but at most once per spec slug
#      per session. "Per session" is approximated by a marker file
#      .specto/.nudged/<slug> (keyed on $CLAUDE_SESSION_ID when that env var is
#      set, so a fresh session re-nudges; otherwise a plain per-slug marker).

set -u

# Read the JSON payload Claude Code passes on stdin.
payload="$(cat 2>/dev/null || true)"
[[ -z "$payload" ]] && exit 0

# Extract the tool name and file path.
tool="$(echo "$payload" | jq -r '.tool_name // .tool // empty' 2>/dev/null)"
file_path="$(echo "$payload" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)"

case "$tool" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac

# Match docs/development/specs/**/*.md
[[ "$file_path" == *"docs/development/specs/"*".md" ]] || exit 0

# 1. Update the debounce marker (only inside a repo that already uses specto).
[[ -d .specto ]] && touch .specto/.last-spec-edit 2>/dev/null

# 2. Once-per-spec-slug-per-session guard.
rest="${file_path##*docs/development/specs/}"
slug="${rest%%/*}"
if [[ -n "$slug" && "$slug" != "$rest" && -d .specto ]]; then
  marker_key="$slug"
  [[ -n "${CLAUDE_SESSION_ID:-}" ]] && marker_key="${slug}.${CLAUDE_SESSION_ID}"
  marker=".specto/.nudged/${marker_key}"
  [[ -e "$marker" ]] && exit 0
  mkdir -p .specto/.nudged 2>/dev/null && touch "$marker" 2>/dev/null
fi

cat <<EOF
{"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": "Tip: run the \`review-spec\` skill when you're ready for reviewer feedback (lint pre-pass + 4 reviewer agents in parallel)."}}
EOF
