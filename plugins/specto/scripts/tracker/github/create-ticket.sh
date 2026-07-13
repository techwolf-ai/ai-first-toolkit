#!/usr/bin/env bash
# Create a GitHub issue (this backend's "ticket"), and (in the SAME invocation)
# create any blocks / blocked-by dependency edges, so a partial create can never
# leave a missing link. Mirrors tracker/jira/create-ticket.sh argv exactly; this
# is the one vetted `gh issue create` call for the tracker domain.
#
# Usage (identical to the jira counterpart):
#   create-ticket.sh <project> <epic-key|-> <summary> <description-file|-> \
#       [--type <T>] [--no-epic] [--label <n>]... [--sprint-id <id>]       \
#       [--impact <v>] [--priority <v>] [--description-adf-file <path>]    \
#       [--assign] [--blocks <KEY>]... [--blocked-by <KEY>]...             \
#       [--from-fixture <path>]
#
# GitHub mapping (see README.md in this dir):
#   <project>      owner/repo targets that repo (exported as GH_REPO for every
#                  gh call in this invocation, sibling helpers included); any
#                  other value (a Jira-style project key like "PROJ") is
#                  accepted and IGNORED: the current repo checkout is the
#                  project on this backend.
#   <epic-key|->   parent issue number, attached post-create via the sibling
#                  set-parent.sh (native sub-issues, gh >= 2.94). "-" or
#                  --no-epic creates a standalone issue.
#   <desc-file|->  markdown, passed through UNTOUCHED (gh is markdown-native;
#                  there is no ADF path on this backend). "-" reads stdin.
#   --type         best-effort `gh issue edit --type` after create when it is
#                  not the default "Task" (native issue types; a repo without
#                  types configured warns instead of failing).
#   --label        repeatable; the `specto` label is always applied on top.
#                  gh does not auto-create labels, so a rejected create gets
#                  one retry after best-effort `gh label create` per label.
#   --sprint-id    milestone number; placed via the sibling add-to-sprint.sh
#                  (sprint = milestone, this backend's documented degradation).
#                  Best-effort: a placement failure warns, the issue stands.
#   --impact/--priority  become labels `impact:<v>` / `priority:<v>` (value
#                  lowercased): GitHub issues have no impact/priority fields.
#   --description-adf-file  NOT SUPPORTED (exit 4): ADF is Jira-internal.
#   --assign       adds `--assignee @me` on the create call.
#   --blocks K     the new issue blocks K, i.e. K is blocked by it
#                    -> link-tickets.sh blocks <new> K
#   --blocked-by K the new issue is blocked by K
#                    -> link-tickets.sh blocks K <new>
#
# --from-fixture <path>: the fixture is the JSON `gh issue view --json number`
# would return for the created issue (e.g. {"number": 1234}); the helper prints
# that number and exercises the parent + link loop against the sibling helpers'
# own fixture modes.
#
# Output: the new issue number on stdout (nothing else). Warnings to stderr.
# Exit:
#   0 - issue created and all links created
#   1 - create succeeded but the number could not be parsed from gh output
#   2 - bad usage
#   3 - gh not on PATH, create failed, or a parent/link attach failed
#   4 - --description-adf-file requested (ADF is unsupported on github)

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/_lib.sh"

usage() {
  echo "usage: create-ticket.sh <project> <epic-key|-> <summary> <description-file|-> [--type <T>] [--no-epic] [--label <n>]... [--sprint-id <id>] [--impact <v>] [--priority <v>] [--description-adf-file <path>] [--assign] [--blocks <KEY>]... [--blocked-by <KEY>]... [--from-fixture <path>]" >&2
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

# ADF is a Jira-internal body format; markdown is native here. A static
# capability gap, so exit 4 even in fixture mode (docs/contracts.md).
if [[ -n "$ADF_FILE" ]]; then
  echo "not supported on github: --description-adf-file (ADF is Jira-internal; pass markdown)" >&2
  exit 4
fi

# --no-epic is equivalent to passing "-" for the positional epic key.
[[ "$EPIC_KEY" == "-" ]] && NO_EPIC=true

# An owner/repo project targets that repo for EVERY gh call below (the create,
# the follow-up edits, and the sibling helpers). Anything else means "the
# current repo checkout is the project" and is deliberately ignored.
if [[ "$PROJECT" == */* ]]; then
  export GH_REPO="$PROJECT"
fi

# Impact / priority map to labels (lowercased value): impact:high, priority:urgent.
EXTRA_LABELS=()
[[ -n "$IMPACT_RAW" ]]   && EXTRA_LABELS+=("impact:$(printf '%s' "$IMPACT_RAW" | tr '[:upper:]' '[:lower:]')")
[[ -n "$PRIORITY_RAW" ]] && EXTRA_LABELS+=("priority:$(printf '%s' "$PRIORITY_RAW" | tr '[:upper:]' '[:lower:]')")

# Resolve the description body. Markdown in, markdown out: no conversion step.
DESC_FILE=""
DESC_FILE_IS_TEMP=false
ERR_TMP=""
cleanup() {
  $DESC_FILE_IS_TEMP && [[ -n "$DESC_FILE" && -f "$DESC_FILE" ]] && rm -f "$DESC_FILE"
  [[ -n "$ERR_TMP" && -f "$ERR_TMP" ]] && rm -f "$ERR_TMP"
  return 0
}
trap cleanup EXIT
if [[ "$DESC_SRC" == "-" ]]; then
  DESC_FILE="$(mktemp -t specto-desc.XXXXXX)"
  DESC_FILE_IS_TEMP=true
  cat > "$DESC_FILE"
else
  [[ -f "$DESC_SRC" ]] || { echo "description file not found: $DESC_SRC" >&2; exit 2; }
  DESC_FILE="$DESC_SRC"
fi

# ----- fixture mode -----
if [[ -n "$FIXTURE" ]]; then
  [[ -f "$FIXTURE" ]] || { echo "fixture not found: $FIXTURE" >&2; exit 3; }
  RESP="$(cat "$FIXTURE")"
  echo "$RESP" | jq . >/dev/null 2>&1 || { echo "fixture JSON unparseable: $FIXTURE" >&2; exit 1; }
  NEW_KEY="$(echo "$RESP" | jq -r '.number // empty')"
  [[ -n "$NEW_KEY" ]] || { echo "no .number in create fixture: $FIXTURE" >&2; exit 1; }
  # Exercise the parent attach + link loop against the siblings' fixture modes.
  OK_FIXTURE="$HERE/tests/fixtures/link-ok.json"
  if ! $NO_EPIC; then
    "$HERE/set-parent.sh" "$NEW_KEY" "$EPIC_KEY" --from-fixture "$OK_FIXTURE" || { echo "set-parent failed in fixture mode" >&2; exit 3; }
  fi
  for k in ${BLOCKS[@]+"${BLOCKS[@]}"}; do
    "$HERE/link-tickets.sh" blocks "$NEW_KEY" "$k" --from-fixture "$OK_FIXTURE" || { echo "link (blocks) failed in fixture mode" >&2; exit 3; }
  done
  for k in ${BLOCKED_BY[@]+"${BLOCKED_BY[@]}"}; do
    "$HERE/link-tickets.sh" blocks "$k" "$NEW_KEY" --from-fixture "$OK_FIXTURE" || { echo "link (blocked-by) failed in fixture mode" >&2; exit 3; }
  done
  echo "$NEW_KEY"
  exit 0
fi

# ----- live mode -----
specto_require_gh

ALL_LABELS=("specto" ${LABELS[@]+"${LABELS[@]}"} ${EXTRA_LABELS[@]+"${EXTRA_LABELS[@]}"})
create_args=(issue create --title "$SUMMARY" --body-file "$DESC_FILE")
for l in "${ALL_LABELS[@]}"; do create_args+=(--label "$l"); done
$ASSIGN && create_args+=(--assignee "@me")

# gh issue create prints the new issue URL on stdout. gh does NOT auto-create
# labels (unlike Jira's freeform labels), so a rejected create gets exactly one
# retry after best-effort `gh label create` for each requested label.
ERR_TMP="$(mktemp -t specto-create-err.XXXXXX)"
if ! CREATE_OUT="$(gh "${create_args[@]}" 2>"$ERR_TMP")"; then
  for l in "${ALL_LABELS[@]}"; do
    gh label create "$l" --color ededed --description "created by specto" >/dev/null 2>&1 || true
  done
  if ! CREATE_OUT="$(gh "${create_args[@]}" 2>"$ERR_TMP")"; then
    echo "gh issue create failed (auth? repo? labels?): $(tail -1 "$ERR_TMP" 2>/dev/null)" >&2
    exit 3
  fi
fi

# The URL's trailing segment is the new issue number.
NEW_KEY="$(printf '%s\n' "$CREATE_OUT" | grep -oE '[0-9]+$' | tail -1 || true)"
if [[ -z "$NEW_KEY" ]]; then
  echo "created the issue but could not parse its number from gh output: $CREATE_OUT" >&2
  exit 1
fi

# Native issue type, best-effort: repos without issue types configured (or a
# type name the org does not define) warn instead of failing the create.
if [[ "$TYPE" != "Task" ]]; then
  gh issue edit "$NEW_KEY" --type "$TYPE" >/dev/null 2>&1 || \
    echo "warning: created #$NEW_KEY but could not set issue type '$TYPE' (issue types not configured on this repo?)" >&2
fi

# Parent attach (native sub-issue). A bad epic is a hard failure, mirroring the
# jira backend where create-under-epic fails outright.
if ! $NO_EPIC; then
  "$HERE/set-parent.sh" "$NEW_KEY" "$EPIC_KEY" || { echo "created #$NEW_KEY but failed to attach parent #$EPIC_KEY" >&2; exit 3; }
fi

# Sprint placement = milestone placement (documented degradation). Best-effort,
# mirroring the jira backend's warn-and-continue sprint behaviour.
if [[ -n "$SPRINT_ID" ]]; then
  "$HERE/add-to-sprint.sh" "$SPRINT_ID" "$NEW_KEY" || \
    echo "warning: created #$NEW_KEY but could not place it in milestone $SPRINT_ID (continuing)" >&2
fi

# Dependency edges in the same invocation (see the header for direction).
for k in ${BLOCKS[@]+"${BLOCKS[@]}"}; do
  "$HERE/link-tickets.sh" blocks "$NEW_KEY" "$k" || { echo "created #$NEW_KEY but failed to link blocks->$k" >&2; exit 3; }
done
for k in ${BLOCKED_BY[@]+"${BLOCKED_BY[@]}"}; do
  "$HERE/link-tickets.sh" blocks "$k" "$NEW_KEY" || { echo "created #$NEW_KEY but failed to link blocked-by<-$k" >&2; exit 3; }
done

echo "$NEW_KEY"
