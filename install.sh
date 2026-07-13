#!/usr/bin/env bash
set -euo pipefail

IDE="codex"
TARGET=""
ACTION="install"
PLUGIN=""
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATE_DIR_NAME=".techwolf-ai-first"

# Default install dir per IDE. An explicit --target overrides either.
#   codex:       ~/.codex/skills        flat per-skill dirs: <target>/<skill>/
#   antigravity: ~/.gemini/config/plugins  one dir per plugin, preserving the
#                plugin shape Antigravity expects:
#                  <target>/<plugin>/plugin.json
#                  <target>/<plugin>/installed_version.json
#                  <target>/<plugin>/skills/<skill>/SKILL.md
# Skills are staged identically in both (plugin-root shared assets copied next to
# each SKILL.md); only the surrounding directory shape differs.
default_target_for_ide() {
  case "$1" in
    codex) echo "${HOME}/.codex/skills" ;;
    antigravity) echo "${HOME}/.gemini/config/plugins" ;;
    *) echo "" ;;
  esac
}

usage() {
  cat <<'EOF'
Usage:
  ./install.sh [install|update|uninstall|verify|list] [plugin] [--ide <codex|antigravity>] [--target <dir>]

Targets:
  --ide codex        Install into ~/.codex/skills (default)
  --ide antigravity  Install into ~/.gemini/config/plugins (Antigravity)
  --target <dir>     Override the install dir for either IDE

Examples:
  ./install.sh
  ./install.sh content-studio
  ./install.sh install ai-firstify
  ./install.sh install ai-firstify --ide antigravity
  ./install.sh update content-studio
  ./install.sh uninstall content-studio --ide antigravity
  ./install.sh verify
  ./install.sh --target /tmp/codex-skills
EOF
}

# Claude Code-only plugins (subagents + hooks); never installed via this script
CLAUDE_ONLY_PLUGINS=("specto")

is_claude_only() {
  local plugin_name="$1" p
  for p in "${CLAUDE_ONLY_PLUGINS[@]}"; do
    [[ "$p" == "$plugin_name" ]] && return 0
  done
  return 1
}

list_plugins() {
  for plugin_dir in "${SCRIPT_DIR}"/plugins/*/; do
    [[ -d "${plugin_dir}/skills" ]] || continue
    is_claude_only "$(basename "${plugin_dir}")" && continue
    basename "${plugin_dir}"
  done
}

plugin_exists() {
  local plugin_name="$1"
  if is_claude_only "${plugin_name}"; then
    echo "Plugin '${plugin_name}' is Claude Code-only (subagents + hooks); install it with: claude plugin install ${plugin_name}@techwolf-ai-first" >&2
    exit 1
  fi
  [[ -d "${SCRIPT_DIR}/plugins/${plugin_name}/skills" ]]
}

plugin_version() {
  local plugin_name="$1"
  local manifest="${SCRIPT_DIR}/plugins/${plugin_name}/.claude-plugin/plugin.json"

  if [[ -f "$manifest" ]]; then
    sed -n 's/.*"version":[[:space:]]*"\([^"]*\)".*/\1/p' "$manifest" | head -n 1
  else
    echo "unknown"
  fi
}

plugin_guide_src() {
  local plugin_name="$1"
  echo "${SCRIPT_DIR}/plugins/${plugin_name}/codex/AGENTS.md"
}

# Where a plugin's files live under TARGET. Codex flattens skills directly into
# TARGET; Antigravity keeps one self-contained dir per plugin.
plugin_install_root() {
  local plugin_name="$1"
  if [[ "$IDE" == "antigravity" ]]; then
    echo "${TARGET}/${plugin_name}"
  else
    echo "${TARGET}"
  fi
}

# Where a single skill's payload lands.
skill_install_dir() {
  local plugin_name="$1"
  local skill_name="$2"
  if [[ "$IDE" == "antigravity" ]]; then
    echo "${TARGET}/${plugin_name}/skills/${skill_name}"
  else
    echo "${TARGET}/${skill_name}"
  fi
}

plugin_state_dir() {
  local plugin_name="$1"
  if [[ "$IDE" == "antigravity" ]]; then
    # Keep state inside the plugin dir so it is removed with the plugin and does
    # not pollute ~/.gemini/config/plugins with a non-plugin entry.
    echo "${TARGET}/${plugin_name}/${STATE_DIR_NAME}"
  else
    echo "${TARGET}/${STATE_DIR_NAME}/plugins/${plugin_name}"
  fi
}

skill_source_dir() {
  local plugin_name="$1"
  echo "${SCRIPT_DIR}/plugins/${plugin_name}/skills"
}

skill_names_for_plugin() {
  local plugin_name="$1"
  local skills_dir
  skills_dir="$(skill_source_dir "$plugin_name")"

  for skill_dir in "${skills_dir}"/*/; do
    [[ -d "$skill_dir" ]] || continue
    basename "$skill_dir"
  done
}

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

write_skill_metadata() {
  local dest="$1"
  local plugin_name="$2"
  local version="$3"
  local skill_name="$4"
  local source_dir="$5"

  # "platform" stamps the target IDE so runtime host-detection is deterministic.
  # Scripts that read Claude-only session history use it to route or degrade.
  cat > "${dest}/.techwolf-plugin.json" <<EOF
{
  "plugin": "$(json_escape "$plugin_name")",
  "version": "$(json_escape "$version")",
  "skill": "$(json_escape "$skill_name")",
  "platform": "$(json_escape "$IDE")",
  "source": "$(json_escape "$source_dir")"
}
EOF
}

write_plugin_manifest() {
  local plugin_name="$1"
  local version="$2"
  local state_dir
  state_dir="$(plugin_state_dir "$plugin_name")"

  mkdir -p "$state_dir"
  {
    echo "plugin=${plugin_name}"
    echo "version=${version}"
    for skill_name in $(skill_names_for_plugin "$plugin_name"); do
      echo "skill=${skill_name}"
    done
  } > "${state_dir}/manifest.txt"
}

install_plugin_guide() {
  local plugin_name="$1"
  local guide_src
  local guide_dest_dir

  guide_src="$(plugin_guide_src "$plugin_name")"
  guide_dest_dir="$(plugin_state_dir "$plugin_name")"

  if [[ -f "$guide_src" ]]; then
    mkdir -p "$guide_dest_dir"
    cp "$guide_src" "${guide_dest_dir}/AGENTS.md"
    echo "  Installed guide ${plugin_name} -> ${guide_dest_dir}/AGENTS.md"
  fi
}

installed_version() {
  local plugin_name="$1"
  local state_dir
  state_dir="$(plugin_state_dir "$plugin_name")"
  if [[ -f "${state_dir}/manifest.txt" ]]; then
    grep -F 'version=' "${state_dir}/manifest.txt" | head -1 | cut -d= -f2
  fi
}

install_plugin() {
  local plugin_name="$1"
  local version
  local skills_dir
  local installed_count=0

  if ! plugin_exists "$plugin_name"; then
    echo "Error: plugin '${plugin_name}' not found" >&2
    exit 1
  fi

  version="$(plugin_version "$plugin_name")"
  skills_dir="$(skill_source_dir "$plugin_name")"

  echo "Installing ${plugin_name} v${version} to ${TARGET}"
  mkdir -p "$TARGET"

  # Antigravity expects one self-contained dir per plugin (plugin.json +
  # installed_version.json + skills/). Reset it and write the plugin-level files
  # before staging skills, mirroring how Antigravity ships its own plugins.
  if [[ "$IDE" == "antigravity" ]]; then
    local plugin_root
    plugin_root="$(plugin_install_root "$plugin_name")"
    rm -rf "$plugin_root"
    mkdir -p "${plugin_root}/skills"
    local marker_src="${SCRIPT_DIR}/plugins/${plugin_name}/plugin.json"
    if [[ -f "$marker_src" ]]; then
      cp "$marker_src" "${plugin_root}/plugin.json"
    else
      printf '{\n  "name": "%s",\n  "version": "%s"\n}\n' \
        "$(json_escape "$plugin_name")" "$(json_escape "$version")" > "${plugin_root}/plugin.json"
    fi
    printf '{"version": "%s"}\n' "$(json_escape "$version")" > "${plugin_root}/installed_version.json"
  fi

  # Write manifest first so interrupted installs can be cleaned up
  write_plugin_manifest "$plugin_name" "$version"

  for skill_dir in "${skills_dir}"/*/; do
    [[ -d "$skill_dir" ]] || continue

    local skill_name
    local dest
    skill_name="$(basename "$skill_dir")"
    dest="$(skill_install_dir "$plugin_name" "$skill_name")"

    # Codex flattens all plugins into one dir, so guard against two plugins
    # claiming the same skill name. Antigravity isolates each plugin in its own
    # dir, so there is no cross-plugin collision to check.
    if [[ "$IDE" != "antigravity" && -f "${dest}/.techwolf-plugin.json" ]]; then
      local existing_owner
      existing_owner="$(grep -F '"plugin":' "${dest}/.techwolf-plugin.json" | sed 's/.*"plugin":[[:space:]]*"\([^"]*\)".*/\1/' || true)"
      if [[ -n "$existing_owner" && "$existing_owner" != "$plugin_name" ]]; then
        echo "  Error: skill '${skill_name}' already installed by plugin '${existing_owner}'" >&2
        echo "  Uninstall '${existing_owner}' first or use a different target directory" >&2
        exit 1
      fi
    fi

    rm -rf "$dest"
    mkdir -p "$dest"

    # Stage plugin-root shared asset dirs into the skill. Claude Code resolves
    # these via the plugin root, but Codex installs each skill as a flat
    # self-contained dir, so a skill that reads "scripts/X" or "templates/X from
    # this plugin" needs those files alongside its own SKILL.md. We copy every
    # plugin-root subdir except the framework dirs (skills/, codex/,
    # .claude-plugin/), before the skill payload so skill-local files win on any
    # name conflict.
    local shared_src
    for shared_src in "${SCRIPT_DIR}/plugins/${plugin_name}"/*/; do
      [[ -d "$shared_src" ]] || continue
      case "$(basename "$shared_src")" in
        skills|codex|.claude-plugin) continue ;;
      esac
      # Strip trailing slash so cp copies the directory itself, not its contents.
      cp -R "${shared_src%/}" "$dest/"
    done

    cp -R "${skill_dir}/." "$dest/"
    write_skill_metadata "$dest" "$plugin_name" "$version" "$skill_name" "$skill_dir"

    echo "  Installed ${plugin_name}/${skill_name} -> ${dest}"
    installed_count=$((installed_count + 1))
  done
  install_plugin_guide "$plugin_name"

  echo "  Installed ${installed_count} skill(s) for ${plugin_name}"
}

verify_plugin() {
  local plugin_name="$1"
  local version
  local failures=0
  local checked=0

  if ! plugin_exists "$plugin_name"; then
    echo "Error: plugin '${plugin_name}' not found" >&2
    exit 1
  fi

  version="$(plugin_version "$plugin_name")"

  if [[ "$IDE" == "antigravity" ]]; then
    local plugin_root
    plugin_root="$(plugin_install_root "$plugin_name")"
    if [[ ! -f "${plugin_root}/plugin.json" ]]; then
      echo "  Missing plugin.json for ${plugin_name} at ${plugin_root}"
      failures=$((failures + 1))
    fi
    if [[ ! -f "${plugin_root}/installed_version.json" ]]; then
      echo "  Missing installed_version.json for ${plugin_name} at ${plugin_root}"
      failures=$((failures + 1))
    fi
  fi

  for skill_name in $(skill_names_for_plugin "$plugin_name"); do
    local dest
    dest="$(skill_install_dir "$plugin_name" "$skill_name")"
    checked=$((checked + 1))

    if [[ ! -f "${dest}/SKILL.md" ]]; then
      echo "  Missing SKILL.md for ${plugin_name}/${skill_name} at ${dest}"
      failures=$((failures + 1))
      continue
    fi

    if [[ ! -f "${dest}/.techwolf-plugin.json" ]]; then
      echo "  Missing metadata for ${plugin_name}/${skill_name} at ${dest}"
      failures=$((failures + 1))
      continue
    fi

    if ! grep -Fq "\"plugin\": \"${plugin_name}\"" "${dest}/.techwolf-plugin.json"; then
      echo "  Metadata plugin mismatch for ${plugin_name}/${skill_name} at ${dest}"
      failures=$((failures + 1))
      continue
    fi

    if ! grep -Fq "\"version\": \"${version}\"" "${dest}/.techwolf-plugin.json"; then
      echo "  Metadata version mismatch for ${plugin_name}/${skill_name} at ${dest}"
      failures=$((failures + 1))
    fi
  done

  local guide_src
  guide_src="$(plugin_guide_src "$plugin_name")"
  if [[ -f "$guide_src" ]]; then
    local installed_guide
    installed_guide="$(plugin_state_dir "$plugin_name")/AGENTS.md"
    if [[ ! -f "$installed_guide" ]]; then
      echo "  Missing guide for ${plugin_name} at ${installed_guide}"
      failures=$((failures + 1))
    fi
  fi

  if [[ $failures -eq 0 ]]; then
    echo "Verified ${plugin_name}: ${checked} skill(s) OK"
  else
    echo "Verification failed for ${plugin_name}: ${failures} issue(s)"
    return 1
  fi
}

uninstall_plugin() {
  local plugin_name="$1"
  local state_dir

  # Antigravity keeps the whole plugin in one dir, so removing it is enough.
  if [[ "$IDE" == "antigravity" ]]; then
    local plugin_root
    plugin_root="$(plugin_install_root "$plugin_name")"
    if [[ ! -d "$plugin_root" ]]; then
      echo "No install found for ${plugin_name} under ${plugin_root}"
      return 1
    fi
    rm -rf "$plugin_root"
    echo "Uninstalled ${plugin_name} (removed ${plugin_root})"
    return 0
  fi

  state_dir="$(plugin_state_dir "$plugin_name")"
  if [[ ! -f "${state_dir}/manifest.txt" ]]; then
    echo "No install manifest found for ${plugin_name} under ${state_dir}"
    return 1
  fi

  echo "Uninstalling ${plugin_name} from ${TARGET}"

  while IFS= read -r line; do
    [[ "$line" == skill=* ]] || continue
    local skill_name="${line#skill=}"
    local dest="${TARGET}/${skill_name}"

    if [[ -f "${dest}/.techwolf-plugin.json" ]] && grep -Fq "\"plugin\": \"${plugin_name}\"" "${dest}/.techwolf-plugin.json"; then
      rm -rf "$dest"
      echo "  Removed ${dest}"
    else
      echo "  Skipped ${dest} (missing or not owned by ${plugin_name})"
    fi
  done < "${state_dir}/manifest.txt"

  rm -rf "$state_dir"
  echo "Removed plugin state ${state_dir}"
}

run_for_selected_plugins() {
  local selected_plugins=()
  local had_failures=0

  if [[ -n "$PLUGIN" ]]; then
    selected_plugins=("$PLUGIN")
  else
    while IFS= read -r plugin_name; do
      selected_plugins+=("$plugin_name")
    done < <(list_plugins)
  fi

  if [[ ${#selected_plugins[@]} -eq 0 ]]; then
    echo "No plugins found."
    exit 1
  fi

  for plugin_name in "${selected_plugins[@]}"; do
    case "$ACTION" in
      install)
        install_plugin "$plugin_name"
        ;;
      update)
        local old_ver
        old_ver="$(installed_version "$plugin_name" || true)"
        local new_ver
        new_ver="$(plugin_version "$plugin_name")"
        if [[ -n "$old_ver" && "$old_ver" == "$new_ver" ]]; then
          echo "${plugin_name} is already at v${new_ver}"
        else
          [[ -n "$old_ver" ]] && echo "Updating ${plugin_name}: v${old_ver} -> v${new_ver}"
          install_plugin "$plugin_name"
        fi
        ;;
      uninstall)
        uninstall_plugin "$plugin_name" || had_failures=1
        ;;
      verify)
        verify_plugin "$plugin_name" || had_failures=1
        ;;
      list)
        if ! plugin_exists "$plugin_name"; then
          echo "Error: plugin '${plugin_name}' not found" >&2
          exit 1
        fi
        printf "%s v%s:" "$plugin_name" "$(plugin_version "$plugin_name")"
        for skill_name in $(skill_names_for_plugin "$plugin_name"); do
          printf " %s" "$skill_name"
        done
        printf "\n"
        ;;
      *)
        echo "Unknown action: ${ACTION}" >&2
        usage
        exit 1
        ;;
    esac
  done

  [[ $had_failures -eq 0 ]] || return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    install|update|uninstall|verify|list)
      ACTION="$1"
      shift
      ;;
    --ide)
      if [[ $# -lt 2 ]]; then
        echo "Error: --ide requires a value (codex|antigravity)" >&2
        usage
        exit 1
      fi
      case "$2" in
        codex|antigravity) IDE="$2" ;;
        *)
          echo "Error: unknown --ide '$2' (expected codex|antigravity)" >&2
          usage
          exit 1
          ;;
      esac
      shift 2
      ;;
    --target)
      if [[ $# -lt 2 ]]; then
        echo "Error: --target requires a value" >&2
        usage
        exit 1
      fi
      TARGET="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -n "$PLUGIN" ]]; then
        echo "Error: unexpected argument '$1'" >&2
        usage
        exit 1
      fi
      PLUGIN="$1"
      shift
      ;;
  esac
done

# Resolve the install dir: an explicit --target wins, otherwise fall back to the
# IDE default. Done after parsing so --ide and --target work in any order.
if [[ -z "$TARGET" ]]; then
  TARGET="$(default_target_for_ide "$IDE")"
fi

run_for_selected_plugins

if [[ "$ACTION" == "install" || "$ACTION" == "update" ]]; then
  ACTION="verify"
  run_for_selected_plugins
fi
