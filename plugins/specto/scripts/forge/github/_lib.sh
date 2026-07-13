#!/usr/bin/env bash
# Shared helpers for the specto github forge scripts. Source it, don't execute it.
# Defines functions only: no side effects on source.
#
# specto_source_branch (git + jj-colocated source-branch resolution) is VCS
# logic, not GitHub logic; it lives in scripts/vcs/_lib.sh and is re-sourced
# here so every github helper keeps its single `. "$SCRIPT_DIR/_lib.sh"` line.

# shellcheck source=../../vcs/_lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../vcs/_lib.sh"

# Resolve "owner/repo" for the current checkout, once per process (cached in
# SPECTO_GH_REPO; settable up front by tests). `gh repo view` respects the
# authed default; the origin-remote parse is the offline fallback.
specto_gh_repo() {
  if [[ -n "${SPECTO_GH_REPO:-}" ]]; then
    printf '%s\n' "$SPECTO_GH_REPO"
    return 0
  fi
  local r
  r="$(gh repo view --json owner,name --jq '.owner.login + "/" + .name' 2>/dev/null)" || r=""
  if [[ -z "$r" || "$r" == "/" ]]; then
    r="$(git remote get-url origin 2>/dev/null \
           | sed -E 's#^(git@[^:]+:|ssh://git@[^/]+/|https?://[^/]+/)##; s#\.git$##')"
  fi
  [[ -n "$r" ]] || return 1
  SPECTO_GH_REPO="$r"
  printf '%s\n' "$r"
}

# Resolve the PR number for an explicit iid (passthrough), an explicit branch,
# or the current source branch. Prints the number; returns 1 when nothing
# resolves (caller owns the error message).
#   specto_gh_pr_number [iid] [branch]
specto_gh_pr_number() {
  local iid="${1:-}" branch="${2:-}" n
  if [[ -n "$iid" ]]; then
    printf '%s\n' "$iid"
    return 0
  fi
  if [[ -z "$branch" ]]; then
    branch="$(specto_source_branch)" || return 1
  fi
  n="$(gh pr view "$branch" --json number --jq '.number' 2>/dev/null)" || n=""
  [[ -n "$n" ]] || return 1
  printf '%s\n' "$n"
}

# jq filter mapping a `gh pr view --json …` object to the normalized
# change-request shape (docs/adapter-contract.md). GitHub has no distinct
# start SHA, so base_sha = start_sha = baseRefOid. `description` (from .body)
# is an extra, backend-emitted field mr-describe.sh relies on.
SPECTO_GH_INFO_JQ='
  def st: (.state // "") | ascii_downcase | if . == "open" then "opened" else . end;
  {
    iid: .number,
    web_url: .url,
    title: .title,
    state: st,
    draft: (.isDraft // false),
    source_branch: (.headRefName // ""),
    target_branch: (.baseRefName // ""),
    description: (.body // ""),
    diff_refs: {
      base_sha:  (.baseRefOid // ""),
      start_sha: (.baseRefOid // ""),
      head_sha:  (.headRefOid // "")
    }
  }'
