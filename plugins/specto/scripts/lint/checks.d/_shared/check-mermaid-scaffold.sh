#!/usr/bin/env bash
# Catch mermaid blocks the writer left half-scaffolded (references/visual-conventions.md
# rules 1-2: validate before writing; don't ship placeholder diagrams). Two mechanical
# signals, both inside ```mermaid fences only:
#
#   1. UNFILLED PLACEHOLDER — a line still carrying a `<…>` template token
#      (e.g. `<one-line action>`, `<METHOD>`, `<Endpoint name>`). The engineering-spec
#      template ships a sequenceDiagram full of these; a real spec must replace them.
#      `<br>` / `<br/>` line breaks are legitimate and ignored.
#   2. UNTYPED / EMPTY FENCE — a ```mermaid block whose first non-directive, non-empty
#      line is not a recognized diagram keyword (or the block is empty). A real syntax
#      validator (scripts/lint/validate-mermaid.sh) catches more, but this is the cheap,
#      dependency-free first line of defence.
#
# Usage: check-mermaid-scaffold.sh <file>
# Exit: 0 pass, 1 violation, 2 bad usage / not a file.

set -u
if [[ $# -ne 1 ]]; then
  echo "usage: check-mermaid-scaffold.sh <file>" >&2
  exit 2
fi
FILE="$1"
if [[ ! -f "$FILE" ]]; then
  echo "not a file: $FILE" >&2
  exit 2
fi

report="$(awk '
  function flush_fence() {
    if (inmer && !haskey && !empty_reported) {
      print "UNTYPED fence starting at line " fence_start ": no recognized diagram type"
    }
  }
  /^[[:space:]]*```mermaid/ { inmer=1; fence_start=NR; firstdone=0; haskey=0; empty_reported=0; next }
  /^[[:space:]]*(```|~~~)/ && inmer { flush_fence(); inmer=0; next }
  inmer {
    # First non-empty, non-directive line names the diagram type.
    if (!firstdone) {
      t=$0; gsub(/^[[:space:]]+/,"",t)
      if (t != "" && t !~ /^%%/) {
        firstdone=1
        split(t, a, /[[:space:]]/); kw=a[1]
        if (kw ~ /^(flowchart|graph|sequenceDiagram|classDiagram|stateDiagram|stateDiagram-v2|erDiagram|journey|gantt|pie|mindmap|timeline|gitGraph|quadrantChart|requirementDiagram|C4Context|sankey-beta|xychart-beta|block-beta|packet-beta|architecture-beta)$/) haskey=1
      }
    }
    # Placeholder check: strip <br>/<br/> first, then look for a leftover <word…> token.
    s=$0; gsub(/<[bB][rR]\/?>/,"",s)
    if (s ~ /<[A-Za-z][^>]*>/) print "PLACEHOLDER " NR ": " $0
  }
  END { flush_fence() }
' "$FILE")"

if [[ -n "$report" ]]; then
  echo "mermaid block left half-scaffolded (visual-conventions.md rules 1-2):"
  printf '%s\n' "$report"
  exit 1
fi
exit 0
