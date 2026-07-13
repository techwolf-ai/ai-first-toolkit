#!/usr/bin/env bash
# UserPromptSubmit hook: when a spec was edited in the last ~5 min, append OKR
# content to the assistant's context.
# Trigger: the marker file .specto/.last-spec-edit (touched by the PostToolUse
# nudge hook on every spec edit) must exist AND be < ~5 min old — a single-file
# `find -mmin -5` stat check, so a user who isn't editing specs pays nothing.
# Source priority: Notion MCP (if .specto/config.yml has notion_okr_page_id) →
# .specto/okrs.md → silent no-op.

set -u

# Only fire when pwd is in a repo with docs/development/specs/.
[[ -d "docs/development/specs" ]] || exit 0

# Debounce: proceed only if a spec was edited recently (marker < ~5 min old).
[[ -n "$(find .specto/.last-spec-edit -mmin -5 -print -quit 2>/dev/null)" ]] || exit 0

# Source 1: .specto/okrs.md (Notion MCP path is invoked by the assistant, not the hook —
# hooks can't easily call MCPs).
if [[ -f ".specto/okrs.md" ]]; then
  okr_content="$(head -100 .specto/okrs.md)"
  jq -nc --arg ctx "Specto OKR snapshot from .specto/okrs.md:

$okr_content" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
  exit 0
fi

exit 0
