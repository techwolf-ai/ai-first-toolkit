#!/usr/bin/env bash
# Read a Jira work item's description (which the API returns as an Atlassian
# Document Format JSON tree) and emit it as plain Markdown on stdout. Used by
# implement-ticket to read the ticket body + acceptance criteria + spec link.
#
# Renders: heading -> #/##/...; paragraph -> text; bulletList -> "- ";
# orderedList -> "1. "; codeBlock -> fenced ```; rule -> "---"; blockquote -> "> ";
# text marks strong -> **bold**, em -> _italic_, code -> `code`;
# link / inlineCard / mention -> [text](url); hardBreak -> newline.
# The tree walk is a recursive jq program (no python dependency).
#
# Usage:
#   get-ticket-description.sh <KEY>                       # live: calls acli
#   get-ticket-description.sh <KEY> --from-fixture <path> # test: reads a JSON file
#
# The fixture / acli JSON is a work-item object; the description is at
# `.fields.description` (an ADF doc node) — same shape `epic-fields.sh` reads.
#
# Output: Markdown on stdout. Warnings/errors to stderr.
# Exit:
#   0 — rendered Markdown (may be empty if the description is empty)
#   1 — JSON unparseable, or no `.fields.description` ADF node found
#   2 — bad usage
#   3 — acli not on PATH, or acli call failed

set -u
set -o pipefail

usage() {
  echo "usage: get-ticket-description.sh <KEY> [--from-fixture <path>]" >&2
  exit 2
}

[[ $# -lt 1 ]] && usage
KEY="$1"
shift

FIXTURE=""
if [[ $# -gt 0 ]]; then
  if [[ "$1" == "--from-fixture" && $# -ge 2 ]]; then
    FIXTURE="$2"
    shift 2
  else
    usage
  fi
fi

if [[ -n "$FIXTURE" ]]; then
  [[ -f "$FIXTURE" ]] || { echo "fixture not found: $FIXTURE" >&2; exit 3; }
  JSON="$(cat "$FIXTURE")"
else
  if ! command -v acli >/dev/null; then
    echo "acli not on PATH; install Atlassian CLI" >&2
    exit 3
  fi
  JSON="$(acli jira workitem view "$KEY" --json --fields 'description' 2>/dev/null)" || {
    echo "acli failed (auth? key? network?); run 'acli auth' to verify" >&2
    exit 3
  }
fi

echo "$JSON" | jq . >/dev/null 2>&1 || { echo "JSON unparseable for $KEY" >&2; exit 1; }

# The description node. Some acli payloads put it directly at .description; the
# work-item view nests it under .fields.description. Accept either; bail if absent
# or not an ADF doc.
desc="$(echo "$JSON" | jq -c '.fields.description // .description // empty' 2>/dev/null)"
if [[ -z "$desc" || "$desc" == "null" ]]; then
  echo "no description on $KEY (empty ticket body)" >&2
  exit 1
fi
# Plain-string descriptions (rare, legacy) — just echo them through.
if [[ "$(echo "$desc" | jq -r 'type' 2>/dev/null)" == "string" ]]; then
  echo "$desc" | jq -r '.'
  exit 0
fi

# --- ADF -> Markdown walker (jq) -------------------------------------------------
ADF_JQ='
def render_marks($text):
  reduce (.marks // [])[] as $m
    ($text;
      if   $m.type == "strong" then "**" + . + "**"
      elif $m.type == "em"     then "_"  + . + "_"
      elif $m.type == "code"   then "`"  + . + "`"
      elif $m.type == "link"   then "[" + . + "](" + ($m.attrs.href // "") + ")"
      else . end);
def inline:
  reduce (.content // [])[] as $n
    ("";
      . + (
        if   $n.type == "text"      then ($n | render_marks($n.text // ""))
        elif $n.type == "hardBreak" then "\n"
        elif ($n.type == "inlineCard" or $n.type == "mention")
          then ("[" + (($n.attrs.url // $n.attrs.text // $n.text // "link")) + "](" + ($n.attrs.url // "") + ")")
        else ($n | inline)
        end));
def blocks($depth):
  reduce (.content // [])[] as $b
    ([];
      . + (
        if $b.type == "heading"
          then [ (("#" * ($b.attrs.level // 1)) // "#") + " " + ($b | inline), "" ]
        elif $b.type == "paragraph"
          then [ ($b | inline), "" ]
        elif $b.type == "codeBlock"
          then [ ("```" + ($b.attrs.language // "")), ($b.content // [] | map(.text // "") | join("")), "```", "" ]
        elif $b.type == "rule"
          then [ "---", "" ]
        elif $b.type == "blockquote"
          then [ ($b | blocks($depth) | map("> " + .) | join("\n")), "" ]
        elif ($b.type == "bulletList" or $b.type == "orderedList")
          then
            ( reduce ($b.content // [] | to_entries)[] as $li
                ([];
                  ( ($li.value.content // []) as $items
                  | ($items | map(
                        if .type == "paragraph" then (. | inline)
                        else (. | blocks($depth + 1) | join("\n")) end) | join("\n")) as $body
                  | ( (("  " * $depth) // "")
                      + (if $b.type == "orderedList" then (($li.key + 1 | tostring) + ". ") else "- " end)
                      + $body ) as $line
                  | . + [ $line ] )) )
            + [ "" ]
        else
          ( ($b | inline) as $t | if ($t | length) > 0 then [ $t, "" ] else [] end )
        end));
blocks(0)
| join("\n")
| gsub("\n{3,}"; "\n\n")
| sub("\\s+$"; "")
'
# --------------------------------------------------------------------------------

out="$(echo "$desc" | jq -r "$ADF_JQ" 2>/dev/null)" || {
  echo "could not render ADF tree for $KEY (malformed ADF?)" >&2
  exit 1
}
printf '%s\n' "$out"
