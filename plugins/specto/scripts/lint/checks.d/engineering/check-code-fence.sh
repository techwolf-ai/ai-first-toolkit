#!/usr/bin/env bash
# Fail if §3.2 (the AI test plan section) contains no fenced ``` code block.
# The engineering-spec guidelines want a worked example / eval-set snippet there
# when the section applies; an empty §3.2 with just a "Not an AI feature" line
# still passes (no fenced block expected, but also no requirement triggered) —
# this check only fires when §3.2 exists AND has prose but no fence.
# Usage: check-code-fence.sh <file>

set -u
if [[ $# -ne 1 ]]; then
  echo "usage: check-code-fence.sh <file>" >&2
  exit 2
fi
FILE="$1"
if [[ ! -f "$FILE" ]]; then
  echo "not a file: $FILE" >&2
  exit 2
fi

# Extract lines from the §3.2 heading up to the next same-or-shallower heading.
# Mirrors the awk section-extraction in check-metric-count.sh, generalised to
# match §3.2 at any heading depth (## 3.2 or ### 3.2).
section=$(awk '
  /^#+ 3\.2[.]?[ ]/ { in_section = 1; next }
  /^#+ / && in_section { in_section = 0 }
  in_section { print }
' "$FILE")

if [[ -z "$section" ]]; then
  # No §3.2 section at all: not this check'\''s concern (other lints / reviewers
  # catch a missing required section based on the applicability matrix).
  exit 0
fi

# If the section is only an inapplicability marker ("*Not an AI feature.*" etc.),
# there's nothing to fence — pass.
if printf '%s\n' "$section" | grep -qiE 'not (an ai feature|applicable)'; then
  exit 0
fi

# Look for an opening code fence (``` or ~~~) somewhere in the section.
if printf '%s\n' "$section" | grep -qE '^[[:space:]]*(```|~~~)'; then
  exit 0
fi

echo "§3.2 (AI test plan) has prose but no fenced code block — add a worked example / eval-set snippet"
exit 1
