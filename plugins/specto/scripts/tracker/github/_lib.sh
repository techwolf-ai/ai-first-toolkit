# Shared helpers for the GitHub Issues tracker backend. Sourced, not executed.
#
# Ticket keys on this backend are bare issue numbers ("123"); gh resolves them
# against the current repo checkout, or against $GH_REPO when a caller exported
# an owner/repo override (create-ticket.sh does this when its <project> arg is
# owner/repo-shaped). Sourcing this file has no side effects.

# Exit 3 with guidance when the gh CLI is missing (live mode only).
specto_require_gh() {
  if ! command -v gh >/dev/null; then
    echo "gh not on PATH; install the GitHub CLI (https://cli.github.com)" >&2
    exit 3
  fi
}

# repos/<owner>/<repo> path segment for `gh api` calls. An explicit owner/repo
# argument wins; otherwise gh's own {owner}/{repo} placeholders resolve from
# the current repo checkout (and honor $GH_REPO), so live calls work from
# anywhere inside the repo with zero config.
specto_gh_repo_path() {
  local explicit="${1:-}"
  if [[ -n "$explicit" && "$explicit" == */* ]]; then
    printf 'repos/%s' "$explicit"
  else
    printf 'repos/{owner}/{repo}'
  fi
}
