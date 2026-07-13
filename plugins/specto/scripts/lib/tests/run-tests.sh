#!/usr/bin/env bash
# Test harness for the dispatcher/config layer (lib/config.sh + lib/dispatch.sh).
# Everything runs against throwaway temp dirs: repo .specto/ configs, a sandboxed
# machine config (CLAUDE_PLUGIN_DATA points at a temp dir so the live
# ~/.claude/plugin-data/specto/ stays untouched), git repos with fake remotes
# (a remote is enough for autodetect, no commits needed), and PATH mocks for
# jj/glab. Fully offline: no live glab, jj, or network.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
LIB="$HERE/.."                        # .../scripts/lib
SCRIPTS="$(cd "$LIB/.." && pwd)"      # .../scripts
FIX="$SCRIPTS/forge/gitlab/tests/fixtures/mr-basic"
PLUGCFG="$SCRIPTS/plugin-config.sh"

# Shared assertion helpers + PASS/FAIL counters.
source "$HERE/../../tests/lib/assert.sh"

# Isolation: no inherited backend selection or tracker hints,
# machine config sandboxed. Selection functions read env and $PWD, so every
# probe below runs in a subshell pinned to a controlled directory.
unset SPECTO_FORGE SPECTO_TRACKER SPECTO_VCS \
      SPECTO_BACKEND_OVERRIDE_FORGE SPECTO_BACKEND_OVERRIDE_TRACKER SPECTO_BACKEND_OVERRIDE_VCS \
      LINEAR_API_KEY
export CLAUDE_PLUGIN_DATA="$(mktemp -d -t specto-lib-cfgdata.XXXXXX)"

# Canonicalize via `cd && pwd` so paths returned by the walk-up match exact
# string comparison (macOS /var -> /private/var symlink).
ROOT="$(cd "$(mktemp -d -t specto-lib-test.XXXXXX)" && pwd)"
trap 'rm -rf "$ROOT" "$CLAUDE_PLUGIN_DATA"' EXIT

. "$LIB/config.sh"

# --------------------------------------------------------------------------------
# specto_yaml_get, flat key: value lookups
# --------------------------------------------------------------------------------
echo "== specto_yaml_get =="
YML="$ROOT/flat.yml"
{
  printf 'forge: gitlab\n'
  printf 'tracker: "jira"\n'
  printf 'dup: first\n'
  printf 'dup: second\n'
  printf 'spaced:    padded value   \n'
} > "$YML"

assert "yaml-hit" "flat key returns its value" "$(specto_yaml_get "$YML" forge)" "gitlab"
assert "yaml-quoted" "surrounding double quotes stripped" "$(specto_yaml_get "$YML" tracker)" "jira"
out="$(specto_yaml_get "$YML" absent)"; rc=$?
assert "yaml-missing-key" "missing key yields empty" "$out" ""
assert_exit 0 "$rc" "yaml-missing-key: exit 0 (empty is not an error)"
out="$(specto_yaml_get "$ROOT/does-not-exist.yml" forge)"; rc=$?
assert "yaml-missing-file" "missing file yields empty" "$out" ""
assert_exit 0 "$rc" "yaml-missing-file: exit 0 (absent config is not an error)"
assert "yaml-first-match" "first match wins on duplicate keys" "$(specto_yaml_get "$YML" dup)" "first"
assert "yaml-whitespace" "space after colon and trailing space trimmed" "$(specto_yaml_get "$YML" spaced)" "padded value"

# --------------------------------------------------------------------------------
# Backend selection precedence: env > repo config > machine default > autodetect
# --------------------------------------------------------------------------------
echo
echo "== selection precedence (forge) =="
CFGREPO="$ROOT/cfgrepo"
mkdir -p "$CFGREPO/.specto" "$CFGREPO/nested/deep"
printf 'forge: gitlab\n' > "$CFGREPO/.specto/config.yml"
"$PLUGCFG" set forge github >/dev/null

out="$(cd "$CFGREPO" && SPECTO_FORGE=forgejo specto_forge_backend 2>/dev/null)"
assert "prec-env" "env var beats repo config" "$out" "forgejo"
out="$(cd "$CFGREPO" && specto_forge_backend 2>/dev/null)"
assert "prec-repo" "repo config beats machine default" "$out" "gitlab"
NOREPO="$ROOT/norepo"; mkdir -p "$NOREPO"
out="$(cd "$NOREPO" && specto_forge_backend 2>/dev/null)"
assert "prec-machine" "machine default used when repo config absent" "$out" "github"
# Machine default also sits above autodetect: a gitlab remote must lose to it.
MACHREPO="$ROOT/machrepo"
git -c init.defaultBranch=main init -q "$MACHREPO"
git -C "$MACHREPO" remote add origin git@gitlab.com:o/r.git
out="$(cd "$MACHREPO" && specto_forge_backend 2>/dev/null)"
assert "prec-machine-over-autodetect" "machine default beats remote autodetect" "$out" "github"
out="$(cd "$CFGREPO/nested/deep" && specto_repo_config_file)"
assert "prec-walkup-file" "config found walking up from a nested subdirectory" "$out" "$CFGREPO/.specto/config.yml"
out="$(cd "$CFGREPO/nested/deep" && specto_forge_backend 2>/dev/null)"
assert "prec-walkup-select" "selection honours the walked-up repo config" "$out" "gitlab"
# Drop the machine default so the autodetect sections start unconfigured.
"$PLUGCFG" delete forge >/dev/null

# --------------------------------------------------------------------------------
# Forge autodetect off the origin remote host
# --------------------------------------------------------------------------------
echo
echo "== forge autodetect =="
GH="$ROOT/gh-repo"; GL="$ROOT/gl-repo"; NAMED="$ROOT/named-gitlab"; UNKNOWN="$ROOT/unknown-host"
for r in "$GH" "$GL" "$NAMED" "$UNKNOWN"; do git -c init.defaultBranch=main init -q "$r"; done
git -C "$GH"      remote add origin git@github.com:o/r.git
git -C "$GL"      remote add origin https://gitlab.com/o/r.git
git -C "$NAMED"   remote add origin git@gitlab.selfhosted.example:o/r.git
git -C "$UNKNOWN" remote add origin git@code.selfhosted.example:o/r.git

out="$(cd "$GH" && specto_forge_backend 2>/dev/null)"; rc=$?
assert_exit 0 "$rc" "autodetect-github: exit 0"
assert "autodetect-github" "ssh github.com remote selects github" "$out" "github"
out="$(cd "$GL" && specto_forge_backend 2>/dev/null)"
assert "autodetect-gitlab" "https gitlab.com remote selects gitlab" "$out" "gitlab"
# A self-hosted host NAMED gitlab.* resolves via the hostname glob alone; the
# glab token probe only exists for hosts that don't say gitlab in their name.
out="$(cd "$NAMED" && specto_forge_backend 2>/dev/null)"
assert "autodetect-named-gitlab" "gitlab.* self-hosted resolves without glab" "$out" "gitlab"
# Unrecognizable host with glab masked off PATH: selection must fail loudly.
# TOOLBIN carries only the tools the selection path itself shells out to, so
# `command -v glab` genuinely fails even on machines that have glab installed.
TOOLBIN="$ROOT/toolbin"; mkdir -p "$TOOLBIN"
for t in bash git sed awk dirname mkdir touch cat mktemp mv; do
  ln -s "$(command -v "$t")" "$TOOLBIN/$t"
done
err="$(cd "$UNKNOWN" && PATH="$TOOLBIN" && specto_forge_backend 2>&1 >/dev/null)"; rc=$?
assert_exit 3 "$rc" "autodetect-unknown-host: exit 3 when nothing matches and glab is absent"
assert "autodetect-unknown-host" "guidance on stderr" "$(printf '%s\n' "$err" | grep -c 'cannot determine forge backend')" "1"

# --------------------------------------------------------------------------------
# Tracker autodetect: jira hints > LINEAR_API_KEY > github forge fallthrough
# --------------------------------------------------------------------------------
echo
echo "== tracker autodetect =="
JKEY="$ROOT/jira-key-repo"; mkdir -p "$JKEY/.specto"
printf 'jira_project_key: APP\n' > "$JKEY/.specto/config.yml"
out="$(cd "$JKEY" && specto_tracker_backend 2>/dev/null)"; rc=$?
assert_exit 0 "$rc" "tracker-jira-key: exit 0"
assert "tracker-jira-key" "jira_project_key in repo config selects jira" "$out" "jira"
# tracker-jira.yml next to an (otherwise empty) config.yml also means jira. The
# walk-up keys off config.yml, so it must exist for the yml file to be seen.
JYML="$ROOT/jira-yml-repo"; mkdir -p "$JYML/.specto"
touch "$JYML/.specto/config.yml" "$JYML/.specto/tracker-jira.yml"
out="$(cd "$JYML" && specto_tracker_backend 2>/dev/null)"
assert "tracker-jira-yml" "tracker-jira.yml presence selects jira" "$out" "jira"
out="$(cd "$JKEY" && SPECTO_TRACKER=linear specto_tracker_backend 2>/dev/null)"
assert "tracker-env" "env var beats jira autodetect" "$out" "linear"
BARE="$ROOT/bare"; mkdir -p "$BARE"
out="$(cd "$BARE" && LINEAR_API_KEY=lin_test specto_tracker_backend 2>/dev/null)"
assert "tracker-linear" "LINEAR_API_KEY (and no jira hints) selects linear" "$out" "linear"
out="$(cd "$GH" && specto_tracker_backend 2>/dev/null)"
assert "tracker-github" "github forge falls through to github tracker" "$out" "github"
err="$(cd "$BARE" && specto_tracker_backend 2>&1 >/dev/null)"; rc=$?
assert_exit 3 "$rc" "tracker-nothing: exit 3 when nothing is detectable"
assert "tracker-nothing" "guidance on stderr" "$(printf '%s\n' "$err" | grep -c 'cannot determine tracker backend')" "1"

# --------------------------------------------------------------------------------
# VCS autodetect: `jj root` probe, git fallback, env override
# --------------------------------------------------------------------------------
echo
echo "== vcs autodetect =="
JJOK="$ROOT/jj-ok"; JJNO="$ROOT/jj-no"
mkdir -p "$JJOK" "$JJNO"
printf '#!/usr/bin/env bash\n[[ "${1:-}" == root ]] && exit 0\nexit 1\n' > "$JJOK/jj"
printf '#!/usr/bin/env bash\nexit 1\n' > "$JJNO/jj"
chmod +x "$JJOK/jj" "$JJNO/jj"
out="$(cd "$BARE" && PATH="$JJOK:$PATH" && specto_vcs_backend 2>/dev/null)"
assert "vcs-jj" "jj when a jj on PATH answers 'jj root'" "$out" "jj"
out="$(cd "$BARE" && PATH="$JJNO:$PATH" && specto_vcs_backend 2>/dev/null)"
assert "vcs-git" "git when 'jj root' fails (not a jj repo)" "$out" "git"
out="$(cd "$BARE" && PATH="$JJOK:$PATH" && SPECTO_VCS=git specto_vcs_backend 2>/dev/null)"
assert "vcs-env" "SPECTO_VCS beats jj detection" "$out" "git"
"$PLUGCFG" set vcs jj >/dev/null
out="$(cd "$BARE" && PATH="$JJNO:$PATH" && specto_vcs_backend 2>/dev/null)"
assert "vcs-machine" "machine default beats detection" "$out" "jj"
"$PLUGCFG" delete vcs >/dev/null

# --------------------------------------------------------------------------------
# Dispatcher: override pinning, verb gaps, argv passthrough, exit codes
# --------------------------------------------------------------------------------
echo
echo "== dispatcher =="
SHIM="$SCRIPTS/forge/mr-fetch.sh"
# Override to a backend with no impl for this verb: exit 4, named on stderr.
# (linear is tracker-only by design, so forge/linear/ will never exist; github
# stopped being a valid gap when forge/github/ landed its verbs.)
err="$(SPECTO_BACKEND_OVERRIDE_FORGE=linear "$SHIM" info --from-fixture "$FIX" 2>&1 >/dev/null)"; rc=$?
assert_exit 4 "$rc" "dispatch-verb-unsupported: exit 4"
assert "dispatch-verb-unsupported" "names the gap on stderr" "$(printf '%s\n' "$err" | grep -c 'not supported')" "1"
# Override to gitlab on a real verb: argv (subcommand + --from-fixture) passes
# through verbatim and the impl's payload comes back untouched.
out="$(SPECTO_BACKEND_OVERRIDE_FORGE=gitlab "$SHIM" info --from-fixture "$FIX" 2>/dev/null)"; rc=$?
assert_exit 0 "$rc" "dispatch-override-gitlab: exit 0"
assert "dispatch-override-gitlab" "fixture payload has .iid" "$(printf '%s' "$out" | jq -r '.iid')" "7"
out="$(SPECTO_BACKEND_OVERRIDE_FORGE=gitlab "$SHIM" info --iid 42 --from-fixture "$FIX" 2>/dev/null)"; rc=$?
assert_exit 0 "$rc" "dispatch-argv-passthrough: multi-flag argv reaches the impl"
SPECTO_BACKEND_OVERRIDE_FORGE=gitlab "$SHIM" info --bogus >/dev/null 2>&1; rc=$?
assert_exit 2 "$rc" "dispatch-argv-passthrough: impl's own usage exit (2) surfaces"
# End to end: autodetect (gitlab.com remote) -> dispatch -> gitlab impl -> fixture.
out="$(cd "$GL" && "$SHIM" info --from-fixture "$FIX" 2>/dev/null)"; rc=$?
assert_exit 0 "$rc" "dispatch-autodetect-e2e: exit 0"
assert "dispatch-autodetect-e2e" "resolved gitlab and returned the fixture" "$(printf '%s' "$out" | jq -r '.iid')" "7"
# No backend determinable: the shim exits 3 and forwards the selection guidance.
err="$(cd "$BARE" && "$SHIM" info --from-fixture "$FIX" 2>&1 >/dev/null)"; rc=$?
assert_exit 3 "$rc" "dispatch-no-backend: exit 3"
assert "dispatch-no-backend" "selection guidance forwarded on stderr" "$(printf '%s\n' "$err" | grep -c 'cannot determine forge backend')" "1"
# Unknown domain is a caller bug: exit 2.
err="$({ . "$LIB/dispatch.sh" && specto_dispatch widgets frob; } 2>&1 >/dev/null)"; rc=$?
assert_exit 2 "$rc" "dispatch-unknown-domain: exit 2"
assert "dispatch-unknown-domain" "names the bad domain on stderr" "$(printf '%s\n' "$err" | grep -c "unknown domain 'widgets'")" "1"

echo
echo "Total: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
