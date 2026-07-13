#!/usr/bin/env bash
# Enforce the dark-mode palette rule (references/visual-conventions.md rule 4) on
# mermaid `classDef` lines. Review surfaces commonly render on a dark theme, so:
#   1. a fill: without an explicit color: pulls light text onto a light fill, and
#   2. the pastel palette mermaid examples ship with is light-on-light regardless.
# Either drop the classDef (let the theme colour nodes) or use the dark palette with
# an explicit color: on every line.
#
# Only lines INSIDE a ```mermaid fence are inspected. A spec with no mermaid, or with
# classDefs that all carry color: and avoid the pastel fills, passes. Mechanical only.
#
# Usage: check-diagram-palette.sh <file>
# Exit: 0 pass, 1 violation, 2 bad usage / not a file.

set -u
if [[ $# -ne 1 ]]; then
  echo "usage: check-diagram-palette.sh <file>" >&2
  exit 2
fi
FILE="$1"
if [[ ! -f "$FILE" ]]; then
  echo "not a file: $FILE" >&2
  exit 2
fi

# The documented "never use" pastel fills (the Material-ish palette mermaid examples
# default to). Matched case-insensitively. Keep in sync with visual-conventions.md rule 4.
PASTELS='#ECEFF1|#E8F5E9|#FFF3E0|#FFEBEE|#F3E5F5|#E3F2FD|#FFFDE7|#E0F2F1|#FCE4EC|#EFEBE9|#E1F5FE|#FFF8E1|#F1F8E9|#FBE9E7|#EDE7F6|#E0F7FA'

no_color="$(awk '
  /^[[:space:]]*```mermaid/ { inmer=1; next }
  /^[[:space:]]*(```|~~~)/ && inmer { inmer=0; next }
  inmer && /classDef/ && /fill:/ && !/color:/ { print NR": "$0 }
' "$FILE")"

pastel="$(awk -v pastels="$PASTELS" '
  BEGIN { IGNORECASE = 1 }
  /^[[:space:]]*```mermaid/ { inmer=1; next }
  /^[[:space:]]*(```|~~~)/ && inmer { inmer=0; next }
  inmer && /classDef/ && $0 ~ pastels { print NR": "$0 }
' "$FILE")"

rc=0
if [[ -n "$no_color" ]]; then
  echo "mermaid classDef sets fill: without an explicit color: — unreadable on the dark-mode reviewer (visual-conventions.md rule 4):"
  printf '%s\n' "$no_color"
  rc=1
fi
if [[ -n "$pastel" ]]; then
  echo "mermaid classDef uses a pastel fill from the 'never use' palette — light-on-light on the dark-mode reviewer (visual-conventions.md rule 4):"
  printf '%s\n' "$pastel"
  rc=1
fi
exit "$rc"
