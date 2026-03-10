#!/usr/bin/env bash
set -euo pipefail

TARGET="${HOME}/.codex/skills"
ACTION="install"
PLUGIN=""
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATE_DIR_NAME=".techwolf-ai-first"

usage() {
  cat <<'EOF'
Usage:
  ./install.sh [install|update|uninstall|verify|list] [plugin] [--target <dir>]

Examples:
  ./install.sh
  ./install.sh content-studio
  ./install.sh install ai-firstify
  ./install.sh update content-studio
  ./install.sh uninstall content-studio
  ./install.sh verify
  ./install.sh --target /tmp/codex-skills
EOF
}

list_plugins() {
  for plugin_dir in "${SCRIPT_DIR}"/plugins/*/; do
    [[ -d "${plugin_dir}/skills" ]] || continue
    basename "${plugin_dir}"
  done
}

plugin_exists() {
  local plugin_name="$1"
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

plugin_state_dir() {
  local plugin_name="$1"
  echo "${TARGET}/${STATE_DIR_NAME}/plugins/${plugin_name}"
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

  cat > "${dest}/.techwolf-plugin.json" <<EOF
{
  "plugin": "$(json_escape "$plugin_name")",
  "version": "$(json_escape "$version")",
  "skill": "$(json_escape "$skill_name")",
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

  # Write manifest first so interrupted installs can be cleaned up
  write_plugin_manifest "$plugin_name" "$version"

  for skill_dir in "${skills_dir}"/*/; do
    [[ -d "$skill_dir" ]] || continue

    local skill_name
    local dest
    skill_name="$(basename "$skill_dir")"
    dest="${TARGET}/${skill_name}"

    # Check for ownership conflict with another plugin
    if [[ -f "${dest}/.techwolf-plugin.json" ]]; then
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

  for skill_name in $(skill_names_for_plugin "$plugin_name"); do
    local dest="${TARGET}/${skill_name}"
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

run_for_selected_plugins

if [[ "$ACTION" == "install" || "$ACTION" == "update" ]]; then
  ACTION="verify"
  run_for_selected_plugins
fi
