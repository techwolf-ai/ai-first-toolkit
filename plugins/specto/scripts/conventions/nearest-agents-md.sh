#!/usr/bin/env bash
# nearest-agents-md.sh — list the AGENTS.md / CLAUDE.md convention files that
# apply to one or more target paths, nearest-first.
#
# For each path argument: resolve a non-existent leaf to its nearest existing
# ancestor, then walk UP to the first directory containing .git or .jj (the repo
# root, auto-detected per path — so this works for the spec repo AND a dependent
# repo checked out elsewhere). At each directory level from the target up to and
# including that root, emit AGENTS.md then CLAUDE.md when present.
#
# Output: one absolute path per line, nearest-first (deepest directory first),
# deduped across all path arguments (a shared ancestor's file prints once). The
# nearest-first order IS the precedence order: by the agents.md convention all
# files on the path apply cumulatively and the CLOSEST one wins on conflict.
#
# Exit codes (repo idiom): 0 ok — empty output when nothing is found is NOT an
# error · 2 bad usage.

set -u

usage() {
  echo "usage: nearest-agents-md.sh <path> [<path>...]" >&2
  exit 2
}

[[ $# -ge 1 ]] || usage

declare -a OUT=()

seen_contains() {
  local needle="$1" x
  for x in "${OUT[@]+"${OUT[@]}"}"; do
    [[ "$x" == "$needle" ]] && return 0
  done
  return 1
}

for target in "$@"; do
  # Resolve a non-existent leaf to its nearest existing ancestor.
  dir="$target"
  while [[ -n "$dir" && ! -e "$dir" ]]; do
    parent="$(dirname "$dir")"
    [[ "$parent" == "$dir" ]] && break
    dir="$parent"
  done
  # Start from the containing directory if the resolved path is a file.
  [[ -f "$dir" ]] && dir="$(dirname "$dir")"
  # Absolutize (also normalizes . and trailing slashes); skip unresolvable paths.
  dir="$(cd "$dir" 2>/dev/null && pwd)" || continue

  cur="$dir"
  while :; do
    for f in AGENTS.md CLAUDE.md; do
      if [[ -f "$cur/$f" ]] && ! seen_contains "$cur/$f"; then
        OUT+=("$cur/$f")
      fi
    done
    # Stop after the directory holding the repo marker (the root).
    [[ -e "$cur/.git" || -e "$cur/.jj" ]] && break
    parent="$(dirname "$cur")"
    [[ "$parent" == "$cur" ]] && break   # filesystem root, no repo marker found
    cur="$parent"
  done
done

[[ ${#OUT[@]} -gt 0 ]] && printf '%s\n' "${OUT[@]}"
exit 0
