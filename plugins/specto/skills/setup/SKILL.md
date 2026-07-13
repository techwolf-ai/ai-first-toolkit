---
name: setup
description: "Interactive onboarding for specto. Doctor-checks dependencies (bash, jq, git, curl), detects your VCS (git/jj) and forge (GitHub/GitLab), probes CLI auth (gh, glab, acli, Linear API key), lets you choose forge + tracker backends, writes machine defaults and the repo's .specto/config.yml, and runs an offline smoke test. Run this first in every repo. Also supports --refresh and --doctor."
argument-hint: "[--refresh | --doctor]"
allowed-tools: Bash, Read, Write, AskUserQuestion
---

# setup

Interactive onboarding for specto in the current repo. Discover the environment, validate every choice with the user, then persist: machine defaults via `scripts/plugin-config.sh`, repo settings in `.specto/config.yml`. Ends with an offline smoke test so the user knows the backends actually resolve before they run a real skill.

> **Principle: never assume, always validate.** Detect, propose, confirm. Autodetect covers the common case; setup only writes config when the user's choice differs from what autodetect would pick, so `.specto/config.yml` stays minimal.

Run the phases in order. Each one discovers, confirms with the user, then persists. `--doctor` runs phase 1 alone; `--refresh` re-probes auth and re-validates config without re-asking settled answers (see [Refresh mode](#refresh-mode)).

Throughout, plugin scripts are addressed as `"${CLAUDE_PLUGIN_ROOT}/scripts/..."`.

## Phase 1 — Doctor

Run the dependency doctor and show the user its output:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/doctor.sh"
```

It checks, per platform:

- **Hard deps** (`bash`, `jq`, `git`, `curl`). A missing one prints a per-OS install hint (`brew install jq` / `sudo apt-get install -y jq` / `sudo dnf install jq` / `winget install jqlang.jq`) and doctor exits non-zero. **If any hard dep is missing, stop here** and tell the user to install it (quote doctor's hint verbatim). No point continuing without the shell toolchain.
- **Optional tools** (`jj`, `gh`, `glab`, `acli`, `python3`, `LINEAR_API_KEY`). Absent ones are reported, never fatal — the later phases only need the ones for the backends the user picks.
- **Tracker config** — the Jira `jira_project` / `jira_board_id` keys, checked only when the resolved tracker is Jira. On a fresh repo the tracker is not configured yet, so doctor just notes it; phase 4 collects those keys.

If invoked as `/specto:setup --doctor`, run only this phase and stop after reporting.

## Phase 2 — VCS detection

Detect the version-control backend from the repo root:

```bash
git rev-parse --show-toplevel 2>/dev/null   # git (or jj colocated with git)
jj root 2>/dev/null                          # jj
```

- `.jj/` present ⇒ **jj**. Confirm a colocated `.git/` exists (`ls -d .git` at the jj root). If not, warn: the forge helpers shell out to `git` / `glab` / `gh`, which need the git metadata — a non-colocated jj repo will not work with the forge layer.
- else `.git/` present ⇒ **git**.
- neither ⇒ **stop**: "run /specto:setup from inside a git or jj repo."

Record nothing. VCS is autodetected at runtime (`jj root` succeeds ⇒ jj, else git). Only write `vcs:` to `.specto/config.yml` if the user explicitly wants to override the autodetect.

## Phase 3 — Forge selection + auth probe

Propose the forge from the origin remote:

```bash
git remote get-url origin 2>/dev/null
```

- host contains `github.com` ⇒ propose **github** (`gh`).
- a GitLab host (`gitlab.com` or a self-hosted `gitlab.*`) ⇒ propose **gitlab** (`glab`).
- ambiguous or no remote ⇒ ask with `AskUserQuestion` (options: GitHub, GitLab).

Confirm the proposal with the user. Then probe auth for the chosen forge and, on failure, print the exact login command:

```bash
glab auth status     # gitlab; on failure: glab auth login --hostname <host>
gh auth status       # github; on failure: gh auth login
```

A failed probe is not fatal for setup (the smoke test is offline), but tell the user they must authenticate before running a live skill.

**Persist only when the choice differs from autodetect.** Autodetect maps the origin host to the forge, so a github.com or gitlab.com remote needs nothing written. Write `forge: <github|gitlab>` into `.specto/config.yml` (phase 5) only when the user picked a forge the remote host would not have produced (e.g. a self-hosted host `glab` knows a token for but the pattern misses). Explain this to the user so they understand why the file may not mention the forge.

## Phase 4 — Tracker selection + auth probe

Ask with `AskUserQuestion`: **Jira**, **GitHub Issues**, or **Linear**. Then, per choice:

**Jira.** Probe auth and collect the site + project key:

```bash
acli jira auth status        # on failure: tell the user to run 'acli jira auth login'
```

- Collect the **Jira site** host (e.g. `your-org.atlassian.net`) and store it as a machine default:
  ```bash
  "${CLAUDE_PLUGIN_ROOT}/scripts/plugin-config.sh" set jira_site <host>
  ```
- Collect the **project key** (e.g. `ABC`) and the **board id** for sprint placement:
  ```bash
  "${CLAUDE_PLUGIN_ROOT}/scripts/plugin-config.sh" set jira_project  <KEY>
  "${CLAUDE_PLUGIN_ROOT}/scripts/plugin-config.sh" set jira_board_id <ID>
  ```
  Also write `jira_project_key: <KEY>` into `.specto/config.yml` (phase 5) — its presence is what makes the tracker autodetect to Jira.
- Offer to scaffold `.specto/tracker-jira.yml` from a commented starter so the tenant's field ids live in one place:
  ```yaml
  # Jira tenant profile for specto. Flat key: value scalars for the shell-read keys.
  site: your-org.atlassian.net
  sprint_field: customfield_10020   # the "Sprint" custom field on this tenant
  # Uncomment and set the ids for your tenant if you file bugs with Impact/Priority:
  # impact_field: customfield_XXXXX
  # impact_high:  <option-id>
  # impact_low:   <option-id>
  # priority_field: customfield_YYYYY
  ```

**GitHub Issues.** Reuse the forge's `gh` auth (`gh auth status`); no extra key needed — the tracker files against the origin repo's Issues, which `gh` infers from the remote. If the forge is not github, write `tracker: github` into `.specto/config.yml` so the choice is explicit.

**Linear.** Check the API key and run one viewer probe (offline-safe: it needs `LINEAR_API_KEY` in the environment):

```bash
[ -n "$LINEAR_API_KEY" ] || echo "set LINEAR_API_KEY (a Linear personal API key) in your shell profile"
printf '{ viewer { id name } }' | \
  "${CLAUDE_PLUGIN_ROOT}/scripts/tracker/linear/_gql.sh" 'query { viewer { id name } }'
```

- Collect the **team key** (e.g. `ENG`) and write it as `project: <TEAM>` into `.specto/config.yml`.
- Write `tracker: linear` into `.specto/config.yml`: the Linear autodetect keys off `$LINEAR_API_KEY`, which may not be set in every shell, so an explicit selector is the robust choice.

Remind the user that `LINEAR_API_KEY` must be exported in their shell for live runs.

## Phase 5 — Repo scaffold

Create `.specto/` and write the repo config. Never clobber an existing `.specto/config.yml` — if one exists, show it and offer to merge the new keys rather than overwrite.

Write `.specto/config.yml` with the keys the earlier phases settled (omit `forge:`/`vcs:`/`tracker:` when autodetect already covers them):

```yaml
# specto repo config. Flat key: value scalars for shell-read keys; lists/blocks
# below (reviewers, default_dod_checklist, compliance) are read by the agents.
jira_project_key: ABC          # Jira only; omit for github/linear
# tracker: linear              # only when autodetect would not pick your tracker
# forge: gitlab                # only when the origin host would not pick your forge
reviewers: []                  # spec/MR reviewers okr-alignment and review-spec read
default_dod_checklist:         # team-wide Definition-of-Done items the dod agent composes
  - tests pass in CI
  - changelog / docs updated when user-facing
```

Then write the `.specto/.gitignore` whitelist (same shape `new-spec` scaffolds, plus the Jira profile) so the tracked OKR/tracker inputs survive an MR while transient files stay local:

```bash
if [ ! -f .specto/.gitignore ]; then
  mkdir -p .specto
  cat > .specto/.gitignore <<'EOF'
*
!.gitignore
!config.yml
!okrs.md
!tracker-jira.yml
EOF
fi
```

Offer to create the spec tree:

```bash
mkdir -p docs/development/specs
```

Capture the repo's test / typecheck commands as machine defaults (used by `verify-milestone`, `resolve-mr-comments`, `dod-check`). Ask the user for each; skip a blank answer:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/plugin-config.sh" set test_command      "<e.g. bash scripts/tests/run-all.sh>"
"${CLAUDE_PLUGIN_ROOT}/scripts/plugin-config.sh" set typecheck_command "<e.g. mypy .>"
```

## Phase 6 — OKR source (optional)

The `okr-alignment-review` reviewer needs an OKR source, or it degrades to a `no-okr-source` advisory. Offer three options with `AskUserQuestion`:

1. **Notion page** — collect the page id and write `notion_okr_page_id: <id>` into `.specto/config.yml`.
2. **Local markdown** — create `.specto/okrs.md` (whitelisted above) and tell the user to paste their OKR snapshot into it.
3. **Skip** — reviewers run with the `no-okr-source` advisory; the user can add a source later by re-running `--refresh`.

## Phase 7 — Compliance profile (optional)

The change-classification feature is opt-in and **off by default**. Point the user at the example profile and offer to copy its `compliance:` block into `.specto/config.yml` for them to adapt:

```bash
cat "${CLAUDE_PLUGIN_ROOT}/references/compliance-profile.example.yml"
```

Default is **skip** — with no `compliance:` block, `change-classification-review` and the DoD classification source both print one "no compliance profile configured; skipped" line and exit cleanly. Only copy the block if the user explicitly wants their org's change-management questions enforced; they must then rewrite the questions and replace the `epic_field_id` placeholders with their tenant's custom-field ids.

## Phase 8 — Offline smoke test

Prove the chosen backends resolve end-to-end, with zero network, by running the vetted dispatcher shim against the shipped test fixture for each backend. Pin the backend with the test override so routing is deterministic regardless of cwd. Each command must exit 0.

**Forge:**

```bash
# gitlab
SPECTO_BACKEND_OVERRIDE_FORGE=gitlab \
  "${CLAUDE_PLUGIN_ROOT}/scripts/forge/mr-fetch.sh" info \
  --from-fixture "${CLAUDE_PLUGIN_ROOT}/scripts/forge/gitlab/tests/fixtures/mr-basic"

# github
SPECTO_BACKEND_OVERRIDE_FORGE=github \
  "${CLAUDE_PLUGIN_ROOT}/scripts/forge/mr-fetch.sh" info \
  --from-fixture "${CLAUDE_PLUGIN_ROOT}/scripts/forge/github/tests/fixtures/pr-open"
```

**Tracker:**

```bash
# jira
SPECTO_BACKEND_OVERRIDE_TRACKER=jira \
  "${CLAUDE_PLUGIN_ROOT}/scripts/tracker/list-children.sh" ABC-1 \
  --from-fixture "${CLAUDE_PLUGIN_ROOT}/scripts/tracker/jira/tests/fixtures/children-wrapped.json"

# github issues
SPECTO_BACKEND_OVERRIDE_TRACKER=github \
  "${CLAUDE_PLUGIN_ROOT}/scripts/tracker/list-children.sh" 100 \
  --from-fixture "${CLAUDE_PLUGIN_ROOT}/scripts/tracker/github/tests/fixtures/children.json"

# linear
SPECTO_BACKEND_OVERRIDE_TRACKER=linear \
  "${CLAUDE_PLUGIN_ROOT}/scripts/tracker/list-children.sh" ENG-1 \
  --from-fixture "${CLAUDE_PLUGIN_ROOT}/scripts/tracker/linear/tests/fixtures/children.json"
```

Run only the two the user chose (their forge + their tracker). Report **PASS/FAIL per backend** (exit 0 = PASS). A FAIL means the helper layer is broken for that backend — surface it; do not claim setup succeeded.

## Phase 9 — Summary

Print:

- **What was written where** — the `.specto/config.yml` keys, the machine-config keys (`plugin-config.sh list` shows them), `.specto/.gitignore`, `.specto/tracker-jira.yml` / `.specto/okrs.md` if created, and whether `docs/development/specs/` was made.
- **Gaps** — any auth probe that failed (with its login command), any optional tool still missing for the chosen backends, whether an OKR source was configured.
- **Superpowers prerequisite** — specto delegates to superpowers skills. Check the available skill list for `superpowers:brainstorming`; if absent, print the install command:
  ```text
  /plugin marketplace add obra/superpowers-marketplace
  /plugin install superpowers@superpowers-marketplace
  ```
- **Next step** — "run `/specto:using-specto` for the orientation, then `/specto:new-spec` to scaffold your first spec."

## Refresh mode

When invoked as `/specto:setup --refresh`:

1. Read the existing `.specto/config.yml` and `plugin-config.sh list`.
2. Re-run phase 1 (doctor) and the auth probes for the already-chosen forge + tracker (phases 3–4), reporting any that now fail with the fix command.
3. Re-run phase 8 (smoke test) for the configured backends.
4. Offer to fill only gaps that are still unset (missing OKR source, missing `test_command`, an absent `tracker-jira.yml`). **Do not re-ask settled answers.**
5. Print the phase 9 summary.

## Hard rules

- **Validate before persisting.** Never write a backend, key, or path the user has not confirmed.
- **Never clobber existing config.** Merge into an existing `.specto/config.yml`; write `.specto/.gitignore` and `.specto/tracker-jira.yml` only if absent.
- **Autodetect first, config second.** Only write `forge:` / `tracker:` / `vcs:` selectors when the user's choice differs from what runtime autodetect would resolve. Keep `.specto/config.yml` minimal.
- **Stop on a missing hard dep.** Do not proceed past phase 1 without `bash`, `jq`, `git`, and `curl`.
- **The smoke test is offline.** It must never reach a live service — always `--from-fixture` against the shipped fixtures.
- **Do not commit on the user's behalf.** The user reviews and commits `.specto/`.
