#!/usr/bin/env bash
# Create a Jira ticket (any type), and (in the SAME invocation) create any
# Blocks / BlockedBy links — so a partial create can never leave a missing link
# This is the one vetted `acli jira workitem create` call;
# plan-to-tickets, create-ticket, and create-test-plan all shell out to it
# instead of inlining acli.
#
# The default invocation matches the original plan-to-tickets case — Task under
# an epic with a plain-text description-file:
#     --type Task --project <P> --summary <S> --description-file <F>
#     --label specto --parent <E>  (+ --json to read back the key).
# Flags broaden the script to cover create-ticket (Task/Bug/Story, optional
# epic, sprint placement, bug fields, --assign) and create-test-plan (Test Plan
# type with a full ADF description). The `specto` label is always applied.
#
# A 3-tier customfield-fallback hook (`resolve_customfields`) mirrors
# epic-fields.sh: it returns a JSON object of `additionalAttributes` to apply
# via a follow-up `acli jira workitem edit --from-json`. It is intentionally EMPTY
# right now — no APP-only IDs hardcoded — but structured so a per-project map is a
# one-line addition. Sprint / impact / priority flags merge into the same object.
# NOTE: acli 1.3.19 rejects `edit --key --from-json` (mutually-exclusive flag group)
# and cannot set these custom fields via edit OR create, so the follow-up edit
# always fails on that version — Impact / Priority / resolve_customfields values do
# NOT apply. The follow-up edit now emits a LOUD stderr warning naming the dropped
# fields instead of silently continuing; the ticket is still created either way.
#
# Usage:
#   create-ticket.sh <project-key> <epic-key|-> <summary> <description-file|-> \
#       [--type <Task|Bug|Story|Test Plan>]                                  \
#       [--no-epic]                                                          \
#       [--label <name>]...                                                  \
#       [--sprint-id <id>]                                                   \
#       [--impact <Low|Medium|High|Critical|<id>>]                           \
#       [--priority <Low|Medium|High|Urgent|<id>>]                           \
#       [--description-adf-file <path>]                                      \
#       [--assign]                                                           \
#       [--blocks <KEY>]... [--blocked-by <KEY>]...
#   create-ticket.sh <project-key> <epic-key|-> <summary> <description-file|-> ... \
#       --from-fixture <path>
#
# <description-file> may be "-" to read the body from stdin.
# <epic-key> may be "-" (or pass `--no-epic`) to create a standalone ticket
#   without a parent epic. The original positional usage is preserved: callers
#   that always pass a real epic key continue to work unchanged.
# --type defaults to "Task". Any acli-known issue type is accepted (Bug, Story,
#   Test Plan, …). `Test Plan` requires --description-adf-file in practice.
# --label is repeatable. The `specto` label is always applied in addition to any
#   labels passed via this flag.
# --sprint-id sets the Sprint customfield (default customfield_10020, Jira
#   Cloud's common id; override via the tenant profile key `sprint_field`).
# --impact / --priority accept either the option name (Low/Medium/High/...) or a
#   raw option ID. Option-name -> option-ID maps are tenant-specific and come
#   from the tenant profile (.specto/tracker-jira.yml: `impact_field`,
#   `impact_option.<name>`, `priority_option.<name>`; machine fallback
#   plugin-config `jira_impact_field`, `jira_impact_option_<name>`, ...).
#   Unconfigured impact: the flag is skipped with a stderr note. Unconfigured
#   priority names fall back to Jira's standard by-name payload.
# --description-adf-file <path> supplies a full ADF JSON document as the
#   description. Mutually exclusive with the positional <description-file>; pass
#   "-" for the positional when using this flag.
# --assign assigns the new ticket to @me after creation (best-effort; non-fatal).
# --from-fixture <path>: the fixture is the JSON `acli create --json` would return
#   (e.g. {"key":"APP-1234"}); the helper prints that key and exercises the link
#   loop against link-tickets.sh in its own fixture mode (a sibling
#   `tests/fixtures/link-ok.json` is used as the link "response").
#
# Output: the new issue key on stdout (nothing else). Warnings/errors to stderr.
# Exit:
#   0 — Ticket created and all links created
#   1 — create succeeded but the key could not be parsed from the response
#   2 — bad usage
#   3 — acli not on PATH, acli create failed, or a link create failed

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  echo "usage: create-ticket.sh <project-key> <epic-key|-> <summary> <description-file|-> [--type <T>] [--no-epic] [--label <n>]... [--sprint-id <id>] [--impact <v>] [--priority <v>] [--description-adf-file <path>] [--assign] [--blocks <KEY>]... [--blocked-by <KEY>]... [--from-fixture <path>]" >&2
  exit 2
}

[[ $# -lt 4 ]] && usage
PROJECT="$1"
EPIC_KEY="$2"
SUMMARY="$3"
DESC_SRC="$4"
shift 4

BLOCKS=()
BLOCKED_BY=()
FIXTURE=""
TYPE="Task"
NO_EPIC=false
LABELS=()
SPRINT_ID=""
IMPACT_RAW=""
PRIORITY_RAW=""
ADF_FILE=""
ASSIGN=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --blocks)                [[ $# -ge 2 ]] || usage; BLOCKS+=("$2"); shift 2 ;;
    --blocked-by)            [[ $# -ge 2 ]] || usage; BLOCKED_BY+=("$2"); shift 2 ;;
    --from-fixture)          [[ $# -ge 2 ]] || usage; FIXTURE="$2"; shift 2 ;;
    --type)                  [[ $# -ge 2 ]] || usage; TYPE="$2"; shift 2 ;;
    --no-epic)               NO_EPIC=true; shift ;;
    --label)                 [[ $# -ge 2 ]] || usage; LABELS+=("$2"); shift 2 ;;
    --sprint-id)             [[ $# -ge 2 ]] || usage; SPRINT_ID="$2"; shift 2 ;;
    --impact)                [[ $# -ge 2 ]] || usage; IMPACT_RAW="$2"; shift 2 ;;
    --priority)              [[ $# -ge 2 ]] || usage; PRIORITY_RAW="$2"; shift 2 ;;
    --description-adf-file)  [[ $# -ge 2 ]] || usage; ADF_FILE="$2"; shift 2 ;;
    --assign)                ASSIGN=true; shift ;;
    *)                       usage ;;
  esac
done

# --no-epic is equivalent to passing "-" for the positional epic key.
[[ "$EPIC_KEY" == "-" ]] && NO_EPIC=true

# Tenant profile lookups: option-name -> option-ID maps and field ids are
# instance-specific (acli has no built-in resolver), so they come from the
# repo's .specto/tracker-jira.yml (flat keys), with a plugin-config machine
# fallback (jira_ prefix, dots -> underscores). Nothing tenant-shaped is
# hardcoded here.
. "$HERE/../../lib/config.sh"
jira_profile_get() {
  local key="$1" val="" repo
  repo="$(specto_repo_dir)"
  if [[ -n "$repo" && -f "$repo/.specto/tracker-jira.yml" ]]; then
    val="$(specto_yaml_get "$repo/.specto/tracker-jira.yml" "$key")"
  fi
  if [[ -z "$val" && -x "$HERE/../../plugin-config.sh" ]]; then
    val="$("$HERE/../../plugin-config.sh" get "jira_$(printf '%s' "$key" | tr '.' '_')" 2>/dev/null || true)"
  fi
  echo "$val"
}

# Resolve --impact / --priority. Numeric input passes through as an option ID.
# Named impact needs both impact_field and impact_option.<name> configured;
# otherwise the flag is skipped with a note. Named priority without a
# priority_option.<name> mapping falls back to Jira's standard by-name payload.
IMPACT_ID=""
IMPACT_FIELD="$(jira_profile_get impact_field)"
PRIORITY_ID=""
PRIORITY_NAME=""
if [[ -n "$IMPACT_RAW" ]]; then
  if [[ "$IMPACT_RAW" =~ ^[0-9]+$ ]]; then
    IMPACT_ID="$IMPACT_RAW"
  else
    IMPACT_ID="$(jira_profile_get "impact_option.$(printf '%s' "$IMPACT_RAW" | tr '[:upper:]' '[:lower:]')")"
  fi
  if [[ -z "$IMPACT_FIELD" || -z "$IMPACT_ID" ]]; then
    echo "note: no impact field/option mapping configured for this tenant; --impact ignored (see .specto/tracker-jira.yml: impact_field, impact_option.<name>)" >&2
    IMPACT_ID=""
  fi
fi
if [[ -n "$PRIORITY_RAW" ]]; then
  if [[ "$PRIORITY_RAW" =~ ^[0-9]+$ ]]; then
    PRIORITY_ID="$PRIORITY_RAW"
  else
    PRIORITY_ID="$(jira_profile_get "priority_option.$(printf '%s' "$PRIORITY_RAW" | tr '[:upper:]' '[:lower:]')")"
    [[ -z "$PRIORITY_ID" ]] && PRIORITY_NAME="$(printf '%s' "$PRIORITY_RAW" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')"
  fi
fi
SPRINT_FIELD="$(jira_profile_get sprint_field)"
[[ -z "$SPRINT_FIELD" ]] && SPRINT_FIELD="customfield_10020"

# Resolve the description body. ADF JSON (--description-adf-file, or stdin/file
# content that parses as `{"type":"doc"}`) goes through `acli ... --from-json`;
# Markdown is auto-converted via md_to_adf.py first. Falls back to the legacy
# --description-file path on conversion failure / missing python3.
DESC_FILE=""
DESC_FILE_IS_TEMP=false
ADF_FILE_IS_TEMP=false
cleanup() {
  $DESC_FILE_IS_TEMP && [[ -n "$DESC_FILE" && -f "$DESC_FILE" ]] && rm -f "$DESC_FILE"
  $ADF_FILE_IS_TEMP  && [[ -n "$ADF_FILE"  && -f "$ADF_FILE"  ]] && rm -f "$ADF_FILE"
  return 0
}
trap cleanup EXIT
if [[ -n "$ADF_FILE" ]]; then
  [[ -f "$ADF_FILE" ]] || { echo "ADF file not found: $ADF_FILE" >&2; exit 2; }
  # Drain the positional <description-file> if it was "-" so callers can still
  # pass "-" + ADF in the same invocation without leaving stdin unread.
  if [[ "$DESC_SRC" == "-" ]]; then cat >/dev/null; fi
elif [[ "$DESC_SRC" == "-" ]]; then
  DESC_FILE="$(mktemp -t specto-desc.XXXXXX)"
  DESC_FILE_IS_TEMP=true
  cat > "$DESC_FILE"
else
  [[ -f "$DESC_SRC" ]] || { echo "description file not found: $DESC_SRC" >&2; exit 2; }
  DESC_FILE="$DESC_SRC"
fi

# Auto-detect ADF / Markdown. Skip if --description-adf-file was already set.
if [[ -z "$ADF_FILE" && -n "$DESC_FILE" ]]; then
  first_char="$(tr -d '[:space:]' < "$DESC_FILE" | head -c 1)"
  if [[ "$first_char" == "{" ]] && jq -e '.type == "doc"' "$DESC_FILE" >/dev/null 2>&1; then
    # Caller piped raw ADF JSON via the markdown path. Promote it to the ADF path.
    ADF_FILE="$DESC_FILE"
    $DESC_FILE_IS_TEMP && ADF_FILE_IS_TEMP=true && DESC_FILE_IS_TEMP=false
    DESC_FILE=""
  elif command -v python3 >/dev/null && [[ -r "$HERE/md_to_adf.py" ]]; then
    converted="$(mktemp -t specto-adf.XXXXXX)"
    if python3 "$HERE/md_to_adf.py" < "$DESC_FILE" > "$converted" 2>/dev/null \
       && jq -e '.type == "doc"' "$converted" >/dev/null 2>&1; then
      ADF_FILE="$converted"
      ADF_FILE_IS_TEMP=true
    else
      rm -f "$converted"
      echo "warning: md_to_adf.py conversion failed; falling back to --description-file (will render as plain text in Jira)" >&2
    fi
  fi
fi

# --- customfield fallback hook ---------------------------------------------------
# Return a JSON object of `additionalAttributes` to apply to the created issue, or
# `{}` for none. Extend the case below per project (display-name -> customfield ID),
# mirroring epic-fields.sh's resolver. Keep it project-agnostic by default.
resolve_customfields() {
  local _project="$1"
  case "$_project" in
    # Example shape (commented out — wire real IDs when a project needs them):
    # PROJ) echo '{"customfield_1NNNN": {"value": "Example option"}}' ;;
    *) echo '{}' ;;
  esac
}

# Tenant-profile create attributes: every `create_attr.<customfield_id>` key in
# .specto/tracker-jira.yml is merged into additionalAttributes. A value that
# parses as JSON is used raw; anything else is wrapped as {"value": "<v>"}
# (Jira's option-field shape).
profile_create_attrs() {
  local repo profile
  repo="$(specto_repo_dir)"
  profile="$repo/.specto/tracker-jira.yml"
  if [[ -z "$repo" || ! -f "$profile" ]]; then echo '{}'; return 0; fi
  awk -F': *' 'index($0, "create_attr.") == 1 {
      key = substr($1, length("create_attr.") + 1)
      val = substr($0, length($1) + 2); sub(/^[[:space:]]*/, "", val); sub(/[[:space:]]+$/, "", val)
      gsub(/^"|"$/, "", val)
      printf "%s\t%s\n", key, val
    }' "$profile" \
  | jq -Rn '
      [inputs | split("\t") | {key: .[0], value: (.[1] as $v | ($v | fromjson? // {value: $v}))}]
      | from_entries'
}
# --------------------------------------------------------------------------------

# ----- fixture mode -----
if [[ -n "$FIXTURE" ]]; then
  [[ -f "$FIXTURE" ]] || { echo "fixture not found: $FIXTURE" >&2; exit 3; }
  RESP="$(cat "$FIXTURE")"
  echo "$RESP" | jq . >/dev/null 2>&1 || { echo "fixture JSON unparseable: $FIXTURE" >&2; exit 1; }
  NEW_KEY="$(echo "$RESP" | jq -r '.key // empty')"
  [[ -n "$NEW_KEY" ]] || { echo "no .key in create fixture: $FIXTURE" >&2; exit 1; }
  # Exercise the link loop against link-tickets.sh's fixture mode.
  LINK_FIXTURE="$HERE/tests/fixtures/link-ok.json"
  if [[ -n "${BLOCKS[*]+x}" ]]; then
    for k in "${BLOCKS[@]}"; do
      "$HERE/link-tickets.sh" "Blocks" "$NEW_KEY" "$k" --from-fixture "$LINK_FIXTURE" || { echo "link (Blocks) failed in fixture mode" >&2; exit 3; }
    done
  fi
  if [[ -n "${BLOCKED_BY[*]+x}" ]]; then
    for k in "${BLOCKED_BY[@]}"; do
      "$HERE/link-tickets.sh" "Blocks" "$k" "$NEW_KEY" --from-fixture "$LINK_FIXTURE" || { echo "link (BlockedBy) failed in fixture mode" >&2; exit 3; }
    done
  fi
  echo "$NEW_KEY"
  exit 0
fi

# ----- live mode -----
if ! command -v acli >/dev/null; then
  echo "acli not on PATH; install Atlassian CLI" >&2
  exit 3
fi

# ADF path: build a full --from-json payload (acli has no --description-adf-file
# flag, so the only way to ship an ADF description is via --from-json). The
# payload mirrors the standard path's behaviour: the `specto` label is always
# embedded, and the parent epic goes in additionalAttributes when --no-epic
# wasn't set. Without these, Test Plan tickets came out unlabeled and the
# post-create label edit was the only thing tagging them (sometimes silently
# failing — the path-divergence bug PR Reviewer Guide flagged).
if [[ -n "$ADF_FILE" ]]; then
  payload="$(mktemp -t specto-create.XXXXXX)"
  rm_payload() { [[ -f "$payload" ]] && rm -f "$payload"; }
  trap 'cleanup; rm_payload' EXIT
  ADF_FILE_ARG="$ADF_FILE" \
  PROJECT_ARG="$PROJECT" \
  TYPE_ARG="$TYPE" \
  SUMMARY_ARG="$SUMMARY" \
  EPIC_ARG="$($NO_EPIC && echo '' || echo "$EPIC_KEY")" \
  python3 - "$payload" <<'PYEOF'
import json, os, sys
out_path = sys.argv[1]
with open(os.environ["ADF_FILE_ARG"]) as f:
    description = json.load(f)
payload = {
    "projectKey": os.environ["PROJECT_ARG"],
    "type": os.environ["TYPE_ARG"],
    "summary": os.environ["SUMMARY_ARG"],
    "description": description,
    "labels": ["specto"],
}
epic = os.environ.get("EPIC_ARG", "")
if epic:
    payload["additionalAttributes"] = {"parent": {"key": epic}}
with open(out_path, "w") as f:
    json.dump(payload, f)
PYEOF
  RESP="$(acli jira workitem create --from-json "$payload" --json 2>/dev/null)" || {
    echo "acli create failed (--from-json) in $PROJECT (auth? project? type? ADF shape?)" >&2
    exit 3
  }
else
  # Standard path: --description-file + per-flag acli flags. Backward-compatible
  # with every existing caller (no --parent if --no-epic, --label specto always).
  create_args=(jira workitem create
    --type "$TYPE"
    --project "$PROJECT"
    --summary "$SUMMARY"
    --description-file "$DESC_FILE"
    --label "specto"
  )
  $NO_EPIC || create_args+=(--parent "$EPIC_KEY")
  create_args+=(--json)
  RESP="$(acli "${create_args[@]}" 2>/dev/null)" || {
    if $NO_EPIC; then
      echo "acli create failed in $PROJECT (auth? project? type?)" >&2
    else
      echo "acli create failed in $PROJECT under $EPIC_KEY (auth? project? epic key?)" >&2
    fi
    exit 3
  }
fi

# Parse the new key. acli --json returns the created issue object; tolerate a few shapes.
NEW_KEY="$(printf '%s' "$RESP" | jq -r '.key // .issueKey // (.issues[0].key) // empty' 2>/dev/null)"
if [[ -z "$NEW_KEY" ]]; then
  # Fall back to grepping a PROJ-NNN token out of the raw response.
  NEW_KEY="$(printf '%s' "$RESP" | grep -oE '[A-Z][A-Z0-9]+-[0-9]+' | head -1 || true)"
fi
if [[ -z "$NEW_KEY" ]]; then
  echo "created the ticket but could not parse its key from acli output: $RESP" >&2
  exit 1
fi

# Build the additionalAttributes payload: merge the resolve_customfields hook
# with any sprint/impact/priority values from the new flags. The merge is done
# in jq so the user-supplied values win on key collisions (a project map can
# still add fields the flags don't cover).
CF="$(resolve_customfields "$PROJECT")"
[[ -z "$CF" ]] && CF="{}"
PROFILE_ATTRS="$(profile_create_attrs)"
[[ -z "$PROFILE_ATTRS" ]] && PROFILE_ATTRS="{}"
ATTRS="$(jq -nc \
            --argjson cf "$CF" \
            --argjson pa "$PROFILE_ATTRS" \
            --arg sprint_field "$SPRINT_FIELD" \
            --arg impact_field "$IMPACT_FIELD" \
            --arg sprint "$SPRINT_ID" \
            --arg impact "$IMPACT_ID" \
            --arg priority "$PRIORITY_ID" \
            --arg priority_name "$PRIORITY_NAME" '
  $pa + $cf
  + (if $sprint   != "" then {($sprint_field): ($sprint | tonumber)} else {} end)
  + (if $impact   != "" and $impact_field != "" then {($impact_field): {id: $impact}} else {} end)
  + (if $priority != "" then {priority: {id: $priority}}
     elif $priority_name != "" then {priority: {name: $priority_name}}
     else {} end)
')"
if [[ -n "$ATTRS" && "$ATTRS" != "{}" ]]; then
  cf_json="$(mktemp -t specto-cf.XXXXXX)"
  printf '{"additionalAttributes": %s}\n' "$ATTRS" > "$cf_json"
  if ! acli jira workitem edit --key "$NEW_KEY" --from-json "$cf_json" --yes >/dev/null 2>&1; then
    # acli 1.3.19 rejects `--key` + `--from-json` together (mutually-exclusive flag
    # group [key jql filter generate-json from-json]), and this version cannot set
    # these custom fields via edit OR create. So the values below DID NOT apply.
    # Name exactly what was requested (and therefore dropped) so the caller knows.
    dropped=()
    [[ -n "$IMPACT_ID" ]]   && dropped+=("Impact")
    [[ -n "$PRIORITY_ID" ]] && dropped+=("Priority")
    [[ "$CF" != "{}" ]]     && dropped+=("custom fields (resolve_customfields)")
    dropped_list="$(IFS=', '; echo "${dropped[*]}")"
    {
      echo "############################################################################"
      echo "⚠️  WARNING: custom fields NOT applied to $NEW_KEY"
      echo "############################################################################"
      echo "The ticket WAS created, but these requested fields did NOT stick:"
      echo "    ${dropped_list:-additionalAttributes}"
      echo "Cause: acli 1.3.19 rejects 'edit --key --from-json' together (mutually-"
      echo "exclusive flag group), and this acli version cannot set these custom fields"
      echo "via edit OR create. They must be set manually in the Jira UI."
      echo "############################################################################"
    } >&2
  fi
  rm -f "$cf_json"
fi

# Apply extra labels (specto is already on the ticket from the create call). The
# create payload sometimes silently drops labels on certain Jira sites, so we
# apply them via a follow-up edit just like jira-create-ticket.sh did.
if (( ${#LABELS[@]} > 0 )); then
  joined="$(IFS=,; echo "${LABELS[*]}")"
  acli jira workitem edit --key "$NEW_KEY" --labels "$joined" --yes >/dev/null 2>&1 || \
    echo "warning: created $NEW_KEY but could not apply labels: $joined (continuing)" >&2
fi

# Assign to @me if requested (non-fatal — older acli versions may not support
# --yes on `assign`, and the ticket is otherwise fine).
if $ASSIGN; then
  acli jira workitem assign --key "$NEW_KEY" --assignee "@me" --yes >/dev/null 2>&1 || \
    echo "warning: created $NEW_KEY but could not assign to @me (continuing)" >&2
fi

# Create the links in the same invocation (B4).
#   --blocks K       => the new ticket BLOCKS K       => "$NEW_KEY blocks $k"
#   --blocked-by K   => the new ticket is BLOCKED BY K => "$k blocks $NEW_KEY"
# link-tickets.sh's positional contract is "$from $to" reading as
# "$from <outward-description> $to", so the order below is intentional.
if [[ -n "${BLOCKS[*]+x}" ]]; then
  for k in "${BLOCKS[@]}"; do
    "$HERE/link-tickets.sh" "Blocks" "$NEW_KEY" "$k" || { echo "created $NEW_KEY but failed to link Blocks->$k" >&2; exit 3; }
  done
fi
if [[ -n "${BLOCKED_BY[*]+x}" ]]; then
  for k in "${BLOCKED_BY[@]}"; do
    "$HERE/link-tickets.sh" "Blocks" "$k" "$NEW_KEY" || { echo "created $NEW_KEY but failed to link BlockedBy<-$k" >&2; exit 3; }
  done
fi

# Verify each Blocks/BlockedBy edge stored in the requested direction. acli's
# --in/--out flag names lie (see link-tickets.sh header) and its success
# message lies in the same direction, so the only trustworthy check is to
# re-read the issue and inspect inwardIssue/outwardIssue. One acli call covers
# every edge on this ticket. Best-effort: a fetch failure warns but does not
# fail the run (the create itself already succeeded).
# Bash-3.2 + set -u chokes on ${#ARR[@]} / "${ARR[@]}" for an EMPTY array, so the
# guard and the loops below use the ${ARR[*]+x} / ${ARR[@]+"${ARR[@]}"} forms —
# the bare forms made every live run with only one of --blocks/--blocked-by exit 1
# AFTER creating + linking.
if [[ -n "${BLOCKS[*]+x}${BLOCKED_BY[*]+x}" ]]; then
  links_json="$(acli jira workitem view "$NEW_KEY" --fields=issuelinks --json 2>/dev/null || true)"
  if [[ -z "$links_json" ]]; then
    echo "warning: created $NEW_KEY and links but could not verify link directions (acli view failed)" >&2
  else
    for k in ${BLOCKS[@]+"${BLOCKS[@]}"}; do
      if ! jq -e --arg k "$k" '
        .fields.issuelinks[]?
        | select(.type.name == "Blocks")
        | select(.outwardIssue.key == $k)
      ' <<<"$links_json" >/dev/null; then
        echo "ERROR: $NEW_KEY --blocks $k did not store in the requested direction; fix the link in Jira UI or re-run after deleting the wrong link" >&2
        exit 3
      fi
    done
    for k in ${BLOCKED_BY[@]+"${BLOCKED_BY[@]}"}; do
      if ! jq -e --arg k "$k" '
        .fields.issuelinks[]?
        | select(.type.name == "Blocks")
        | select(.inwardIssue.key == $k)
      ' <<<"$links_json" >/dev/null; then
        echo "ERROR: $NEW_KEY --blocked-by $k did not store in the requested direction; fix the link in Jira UI or re-run after deleting the wrong link" >&2
        exit 3
      fi
    done
  fi
fi

echo "$NEW_KEY"
