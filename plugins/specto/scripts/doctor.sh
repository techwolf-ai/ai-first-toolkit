#!/usr/bin/env bash
# Fail-loud preflight for the Specto toolchain.
#
# Checks the shell tooling, CLIs, auth, and config a run needs BEFORE it starts,
# so a skill never silently stops mid-flow when (say) jq is missing or the Jira
# board id isn't configured. Prints one line per check with a fix hint on failure.
#
# Two modes:
#   doctor.sh              full preflight: hard deps (bash, jq, git, curl),
#                          optional tools (jj, gh, glab, acli, python3,
#                          LINEAR_API_KEY), forge auth, and — only when the
#                          configured tracker is Jira — the Jira config keys.
#                          Backs the setup skill's doctor phase (/specto:setup
#                          --doctor).
#   doctor.sh --config-only
#                          check only the Jira config keys — no CLI presence,
#                          no auth, no network. Used by tests and by callers
#                          that just need the Jira config present.
#
# Exit: 0 all required checks pass · 1 a required check failed · 2 bad usage.

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$HERE/plugin-config.sh"

CONFIG_ONLY=0
case "${1:-}" in
  --config-only) CONFIG_ONLY=1 ;;
  "") ;;
  *) echo "usage: doctor.sh [--config-only]" >&2; exit 2 ;;
esac

fail=0
if [[ -t 1 ]]; then
  ok()   { printf '  \033[32mOK\033[0m    %s\n' "$1"; }
  bad()  { printf '  \033[31mFAIL\033[0m  %s\n        ↳ %s\n' "$1" "$2"; fail=1; }
  note() { printf '  \033[33m--\033[0m    %s\n' "$1"; }
else
  ok()   { printf '  OK    %s\n' "$1"; }
  bad()  { printf '  FAIL  %s\n        -> %s\n' "$1" "$2"; fail=1; }
  note() { printf '  --    %s\n' "$1"; }
fi

# os_hint <macos> <debian/ubuntu> <fedora> <windows-git-bash> — the install hint
# for the current platform. WSL reports Linux, so it takes the apt/dnf branch.
os_hint() {
  case "$(uname -s 2>/dev/null)" in
    Darwin)               printf '%s\n' "$1" ;;
    MINGW*|MSYS*|CYGWIN*) printf '%s\n' "$4" ;;
    *)
      if   command -v apt-get >/dev/null 2>&1; then printf '%s\n' "$2"
      elif command -v dnf     >/dev/null 2>&1; then printf '%s\n' "$3"
      else printf '%s\n' "$1 · $2 · $3"; fi
      ;;
  esac
}

# check_config <key> <label> <fix-hint> — a required machine-config value.
check_config() {
  if "$CONFIG" has "$1" >/dev/null 2>&1; then
    ok "config: $2 = $("$CONFIG" get "$1" 2>/dev/null)"
  else
    bad "config: $2 not set" "$3"
  fi
}

echo "specto doctor"

if [[ "$CONFIG_ONLY" -eq 1 ]]; then
  # Legacy preflight surface: just the Jira config keys, hard-required. Kept for
  # callers (and tests) that only need to know the Jira config is present.
  check_config jira_project  "Jira project key"                 "scripts/plugin-config.sh set jira_project <KEY>"
  check_config jira_board_id "Jira board id (sprint placement)" "scripts/plugin-config.sh set jira_board_id <ID>"
else
  # --- hard dependencies (a missing one stops any specto run) ------------------
  echo "hard dependencies"
  if command -v bash >/dev/null 2>&1; then
    ok "cli: bash ${BASH_VERSION%%(*}"
  else
    bad "cli: bash not on PATH" "$(os_hint 'brew install bash' 'sudo apt-get install -y bash' 'sudo dnf install bash' 'ships with Git for Windows')"
  fi
  if command -v jq >/dev/null 2>&1; then ok "cli: jq"; else
    bad "cli: jq not on PATH" "$(os_hint 'brew install jq' 'sudo apt-get install -y jq' 'sudo dnf install jq' 'winget install jqlang.jq')"; fi
  if command -v git >/dev/null 2>&1; then ok "cli: git"; else
    bad "cli: git not on PATH" "$(os_hint 'brew install git' 'sudo apt-get install -y git' 'sudo dnf install git' 'winget install Git.Git')"; fi
  if command -v curl >/dev/null 2>&1; then ok "cli: curl"; else
    bad "cli: curl not on PATH" "$(os_hint 'brew install curl' 'sudo apt-get install -y curl' 'sudo dnf install curl' 'winget install cURL.cURL')"; fi

  # --- optional tools (present = capability available; absent = never fatal) ---
  echo "optional tools"
  optional_cli() {  # <bin> <label> <what-it's-for>
    if command -v "$1" >/dev/null 2>&1; then ok "cli: $2"; else note "cli: $2 not found — $3"; fi
  }
  optional_cli jj      "jj (Jujutsu VCS)"     "only if this repo uses jj"
  optional_cli gh      "gh (GitHub CLI)"      "the github forge / GitHub Issues tracker"
  optional_cli glab    "glab (GitLab CLI)"    "the gitlab forge"
  optional_cli acli    "acli (Atlassian CLI)" "the jira tracker"
  optional_cli python3 "python3"              "Jira ADF rendering (jira tracker)"
  if [[ -n "${LINEAR_API_KEY:-}" ]]; then ok "env: LINEAR_API_KEY set"; else
    note "env: LINEAR_API_KEY not set — needed for the linear tracker"; fi

  # --- forge auth (advisory: reports state, never fatal on its own) ------------
  echo "forge auth"
  if ! command -v glab >/dev/null 2>&1 && ! command -v gh >/dev/null 2>&1; then
    note "auth: no forge CLI installed yet (glab or gh)"
  fi
  if command -v glab >/dev/null 2>&1; then
    if glab auth status >/dev/null 2>&1; then ok "auth: glab authenticated"; else
      note "auth: glab not authenticated — run 'glab auth login' if this repo uses GitLab"; fi
  fi
  if command -v gh >/dev/null 2>&1; then
    if gh auth status >/dev/null 2>&1; then ok "auth: gh authenticated"; else
      note "auth: gh not authenticated — run 'gh auth login' if this repo uses GitHub"; fi
  fi

  # --- tracker config (only the Jira tracker needs these keys) -----------------
  echo "tracker config"
  # Resolve the configured tracker without failing if it can't be determined;
  # the Jira keys are required only when Jira is actually the tracker.
  tracker=""
  if [[ -f "$HERE/lib/config.sh" ]]; then
    # shellcheck source=lib/config.sh
    . "$HERE/lib/config.sh"
    tracker="$(specto_tracker_backend 2>/dev/null || true)"
  fi
  if [[ "$tracker" == "jira" ]]; then
    check_config jira_project  "Jira project key"                 "scripts/plugin-config.sh set jira_project <KEY>"
    check_config jira_board_id "Jira board id (sprint placement)" "scripts/plugin-config.sh set jira_board_id <ID>"
  elif [[ -n "$tracker" ]]; then
    note "config: tracker is '$tracker' — Jira config keys not required"
  else
    note "config: tracker not configured yet — run /specto:setup (Jira keys apply only to the jira tracker)"
  fi
fi

echo
if [[ "$fail" -ne 0 ]]; then
  echo "doctor: one or more required checks FAILED — fix the above before running specto." >&2
  exit 1
fi
echo "doctor: all required checks passed."
