#!/usr/bin/env bash
# Fail if there is no §4.3 (data-migration reversibility) section, or it is empty
# / a bare TODO. The eng-spec guidelines require a reversibility analysis there
# (an explicit "Not applicable — no schema changes." line counts as a valid body).
# Usage: check-reversibility.sh <file>

set -u
if [[ $# -ne 1 ]]; then
  echo "usage: check-reversibility.sh <file>" >&2
  exit 2
fi
FILE="$1"
if [[ ! -f "$FILE" ]]; then
  echo "not a file: $FILE" >&2
  exit 2
fi

# Does a §4.3 heading exist at all?
if ! grep -qE '^#+ 4\.3[.]?[ ]' "$FILE"; then
  echo "missing §4.3 (data migration reversibility) section"
  exit 1
fi

# Extract the §4.3 body up to the next same-or-shallower heading.
section=$(awk '
  /^#+ 4\.3[.]?[ ]/ { in_section = 1; next }
  /^#+ / && in_section { in_section = 0 }
  in_section { print }
' "$FILE")

# Strip whitespace, template placeholder markup (`*<...>*`), and a leading "TODO".
# What'\''s left is the "real" content; if it'\''s empty the section is a stub.
body=$(printf '%s\n' "$section" \
  | sed -E 's/^[[:space:]]*//; s/[[:space:]]*$//' \
  | grep -v '^$' \
  | grep -vE '^[*]?<[^>]*>[*]?$' \
  | grep -viE '^[*_]*todo[:.! ]?' )

if [[ -z "$body" ]]; then
  echo "§4.3 (data migration reversibility) is empty or only a TODO placeholder — add the reversibility analysis (or 'Not applicable — no schema changes.')"
  exit 1
fi
exit 0
