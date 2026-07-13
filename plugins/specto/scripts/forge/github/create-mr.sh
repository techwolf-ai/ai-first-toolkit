#!/usr/bin/env bash
# Create (or, idempotently, update) the pull request for the current branch.
# The title is passed through verbatim: the caller is responsible for
# formatting it (e.g. "[APP-1234] <ticket title>"). PRs are created as DRAFT;
# flip out of draft with mr-ready.sh.
#
# Idempotency: if a PR already exists for the current branch (`gh pr view
# <branch>` succeeds), this updates that PR (`gh pr edit`) instead of creating
# a duplicate.
#
# Usage:
#   create-mr.sh <title> <description-file|-> [--reviewer <user>]... [--assignee <user>]... [--target <branch>] [--source-branch <name>]
#   create-mr.sh <title> <description-file|-> [...] --from-fixture <dir>
#
# <description-file> may be "-" to read from stdin.
# --target defaults to the repo default branch (gh decides if omitted).
# --assignee defaults to "@me" when omitted: the implementer owns the PR by
#   default so it doesn't sit assignee-less; pass `--assignee` explicitly to
#   override (a single explicit `--assignee` replaces the @me default).
# --from-fixture <dir>: reads <dir>/mr.json: `{"exists": true, "number": 42, "url": "..."}`
#   or `{"exists": false}`: and prints, on a single line,
#       CREATE  (when exists=false)   or   UPDATE iid=<number>  (when exists=true)
#   without touching the network.
#
# Output (live): the PR web URL on stdout. Output (fixture): the CREATE/UPDATE line.
# Exit:
#   0: created / updated (or decision printed in fixture mode)
#   1: description body empty / unreadable
#   2: bad usage
#   3: gh not on PATH / not in a repo / the gh call failed

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

# Default the implementer as assignee so the PR doesn't land owner-less. A
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
  echo "PR description is empty" >&2
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
    echo "UPDATE iid=$(echo "$data" | jq -r '.number // .iid // "?"')"
  else
    echo "CREATE"
  fi
  exit 0
fi

# --- live mode --------------------------------------------------------------------
if ! command -v gh >/dev/null; then
  echo "gh not on PATH; install the GitHub CLI" >&2
  exit 3
fi

# Resolve the source branch explicitly so this works under jj-colocated
# detached HEAD (where gh's current-branch inference sees "HEAD").
BRANCH="$(specto_source_branch)" || {
  echo "could not resolve the source branch (detached HEAD with no branch ref?); pass --source-branch <name>" >&2
  exit 3
}

# Does a PR already exist for this branch?
if gh pr view "$BRANCH" --json number >/dev/null 2>&1; then
  # Update in place. gh pr edit has add-only people flags; title + body are
  # whole-replaced, matching the gitlab update semantics.
  update_args=(pr edit "$BRANCH" --title "$TITLE" --body-file -)
  for a in "${ASSIGNEES[@]}"; do update_args+=(--add-assignee "$a"); done
  if (( ${#REVIEWERS[@]} > 0 )); then
    for r in "${REVIEWERS[@]}"; do update_args+=(--add-reviewer "$r"); done
  fi
  if ! printf '%s' "$DESC" | gh "${update_args[@]}" >/dev/null 2>&1; then
    echo "gh pr edit failed for branch $BRANCH" >&2; exit 3
  fi
  gh pr view "$BRANCH" --json url --jq '.url' 2>/dev/null
  exit 0
fi

# Create a fresh draft PR.
create_args=(pr create --draft --title "$TITLE" --body-file - --head "$BRANCH" --assignee "$(IFS=,; echo "${ASSIGNEES[*]}")")
if (( ${#REVIEWERS[@]} > 0 )); then
  create_args+=(--reviewer "$(IFS=,; echo "${REVIEWERS[*]}")")
fi
if [[ -n "$TARGET" ]]; then
  create_args+=(--base "$TARGET")
fi
if ! printf '%s' "$DESC" | gh "${create_args[@]}" >/dev/null 2>&1; then
  echo "gh pr create failed for branch $BRANCH (uncommitted/unpushed branch? auth?)" >&2; exit 3
fi
gh pr view "$BRANCH" --json url --jq '.url' 2>/dev/null
