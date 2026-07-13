#!/usr/bin/env bash
# SessionStart hook:
#   - When pwd is inside docs/development/specs/<initiative>/, surface the spec
#     file paths so the assistant has them in additional-context.
#   - When pwd is inside any repo that uses specto (a .specto/ dir exists up-tree),
#     surface the plugin-feedback watch-rule so friction capture is ambient — the
#     agent watches for friction without having to recall it from a skill.
#   - When pwd is a github/gitlab repo that does NOT use specto yet (no .specto/
#     and no docs/development/specs/), nudge the user to run /specto:setup — once
#     per repo, never again.
# Silent no-op when none applies.

set -u

# Degrade silently if jq is missing: this hook emits its context via jq, so a
# missing jq must never break a session — only the skills (which can print the
# doctor hint) should surface it.
command -v jq >/dev/null 2>&1 || exit 0

CWD="$(pwd)"

# 1. Walk up to find a docs/development/specs/<initiative>/ ancestor.
SPEC_FOLDER=""
candidate="$CWD"
while [[ "$candidate" != "/" && "$candidate" != "." ]]; do
  if [[ "$(basename "$(dirname "$candidate")")" == "specs" \
        && "$(basename "$(dirname "$(dirname "$candidate")")")" == "development" \
        && "$(basename "$(dirname "$(dirname "$(dirname "$candidate")")")")" == "docs" ]]; then
    SPEC_FOLDER="$candidate"
    break
  fi
  candidate="$(dirname "$candidate")"
done

# 2. Walk up to find a .specto/ ancestor (any specto-using repo).
SPECTO_DIR=""
candidate="$CWD"
while [[ "$candidate" != "/" && "$candidate" != "." ]]; do
  if [[ -d "$candidate/.specto" ]]; then
    SPECTO_DIR="$candidate/.specto"
    break
  fi
  candidate="$(dirname "$candidate")"
done

# 3. First-run nudge: not a specto repo yet (no .specto/ and no spec folder up
#    the tree), but it IS a github/gitlab repo with no spec convention in place.
#    Suggest /specto:setup, gated to once per repo by a marker keyed on the repo
#    root path so it never nags.
NUDGE=""
if [[ -z "$SPEC_FOLDER" && -z "$SPECTO_DIR" ]]; then
  REPO_ROOT="$(cd "$CWD" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)"
  [[ -z "$REPO_ROOT" ]] && REPO_ROOT="$(cd "$CWD" 2>/dev/null && jj root 2>/dev/null)"
  if [[ -n "$REPO_ROOT" && ! -d "$REPO_ROOT/docs/development/specs" ]]; then
    ORIGIN="$(cd "$CWD" 2>/dev/null && git remote get-url origin 2>/dev/null)"
    is_forge=0
    case "$ORIGIN" in
      *github.com[:/]*|*gitlab.com[:/]*|*gitlab.*[:/]*) is_forge=1 ;;
    esac
    if [[ "$is_forge" -eq 1 ]]; then
      NUDGE_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugin-data/specto}/nudges"
      key="$(printf '%s' "$REPO_ROOT" | cksum | awk '{print $1}')"
      marker="$NUDGE_DIR/$key"
      if [[ ! -f "$marker" ]]; then
        NUDGE="Specto is installed but not set up for this repo — run /specto:setup to detect your forge and tracker, write .specto/config.yml, and smoke-test the backends."
        mkdir -p "$NUDGE_DIR" 2>/dev/null && : > "$marker" 2>/dev/null || true
      fi
    fi
  fi
fi

[[ -z "$SPEC_FOLDER" && -z "$SPECTO_DIR" && -z "$NUDGE" ]] && exit 0

# Assemble the additional-context message from whatever applies.
msg=""

if [[ -n "$SPEC_FOLDER" ]]; then
  parts=()
  [[ -f "$SPEC_FOLDER/product-spec.md" ]] && parts+=("product-spec.md")
  [[ -f "$SPEC_FOLDER/engineering-spec.md" ]] && parts+=("engineering-spec.md")
  [[ -f "$SPEC_FOLDER/.specto-meta.yml" ]] && parts+=(".specto-meta.yml")
  [[ -d "$SPEC_FOLDER/context/raw" ]] && parts+=("context/raw/")
  [[ -d "$SPEC_FOLDER/context/compiled" ]] && parts+=("context/compiled/")
  if (( ${#parts[@]} > 0 )); then
    joined="${parts[0]}"
    for p in "${parts[@]:1}"; do joined="$joined, $p"; done
    msg="Specto: working in spec folder $SPEC_FOLDER (contains: $joined). Skills: new-spec, review-spec."
  fi
fi

if [[ -n "$SPECTO_DIR" ]]; then
  feedback="Specto plugin-feedback loop: while using specto skills, watch for friction (a skill stopping short, misclassifying, or missing an obvious follow-up). Capture it the moment you notice with \`plugin-feedback --capture \"<one-liner>\"\`; drain pending entries into work items with \`plugin-feedback --drain\`."
  if [[ -n "$msg" ]]; then
    msg="$msg $feedback"
  else
    msg="$feedback"
  fi
fi

if [[ -n "$NUDGE" ]]; then
  if [[ -n "$msg" ]]; then msg="$msg $NUDGE"; else msg="$NUDGE"; fi
fi

[[ -z "$msg" ]] && exit 0

jq -nc --arg ctx "$msg" \
  '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
