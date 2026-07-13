#!/usr/bin/env bash
# Shared classification-from-body parsing for tracker backends whose epics have
# no custom fields (github, linear). Source it, don't execute it.
#
# The epic's description carries a structured markdown block:
#
#   ### Change classification
#   - [x] Q1: Does the change affect authentication or authorization?
#   - [ ] Q2: Could the change impact the availability of services?
#
# specto_classify_from_body <body> <questions-json>
#   emits the same contract lines the jira epic-fields.sh emits:
#     flag_<id>=Yes|No           (one per question; [x] = Yes, [ ] = No)
#     development_stage= / epic_type= / delivery_cycle=   (always empty here —
#       these backends carry no structured metadata fields)
#     classification=Standard | Non-standard (<id> / <id>)
#     resolved_via=body
#   A question with no matching checklist line defaults to No with a stderr
#   note (body blocks are author-maintained, unlike Jira's required fields),
#   so the caller always gets a complete answer set and exit 0.
#
# Matching: a checklist line answers question <id> when its text starts with
# "<id>:" (case-insensitive), or contains the question text case-insensitively.

specto_classify_from_body() {
  local body="$1" questions="$2"
  local block flag_lines="" yes_ids=() missing=()

  # Extract the block: lines after a "### Change classification" heading (any
  # heading level), up to the next heading or end of body.
  block="$(printf '%s\n' "$body" | awk '
    /^#{1,6}[[:space:]]+[Cc]hange [Cc]lassification[[:space:]]*$/ { inblock=1; next }
    inblock && /^#{1,6}[[:space:]]/ { inblock=0 }
    inblock { print }')"

  if [[ -z "$block" ]]; then
    echo "no '### Change classification' block found on the epic body; all flags default to No" >&2
  fi

  local q qid qtext line answer lower_line lower_qid lower_qtext
  while IFS= read -r q; do
    [[ -z "$q" ]] && continue
    qid="$(echo "$q" | jq -r '.id // empty')"
    qtext="$(echo "$q" | jq -r '.question // empty')"
    [[ -z "$qid" ]] && { echo "--questions entry without an id" >&2; return 2; }
    answer=""
    lower_qid="$(printf '%s' "$qid" | tr '[:upper:]' '[:lower:]')"
    lower_qtext="$(printf '%s' "$qtext" | tr '[:upper:]' '[:lower:]')"
    while IFS= read -r line; do
      case "$line" in
        -\ \[x\]\ *|-\ \[X\]\ *) checked=Yes ;;
        -\ \[\ \]\ *)            checked=No ;;
        *) continue ;;
      esac
      lower_line="$(printf '%s' "${line#- \[?\] }" | tr '[:upper:]' '[:lower:]')"
      if [[ "$lower_line" == "$lower_qid:"* ]] \
         || { [[ -n "$lower_qtext" ]] && [[ "$lower_line" == *"$lower_qtext"* ]]; }; then
        answer="$checked"
        break
      fi
    done <<EOF_BLOCK
$block
EOF_BLOCK
    if [[ -z "$answer" ]]; then
      missing+=("$qid")
      answer="No"
    fi
    flag_lines="${flag_lines}flag_${qid}=${answer}
"
    [[ "$answer" == "Yes" ]] && yes_ids+=("$qid")
  done < <(echo "$questions" | jq -c '.[]')

  if (( ${#missing[@]} > 0 )) && [[ -n "$block" ]]; then
    echo "no checklist line matched for: ${missing[*]} (defaulted to No)" >&2
  fi

  local classification joined item
  if (( ${#yes_ids[@]} == 0 )); then
    classification="Standard"
  else
    joined="${yes_ids[0]}"
    for item in "${yes_ids[@]:1}"; do
      joined="$joined / $item"
    done
    classification="Non-standard ($joined)"
  fi

  printf '%s' "$flag_lines"
  cat <<EOF_OUT
development_stage=
epic_type=
delivery_cycle=
classification=$classification
resolved_via=body
EOF_OUT
}
