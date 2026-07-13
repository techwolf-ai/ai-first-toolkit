#!/usr/bin/env bash
# Shared VCS helpers for the specto scripts. Source it, don't execute it.
# Defines functions only — no side effects on source.
#
# VCS has a single live implementation set: the plain-git vs jj-colocated
# switching happens INSIDE each function, so callers (forge impls, the thin
# scripts/vcs/*.sh wrappers) never dispatch on a backend.

# Resolve the branch glab should target for MR operations.
#
# `glab mr view/update/create` infer the source branch from the current git
# branch (`git rev-parse --abbrev-ref HEAD`). Under jj colocated with git, HEAD
# stays DETACHED after `jj git push` — that inference returns the literal
# "HEAD" and every MR call fails, even though the bookmark exists in
# refs/heads/<name> and is visible on origin.
#
# Resolution order:
#   1. $SOURCE_BRANCH if set (explicit override, e.g. create-mr.sh --source-branch).
#   2. The current git branch (symbolic-ref) — the normal plain-git case.
#   3. The jj bookmark on @ (then @-) — jj keeps git HEAD detached at the PARENT
#      commit while the bookmark lives on the working-copy commit, so a git
#      `--points-at HEAD` probe never finds it; ask jj directly.
#   4. A local branch ref pointing at git HEAD — last-resort plain-git detached case.
#
# Prints the branch name on stdout. Returns 1 (prints nothing) if none resolve.
specto_source_branch() {
  if [[ -n "${SOURCE_BRANCH:-}" ]]; then
    printf '%s\n' "$SOURCE_BRANCH"
    return 0
  fi
  local b
  if b="$(git symbolic-ref --quiet --short HEAD 2>/dev/null)" && [[ -n "$b" ]]; then
    printf '%s\n' "$b"
    return 0
  fi
  if command -v jj >/dev/null 2>&1; then
    local rev
    for rev in '@' '@-'; do
      b="$(jj log --no-graph -r "$rev" -T 'bookmarks.map(|x| x.name()).join("\n")' 2>/dev/null | head -1)"
      if [[ -n "$b" ]]; then
        printf '%s\n' "$b"
        return 0
      fi
    done
  fi
  b="$(git for-each-ref --points-at HEAD --format='%(refname:short)' refs/heads/ 2>/dev/null | head -1)"
  if [[ -n "$b" ]]; then
    printf '%s\n' "$b"
    return 0
  fi
  return 1
}

# Resolve the default branch ("trunk") for the current checkout.
#
# Resolution order:
#   1. $TRUNK if set (explicit override).
#   2. git's origin/HEAD symbolic ref (set on clone; repairable with
#      `git remote set-head origin --auto`).
#   3. The jj trunk() revset alias, when the checkout is a jj workspace and the
#      alias names a plain `<branch>@<remote>` target. Composite revsets (jj's
#      shipped default is one) don't name a single branch; fall through.
#   4. An existence probe for origin/main, then origin/master.
#
# Prints the branch name on stdout. Returns 1 (prints nothing) if none resolve.
specto_trunk() {
  if [[ -n "${TRUNK:-}" ]]; then
    printf '%s\n' "$TRUNK"
    return 0
  fi
  local ref
  if ref="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)" && [[ -n "$ref" ]]; then
    printf '%s\n' "${ref#origin/}"
    return 0
  fi
  if command -v jj >/dev/null 2>&1 && jj root >/dev/null 2>&1; then
    local trunk_alias
    trunk_alias="$(jj config get 'revset-aliases."trunk()"' 2>/dev/null)"
    if [[ "$trunk_alias" =~ ^([A-Za-z0-9._/-]+)@ ]]; then
      printf '%s\n' "${BASH_REMATCH[1]}"
      return 0
    fi
  fi
  local b
  for b in main master; do
    if git show-ref --verify --quiet "refs/remotes/origin/$b" 2>/dev/null; then
      printf '%s\n' "$b"
      return 0
    fi
  done
  return 1
}

# Print the unified diff of trunk...HEAD (the branch's own changes).
#
# On a jj workspace: `jj diff --git -r "trunk()..@"` (--git renders the
# git-format unified diff; jj's default output is its own color-words format).
# If jj is absent, the checkout is not a jj workspace, or the jj diff fails,
# fall back to plain git: `git diff <trunk>...HEAD` (triple-dot, so the diff is
# taken against the merge base, not against a moved trunk tip).
#
# Returns non-zero (via git) when no trunk resolves or the diff itself fails.
specto_branch_diff() {
  if command -v jj >/dev/null 2>&1 && jj root >/dev/null 2>&1; then
    if jj diff --git -r 'trunk()..@' 2>/dev/null; then
      return 0
    fi
  fi
  local trunk
  trunk="$(specto_trunk)" || return 1
  git diff "$trunk...HEAD"
}
