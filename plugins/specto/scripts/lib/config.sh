# Sourceable config library: backend selection + flat-YAML reading.
#
# Backend selection precedence (each domain):
#   1. env var            (SPECTO_FORGE / SPECTO_TRACKER / SPECTO_VCS)
#   2. repo config        (.specto/config.yml key forge:/tracker:/vcs:, walking
#                          up from $PWD to the repo root)
#   3. machine default    (plugin-config.sh get forge|tracker|vcs)
#   4. autodetect         (git remote host; tracker heuristics; jj root)
#
# .specto/config.yml (and every .specto/*.yml Specto reads in shell) is
# constrained to flat `key: value` scalar lines — no nesting, no lists. The
# model may read richer YAML in prompts; shell code only ever needs flat keys.
#
# Functions return the value on stdout. Selection functions exit 3 with
# guidance on stderr when no backend can be determined.

SPECTO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPECTO_PLUGIN_CONFIG="$SPECTO_LIB_DIR/../plugin-config.sh"

# specto_yaml_get <file> <key> — flat `key: value` lookup; empty when absent.
# Field comparison (not regex) so keys with metacharacters can't cross-match.
specto_yaml_get() {
  local file="$1" key="$2"
  [[ -f "$file" ]] || return 0
  awk -v k="$key" -F': *' '
    index($0, k":") == 1 {
      val = substr($0, length(k) + 2)
      sub(/^[[:space:]]*/, "", val); sub(/[[:space:]]+$/, "", val)
      gsub(/^"|"$/, "", val); gsub(/^'\''|'\''$/, "", val)
      print val; exit
    }' "$file"
}

# specto_repo_dir — nearest ancestor (from $PWD) carrying a .specto/ dir.
# The walk stops at the first repo boundary (.git or .jj) it crosses, so a
# stray .specto/ in $HOME can never configure unrelated repos below it; with
# no repo marker anywhere the walk continues to /.
specto_repo_dir() {
  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    if [[ -d "$dir/.specto" ]]; then
      echo "$dir"
      return 0
    fi
    [[ -e "$dir/.git" || -e "$dir/.jj" ]] && return 0
    dir="$(dirname "$dir")"
  done
  return 0
}

# specto_repo_config_file — the repo's .specto/config.yml, if present.
specto_repo_config_file() {
  local repo
  repo="$(specto_repo_dir)"
  [[ -n "$repo" && -f "$repo/.specto/config.yml" ]] && echo "$repo/.specto/config.yml"
  return 0
}

# specto_config_get <key> — repo config first, then machine config; empty if unset.
specto_config_get() {
  local key="$1" val="" repo_cfg
  repo_cfg="$(specto_repo_config_file)"
  [[ -n "$repo_cfg" ]] && val="$(specto_yaml_get "$repo_cfg" "$key")"
  if [[ -z "$val" && -x "$SPECTO_PLUGIN_CONFIG" ]]; then
    val="$("$SPECTO_PLUGIN_CONFIG" get "$key" 2>/dev/null || true)"
  fi
  echo "$val"
}

# _specto_remote_host — hostname of the origin remote, if any.
_specto_remote_host() {
  local url
  url="$(git remote get-url origin 2>/dev/null || true)"
  [[ -z "$url" ]] && return 0
  case "$url" in
    git@*)     echo "$url" | sed -E 's|^git@([^:]+):.*|\1|' ;;
    ssh://*)   echo "$url" | sed -E 's|^ssh://(git@)?([^/:]+).*|\2|' ;;
    http*://*) echo "$url" | sed -E 's|^https?://([^/]+)/.*|\1|' ;;
  esac
}

specto_forge_backend() {
  local backend="${SPECTO_FORGE:-}"
  [[ -z "$backend" ]] && backend="$(specto_config_get forge)"
  if [[ -z "$backend" ]]; then
    local host
    host="$(_specto_remote_host)"
    case "$host" in
      github.com) backend=github ;;
      gitlab.*|*.gitlab.com) backend=gitlab ;;
      *)
        if [[ -n "$host" ]] && command -v glab >/dev/null 2>&1 \
           && glab config get -h "$host" token >/dev/null 2>&1; then
          backend=gitlab
        fi
        ;;
    esac
  fi
  if [[ -z "$backend" ]]; then
    echo "specto: cannot determine forge backend. Run /specto:setup, or set SPECTO_FORGE / 'forge:' in .specto/config.yml." >&2
    return 3
  fi
  echo "$backend"
}

specto_tracker_backend() {
  local backend="${SPECTO_TRACKER:-}"
  [[ -z "$backend" ]] && backend="$(specto_config_get tracker)"
  if [[ -z "$backend" ]]; then
    local repo_dir
    repo_dir="$(specto_repo_dir)"
    if [[ -n "$repo_dir" ]]; then
      if [[ -f "$repo_dir/.specto/tracker-jira.yml" ]] \
         || [[ -n "$(specto_yaml_get "$repo_dir/.specto/config.yml" jira_project_key)" ]]; then
        backend=jira
      fi
    fi
    if [[ -z "$backend" && -n "${LINEAR_API_KEY:-}" ]]; then backend=linear; fi
    if [[ -z "$backend" ]]; then
      local forge; forge="$(SPECTO_FORGE="${SPECTO_FORGE:-}" specto_forge_backend 2>/dev/null || true)"
      [[ "$forge" == github ]] && backend=github
    fi
  fi
  if [[ -z "$backend" ]]; then
    echo "specto: cannot determine tracker backend. Run /specto:setup, or set SPECTO_TRACKER / 'tracker:' in .specto/config.yml." >&2
    return 3
  fi
  echo "$backend"
}

specto_vcs_backend() {
  local backend="${SPECTO_VCS:-}"
  [[ -z "$backend" ]] && backend="$(specto_config_get vcs)"
  if [[ -z "$backend" ]]; then
    if command -v jj >/dev/null 2>&1 && jj root >/dev/null 2>&1; then
      backend=jj
    else
      backend=git
    fi
  fi
  echo "$backend"
}
