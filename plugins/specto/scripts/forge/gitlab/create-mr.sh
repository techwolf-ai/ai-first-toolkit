#!/usr/bin/env bash
# Create (or, idempotently, update) the merge request for the current branch.
# `glab mr create` has NO --description-file flag, so the description file is read
# into memory and passed via -d. The title is passed through verbatim — the caller
# is responsible for formatting it (e.g. "[APP-1234] <ticket title>"). MRs are
# created as DRAFT; flip out of draft with mr-ready.sh.
#
# Idempotency: if an MR already exists for the current branch (`glab mr view`
# succeeds), this updates that MR (`glab mr update --title … -d …`) instead of
# creating a duplicate.
#
# Usage:
#   create-mr.sh <title> <description-file|-> [--reviewer <user>]... [--assignee <user>]... [--target <branch>]
#   create-mr.sh <title> <description-file|-> [...] --from-fixture <dir>
#
# <description-file> may be "-" to read from stdin.
# --target defaults to the repo default branch (glab decides if omitted).
# --assignee defaults to "@me" when omitted — the implementer owns the MR by
#   default so it doesn't sit assignee-less; pass `--assignee` explicitly to
#   override (a single explicit `--assignee` replaces the @me default).
# --from-fixture <dir>: reads <dir>/mr.json — `{"exists": true, "iid": 42, "web_url": "..."}`
#   or `{"exists": false}` — and prints, on a single line,
#       CREATE  (when exists=false)   or   UPDATE iid=<iid>  (when exists=true)
#   without touching the network.
#
# Output (live): the MR web URL on stdout. Output (fixture): the CREATE/UPDATE line.
# Exit:
#   0 — created / updated (or decision printed in fixture mode)
#   1 — description body empty / unreadable
#   2 — bad usage
#   3 — glab not on PATH / not in a repo / the glab call failed

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
. "$SCRIPT_DIR/_lib.sh"

usage() {
  echo "usage: create-mr.sh <title> <description-file|-> [--reviewer <user>]... [--assignee <user>]... [--target <branch>] [--source-branch <name>] [--from-fixture <dir>]" >&2
  exit 2
}

[[ $# -lt 2 ]] && usage
TITLE="$1"
DESC_SRC="$2"
shift 2

REVIEWERS=()
ASSIGNEES=()
TARGET=""
FIXTURE_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --reviewer)      [[ $# -ge 2 ]] || usage; REVIEWERS+=("$2"); shift 2 ;;
    --assignee)      [[ $# -ge 2 ]] || usage; ASSIGNEES+=("$2"); shift 2 ;;
    --target)        [[ $# -ge 2 ]] || usage; TARGET="$2"; shift 2 ;;
    --source-branch) [[ $# -ge 2 ]] || usage; SOURCE_BRANCH="$2"; shift 2 ;;
    --from-fixture)  [[ $# -ge 2 ]] || usage; FIXTURE_DIR="$2"; shift 2 ;;
    *)               usage ;;
  esac
done

# Default the implementer as assignee so the MR doesn't land owner-less. A
# caller passing one or more explicit --assignee replaces this default.
if (( ${#ASSIGNEES[@]} == 0 )); then
  ASSIGNEES=("@me")
fi

# Read the description.
if [[ "$DESC_SRC" == "-" ]]; then
  DESC="$(cat)"
else
  [[ -f "$DESC_SRC" ]] || { echo "description file not found: $DESC_SRC" >&2; exit 2; }
  DESC="$(cat "$DESC_SRC")"
fi
if [[ -z "${DESC//[[:space:]]/}" ]]; then
  echo "MR description is empty" >&2
  exit 1
fi

# --- fixture mode -----------------------------------------------------------------
if [[ -n "$FIXTURE_DIR" ]]; then
  [[ -d "$FIXTURE_DIR" ]] || { echo "fixture dir not found: $FIXTURE_DIR" >&2; exit 3; }
  f="$FIXTURE_DIR/mr.json"
  [[ -f "$f" ]] || { echo "fixture file not found: $f" >&2; exit 3; }
  data="$(cat "$f")"
  echo "$data" | jq . >/dev/null 2>&1 || { echo "fixture JSON unparseable: $f" >&2; exit 3; }
  exists="$(echo "$data" | jq -r '.exists // false')"
  if [[ "$exists" == "true" ]]; then
    echo "UPDATE iid=$(echo "$data" | jq -r '.iid // "?"')"
  else
    echo "CREATE"
  fi
  exit 0
fi

# --- live mode --------------------------------------------------------------------
if ! command -v glab >/dev/null; then
  echo "glab not on PATH; install the GitLab CLI" >&2
  exit 3
fi

# Resolve the source branch explicitly so this works under jj-colocated
# detached HEAD (where glab's current-branch inference returns "HEAD").
BRANCH="$(specto_source_branch)" || {
  echo "could not resolve the source branch (detached HEAD with no branch ref?); pass --source-branch <name>" >&2
  exit 3
}

# Does an MR already exist for this branch?
if glab mr view "$BRANCH" --output json >/dev/null 2>&1; then
  # Update in place.
  update_args=(mr update "$BRANCH" --title "$TITLE" -d "$DESC" --assignee "$(IFS=,; echo "${ASSIGNEES[*]}")")
  if (( ${#REVIEWERS[@]} > 0 )); then
    update_args+=(--reviewer "$(IFS=,; echo "${REVIEWERS[*]}")")
  fi
  if ! glab "${update_args[@]}" >/dev/null 2>&1; then
    echo "glab mr update failed for branch $BRANCH" >&2; exit 3
  fi
  mr_json="$(glab mr view "$BRANCH" --output json 2>/dev/null)"
  jq -r '.web_url // empty' <<<"$mr_json"
  exit 0
fi

# Create a fresh draft MR.
create_args=(mr create --draft --title "$TITLE" -d "$DESC" --source-branch "$BRANCH" --assignee "$(IFS=,; echo "${ASSIGNEES[*]}")" --yes)
if (( ${#REVIEWERS[@]} > 0 )); then
  create_args+=(--reviewer "$(IFS=,; echo "${REVIEWERS[*]}")")
fi
if [[ -n "$TARGET" ]]; then
  create_args+=(--target-branch "$TARGET")
fi
if ! glab "${create_args[@]}" >/dev/null 2>&1; then
  echo "glab mr create failed for branch $BRANCH (uncommitted/unpushed branch? auth?)" >&2; exit 3
fi
mr_json="$(glab mr view "$BRANCH" --output json 2>/dev/null)"
jq -r '.web_url // empty' <<<"$mr_json"
