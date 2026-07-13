#!/usr/bin/env bash
# Read classification answers + generic metadata fields from a Jira epic.
# Used by Specto's new-spec skill (at scaffold time), the
# change-classification-review agent (at review time), and the dod agent.
#
# The classification questions are NOT hardcoded: they come from the repo's
# compliance profile (the `compliance:` block in .specto/config.yml — see
# references/compliance-profile.example.yml). The dispatching skill/agent
# parses that block and passes the questions as JSON. Without --questions the
# helper emits only the generic metadata plus `classification=unconfigured`.
#
# Usage:
#   epic-fields.sh <epic-key> [--questions <json>] [--from-fixture <path>]
#
#   --questions: JSON array of question objects:
#     [{"id":"Q1","flag":"security","question":"...",
#       "epic_field":"<display name on the epic>","epic_field_id":"customfield_NNNNN"}]
#     epic_field / epic_field_id are optional per question; resolution tries the
#     display name, then the field id, then a case-insensitive substring of the
#     display name / question text against the epic's field names.
#
# Generic metadata (Development Stage / Epic Type / Delivery cycle) is optional:
# display-name resolution by default, with per-tenant field-id overrides via
# .specto/tracker-jira.yml keys `epic_field.development_stage`,
# `epic_field.epic_type`, `epic_field.delivery_cycle` (machine fallback:
# plugin-config `jira_epic_field_<name>`).
#
# Output: one key=value per line on stdout —
#   flag_<id>=<answer>  (one per --questions entry)
#   development_stage= / epic_type= / delivery_cycle=
#   classification=Standard | Non-standard (<id> / <id>) | unconfigured
#   resolved_via=display_name | field_id | substring | mixed
# Exit:
#   0 — resolved (metadata may be empty with a stderr warning)
#   1 — a --questions field missing on the epic, OR JSON unparseable
#   2 — bad usage
#   3 — acli call failed (auth, network, key not found)

set -u

usage() {
  echo "usage: epic-fields.sh <epic-key> [--questions <json>] [--from-fixture <path>]" >&2
  exit 2
}

[[ $# -lt 1 ]] && usage
EPIC_KEY="$1"
shift

FIXTURE=""
QUESTIONS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from-fixture) [[ $# -ge 2 ]] || usage; FIXTURE="$2"; shift 2 ;;
    --questions)    [[ $# -ge 2 ]] || usage; QUESTIONS="$2"; shift 2 ;;
    *) usage ;;
  esac
done

if [[ -n "$QUESTIONS" ]]; then
  echo "$QUESTIONS" | jq -e 'type == "array"' >/dev/null 2>&1 || {
    echo "--questions is not a JSON array" >&2
    exit 2
  }
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../lib/config.sh"

# Fetch JSON: from fixture in test mode, from acli in live mode.
if [[ -n "$FIXTURE" ]]; then
  [[ -f "$FIXTURE" ]] || { echo "fixture not found: $FIXTURE" >&2; exit 2; }
  JSON="$(cat "$FIXTURE")"
else
  if ! command -v acli >/dev/null; then
    echo "acli not on PATH; install Atlassian CLI" >&2
    exit 3
  fi
  JSON="$(acli jira workitem view "$EPIC_KEY" --json --fields '*all' 2>/dev/null)" || {
    echo "acli failed (auth? key? network?); run 'acli auth' to verify" >&2
    exit 3
  }
fi

# Sanity-check that JSON parses before we start hunting fields.
echo "$JSON" | jq . >/dev/null 2>&1 || {
  echo "JSON unparseable from epic $EPIC_KEY" >&2
  exit 1
}

# Track which resolution tier answered, for the resolved_via= line.
# resolve_field runs in command substitutions (subshells), so it reports its
# tier as "<tier>\t<value>" on stdout; callers split via resolve_split.
via_display=0; via_id=0; via_substring=0

# Field resolver: display-name match, then field id, then case-insensitive
# substring of the display name / question text against the epic's field names.
# Prints "<tier>\t<value>"; exit 1 when no tier resolves.
resolve_field() {
  local display="$1"      # display name on the epic (may be empty)
  local id="$2"           # customfield id (may be empty)
  local pattern="$3"      # substring fallback (may be empty)

  local val
  if [[ -n "$display" ]]; then
    val="$(echo "$JSON" | jq -r --arg n "$display" '.fields[$n] | if type == "object" then .value // .name // .displayName else . end // empty' 2>/dev/null)"
    if [[ -n "$val" && "$val" != "null" ]]; then
      printf 'display_name\t%s' "$val"; return 0
    fi
  fi
  if [[ -n "$id" ]]; then
    val="$(echo "$JSON" | jq -r --arg n "$id" '.fields[$n] | if type == "object" then .value // .name // .displayName else . end // empty' 2>/dev/null)"
    if [[ -n "$val" && "$val" != "null" ]]; then
      printf 'field_id\t%s' "$val"; return 0
    fi
  fi
  if [[ -n "$pattern" ]]; then
    val="$(echo "$JSON" | jq -r --arg p "$pattern" '.fields | to_entries[] | select(.key | ascii_downcase | contains($p | ascii_downcase)) | .value | if type == "object" then .value // .name // .displayName else . end // empty' 2>/dev/null | head -1)"
    if [[ -n "$val" && "$val" != "null" ]]; then
      printf 'substring\t%s' "$val"; return 0
    fi
  fi
  return 1
}

# Split resolve_field's "<tier>\t<value>" in the PARENT shell (no subshell, so
# the tier counters actually stick): bumps the counter, sets RESOLVED_VAL.
resolve_note_tier() {
  local tagged="$1" tier
  tier="${tagged%%$'\t'*}"
  RESOLVED_VAL="${tagged#*$'\t'}"
  case "$tier" in
    display_name) via_display=1 ;;
    field_id)     via_id=1 ;;
    substring)    via_substring=1 ;;
  esac
}

# Tenant metadata-field overrides (.specto/tracker-jira.yml, machine fallback).
tenant_field_id() {
  local name="$1" val="" repo profile
  repo="$(specto_repo_dir)"
  if [[ -n "$repo" && -f "$repo/.specto/tracker-jira.yml" ]]; then
    val="$(specto_yaml_get "$repo/.specto/tracker-jira.yml" "epic_field.$name")"
  fi
  if [[ -z "$val" && -x "$HERE/../../plugin-config.sh" ]]; then
    val="$("$HERE/../../plugin-config.sh" get "jira_epic_field_$name" 2>/dev/null || true)"
  fi
  echo "$val"
}

# --- classification questions (profile-driven) -------------------------------
flag_lines=""
yes_ids=()
missing=()
if [[ -n "$QUESTIONS" ]]; then
  while IFS= read -r q; do
    [[ -z "$q" ]] && continue
    qid="$(echo "$q" | jq -r '.id // empty')"
    qdisplay="$(echo "$q" | jq -r '.epic_field // empty')"
    qfid="$(echo "$q" | jq -r '.epic_field_id // empty')"
    qtext="$(echo "$q" | jq -r '.question // empty')"
    [[ -z "$qid" ]] && { echo "--questions entry without an id" >&2; exit 2; }
    pattern="${qdisplay:-$qtext}"
    if tagged="$(resolve_field "$qdisplay" "$qfid" "$pattern")"; then
      resolve_note_tier "$tagged"; ans="$RESOLVED_VAL"
      flag_lines="${flag_lines}flag_${qid}=${ans}
"
      [[ "$ans" == "Yes" ]] && yes_ids+=("$qid")
    else
      missing+=("flag_${qid}")
    fi
  done < <(echo "$QUESTIONS" | jq -c '.[]')

  if (( ${#missing[@]} > 0 )); then
    echo "missing required (gating) fields on epic $EPIC_KEY: ${missing[*]}" >&2
    exit 1
  fi
fi

# --- generic metadata (optional, warning when absent) ------------------------
optional_missing=()
if tagged="$(resolve_field 'Development Stage' "$(tenant_field_id development_stage)" '')"; then
  resolve_note_tier "$tagged"; dev_stage="$RESOLVED_VAL"
else dev_stage=""; optional_missing+=("development_stage"); fi
if tagged="$(resolve_field 'Epic Type' "$(tenant_field_id epic_type)" '')"; then
  resolve_note_tier "$tagged"; epic_type="$RESOLVED_VAL"
else epic_type=""; optional_missing+=("epic_type"); fi
if tagged="$(resolve_field 'Delivery cycle' "$(tenant_field_id delivery_cycle)" '')"; then
  resolve_note_tier "$tagged"; delivery_cycle="$RESOLVED_VAL"
else delivery_cycle=""; optional_missing+=("delivery_cycle"); fi

if (( ${#optional_missing[@]} > 0 )); then
  echo "warning: missing optional metadata fields on epic $EPIC_KEY: ${optional_missing[*]} (continuing with empty values)" >&2
fi

# --- classification + resolved_via lines -------------------------------------
if [[ -z "$QUESTIONS" ]]; then
  classification="unconfigured"
elif (( ${#yes_ids[@]} == 0 )); then
  classification="Standard"
else
  joined="${yes_ids[0]}"
  for item in "${yes_ids[@]:1}"; do
    joined="$joined / $item"
  done
  classification="Non-standard ($joined)"
fi

tiers=$(( (via_display > 0) + (via_id > 0) + (via_substring > 0) ))
if (( tiers > 1 )); then resolved_via="mixed"
elif (( via_substring > 0 )); then resolved_via="substring"
elif (( via_id > 0 )); then resolved_via="field_id"
else resolved_via="display_name"
fi

printf '%s' "$flag_lines"
cat <<EOF
development_stage=$dev_stage
epic_type=$epic_type
delivery_cycle=$delivery_cycle
classification=$classification
resolved_via=$resolved_via
EOF
