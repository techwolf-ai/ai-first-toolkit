#!/usr/bin/env bash
# Shared diff-anchor math for the forge backends. Source it, don't execute it.
# Defines functions only: no side effects on source.
#
# Extracted from gitlab/post-mr-comment.sh compute_anchor() so every backend
# anchors a review comment off the SAME hunk walk (the gitlab impl still
# carries its own copy for now; it delegates here in a later pass).
#
# specto_compute_anchor <diffs-json> <path> <line> [hunks-only]
#
# Emits five space-separated fields:
#   ADDED     <new_line> -          <new_path> <old_path>
#   UNCHANGED <new_line> <old_line> <new_path> <old_path>
#   NONE      -          -          -          -
# given the normalized per-file diff array (arg 1, entries carrying
# .new_path/.old_path/.diff with @@ headers), the spec path (arg 2), and the
# target new-file line (arg 3).
#
# The spec path is matched against a diff entry by exact path OR repo-relative
# suffix: reviewer agents are handed an ABSOLUTE spec_path, and the backend's
# position payload (and our own matching) need the repo-relative one, so the
# matched entry's canonical .new_path/.old_path are returned for the caller to
# anchor with. (Assumes diff paths contain no spaces: true for spec files.)
#
# The optional 4th arg "hunks-only" narrows anchoring to lines INSIDE diff
# hunks: a target line in the gaps between hunks (or beyond the last one)
# yields NONE instead of a computed UNCHANGED anchor. GitHub review comments
# can only attach to lines a hunk actually shows, so its backend passes it;
# GitLab text positions can anchor any line in the file, so it doesn't.
specto_compute_anchor() {
  local diffs="$1" path="$2" line="$3" ho=0
  [[ "${4:-}" == "hunks-only" ]] && ho=1
  local entry np op file_diff res
  entry="$(printf '%s' "$diffs" | jq -c --arg p "$path" '
    ([ .[] | select(.new_path == $p or .old_path == $p) ][0])
    // ([ .[]
          | (.new_path // "") as $np | (.old_path // "") as $op
          | select( (($np | length) > 0 and ($p | endswith("/" + $np)))
                 or (($op | length) > 0 and ($p | endswith("/" + $op))) ) ][0])
    // empty')"
  [[ -n "$entry" ]] || { echo "NONE - - - -"; return 0; }
  np="$(printf '%s' "$entry" | jq -r '.new_path // ""')"
  op="$(printf '%s' "$entry" | jq -r '.old_path // ""')"
  file_diff="$(printf '%s' "$entry" | jq -r '.diff')"
  res="$(printf '%s' "$file_diff" | awk -v T="$line" -v HO="$ho" '
    BEGIN { seen=0 }
    /^@@/ {
      seen=1
      o=$2; sub(/^-/,"",o); sub(/,.*/,"",o); old_ln=o+0
      n=$3; sub(/^\+/,"",n); sub(/,.*/,"",n); new_ln=n+0
      # gap before this hunk is unchanged; offset there is new_start-old_start
      if (T < new_ln) {
        if (HO) print "NONE"; else print "UNCHANGED", T, T-(new_ln-old_ln)
        found=1; exit
      }
      next
    }
    seen {
      c=substr($0,1,1)
      if (c=="+")      { if (new_ln==T) { print "ADDED", T, "-"; found=1; exit } new_ln++ }
      else if (c=="-") { old_ln++ }
      else if (c=="\\"){ }                       # "\ No newline at end of file"
      else             { if (new_ln==T) { print "UNCHANGED", T, old_ln; found=1; exit } old_ln++; new_ln++ }
    }
    END {
      if (!seen) print "NONE"
      else if (!found) { if (HO) print "NONE"; else print "UNCHANGED", T, T-(new_ln-old_ln) }
    }')"
  if [[ -z "$res" || "$res" == NONE* ]]; then echo "NONE - - - -"; return 0; fi
  echo "$res $np $op"
}
