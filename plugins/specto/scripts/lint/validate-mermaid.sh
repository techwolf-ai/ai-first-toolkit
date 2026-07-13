#!/usr/bin/env bash
# Programmatic mermaid SYNTAX validation — the "validate before writing" rule
# (references/visual-conventions.md rule 1) made real. Extracts every ```mermaid fence
# from the given markdown file(s) and renders each through mermaid-cli (`mmdc`); a fence
# that fails to render is a syntax error reported with its file + start line.
#
# This is the rich, browser-backed check, kept OUT of the fast blocking lint
# (checks.d/* is pure-bash, no deps). Run it from CI on changed specs, or have the
# spec writer / mr-walkthrough agents run it after generating diagrams.
#
# It also emits soft SIZE warnings (rule 3, "keep it small") to stderr — these never
# affect the exit code.
#
# Renderer resolution: `mmdc` on PATH, else `npx -p @mermaid-js/mermaid-cli mmdc`.
# mmdc needs a headless Chromium; in CI use an image that has one (or let npx fetch it).
#
# Usage:
#   validate-mermaid.sh <file.md> [<file.md> ...]
#   validate-mermaid.sh --list <file.md> [...]    # print extracted fences, do not render
#   validate-mermaid.sh --require-renderer <file.md> [...]   # exit 3 (not skip) if no mmdc
#
# Exit:
#   0 — every fence rendered (or --list, or no fences)
#   1 — at least one fence failed to render (syntax error)
#   2 — bad usage / not a file
#   3 — no renderer available (only when --require-renderer, otherwise it warns + exits 0)

set -u

MODE=validate
REQUIRE_RENDERER=0
FILES=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --list)             MODE=list; shift ;;
    --require-renderer) REQUIRE_RENDERER=1; shift ;;
    -h|--help)          sed -n '2,28p' "$0"; exit 0 ;;
    -*)                 echo "unknown flag: $1" >&2; exit 2 ;;
    *)                  FILES+=("$1"); shift ;;
  esac
done
[[ ${#FILES[@]} -ge 1 ]] || { echo "usage: validate-mermaid.sh [--list|--require-renderer] <file.md> ..." >&2; exit 2; }
for f in "${FILES[@]}"; do
  [[ -f "$f" ]] || { echo "not a file: $f" >&2; exit 2; }
done

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Split a markdown file's ```mermaid fences into $TMP/<tag>-<n>.mmd, writing the start
# line of each to <tag>-<n>.line. Prints the fence count.
extract() {
  local file="$1" tag="$2"
  awk -v dir="$TMP" -v tag="$tag" '
    /^[[:space:]]*```mermaid/ { inmer=1; n++; print NR > (dir"/"tag"-"n".line"); close(dir"/"tag"-"n".line"); next }
    /^[[:space:]]*(```|~~~)/ && inmer { inmer=0; close(dir"/"tag"-"n".mmd"); next }
    inmer { print > (dir"/"tag"-"n".mmd") }
    END { print n+0 }
  ' "$file"
}

# Resolve a renderer command into RENDERER (array). Empty if none.
RENDERER=()
if command -v mmdc >/dev/null 2>&1; then
  RENDERER=(mmdc)
elif command -v npx >/dev/null 2>&1; then
  RENDERER=(npx -p @mermaid-js/mermaid-cli mmdc)
fi

# A puppeteer config so mmdc's Chromium runs in CI/root sandboxes.
PUPPET="$TMP/puppeteer.json"
printf '{"args":["--no-sandbox","--disable-setuid-sandbox"]}' > "$PUPPET"

# size warnings (stderr only; never change exit code)
warn_size() {
  local mmd="$1" where="$2"
  local lines participants
  lines="$(grep -cvE '^[[:space:]]*(%%|$)' "$mmd")"
  if (( lines > 40 )); then
    echo "warning: $where — large diagram ($lines lines); consider splitting (visual-conventions.md rule 3)" >&2
  fi
  if grep -qE '^[[:space:]]*sequenceDiagram' "$mmd"; then
    participants="$(grep -cE '^[[:space:]]*(participant|actor)[[:space:]]' "$mmd")"
    if (( participants > 8 )); then
      echo "warning: $where — $participants participants in one sequenceDiagram; consider per-caller diagrams (rule 3)" >&2
    fi
  fi
}

fail=0
total_fences=0
for file in "${FILES[@]}"; do
  tag="$(printf '%s' "$file" | tr -c 'A-Za-z0-9' '_')"
  count="$(extract "$file" "$tag")"
  total_fences=$((total_fences + count))
  for ((i=1; i<=count; i++)); do
    mmd="$TMP/$tag-$i.mmd"
    [[ -f "$mmd" ]] || continue
    startline="$(cat "$TMP/$tag-$i.line" 2>/dev/null || echo '?')"
    where="$file:$startline"
    if [[ "$MODE" == "list" ]]; then
      firstline="$(grep -vE '^[[:space:]]*(%%|$)' "$mmd" | head -1 | sed 's/^[[:space:]]*//')"
      printf '%s\t%s\n' "$where" "$firstline"
      continue
    fi
    warn_size "$mmd" "$where"
    if [[ ${#RENDERER[@]} -eq 0 ]]; then
      continue   # handled once after the loop
    fi
    if ! "${RENDERER[@]}" -p "$PUPPET" -i "$mmd" -o "$TMP/out.svg" >/dev/null 2>"$TMP/err"; then
      echo "INVALID $where:" >&2
      sed 's/^/    /' "$TMP/err" >&2
      fail=1
    fi
  done
done

if [[ "$MODE" == "list" ]]; then
  exit 0
fi

if [[ ${#RENDERER[@]} -eq 0 ]]; then
  msg="no mermaid renderer found (install @mermaid-js/mermaid-cli, or ensure npx + a headless Chromium are available)"
  if [[ "$REQUIRE_RENDERER" -eq 1 ]]; then
    echo "$msg" >&2
    exit 3
  fi
  echo "warning: $msg — skipped syntax validation of $total_fences fence(s)" >&2
  exit 0
fi

exit "$fail"
