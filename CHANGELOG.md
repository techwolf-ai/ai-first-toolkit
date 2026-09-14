# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and this project follows Semantic Versioning.

## [1.12.0] - 2026-09-14

### Fixed

- `token-doctor` and `task-profile` reported roughly 6x too low for anyone working in the Claude desktop app. Two independent defects in each skill's `inventory.py`:
  - **Desktop sessions were classified as automation.** The automation check was `entrypoint != "cli"`, an allow-list of one, so every transcript stamped `claude-desktop` was dropped by default. Replaced with an explicit `AUTOMATION_ENTRYPOINTS` deny-list (`sdk-cli`, `sdk`). An unknown entrypoint now counts as interactive, because silently dropping real work is the worse failure for a cost tool. `sdk-cli` background dispatch, paperclip, ditto-routines, scheduled tasks and the automation slash commands are still excluded by default.
  - **Sub-agent transcripts were invisible.** The scan globbed `*/*.jsonl`, which only matches top-level session files. Sub-agent transcripts live at `<project>/<sid>/subagents/**`, and workflow agents at `<project>/<sid>/subagents/workflows/<wf>/**`. On the reference machine that was 796 of 1,089 files, carrying 28% of real spend. The scan now walks each project directory and rolls every sub-agent transcript into its parent session. Project directories starting with `_archive` are skipped.
- Measured against real transcripts for 31-08-2026 to 14-09-2026: token-doctor went from $409 to $9,728 across the same window, 33 to 113 sessions. `task-profile` went from 11 to 97 interactive sessions.
- `token-doctor` now takes the session id from the transcript filename. A resumed or forked transcript can still carry its originating `sessionId` on an early line, and two sessions sharing an id collided on `out/payloads/<sid>.json` in stage 2.
- `ai-adoption`'s two plugin manifests had drifted apart: `.claude-plugin/plugin.json` was still on 2.0.0's predecessor 1.1.0 and still described `session-search` as part of the plugin. Both markers are now back in sync. Note that `preflight.py` checks that both markers exist but not that their versions match, which is how this drifted unnoticed.

### Added

- `token-doctor` surfaces fan-out and model tier, the two levers the old report could not see:
  - **Fan-out vital sign.** Sessions with >= 5 sub-agent transcripts, their cost and share, plus total sub-agent spend as a share of the bill. New `fanout_*` and `subagent_*` fields in `user-stats.json`, a `--fanout-threshold` flag, and a 🌳 `fanout` health class in the per-project chart.
  - **Model mix section.** Cost, share and turns per model, split main conversation vs sub-agent. This is the actionable half: a model that is cheap in the main conversation and expensive across sub-agents is a one-line change in an `Agent(...)` call. On the reference data Opus was 84% of spend and 8,453 of its turns were sub-agent turns worth $2,385.
- Per-session `main_cost_usd`, `subagent_cost_usd`, `subagent_files`, `subagent_turns` and `subagent_by_model` in `sessions.jsonl`; `subagent_files` / `subagent_turns` in task-profile's inventory rows. Turn counts, timelines and cache metrics stay main-session figures so the length buckets keep meaning one conversation.

### Changed

- `ai-adoption` plugin bumped to v2.1.0; description updated in both `plugin.json` markers and both marketplace manifests.

## [1.11.0] - 2026-07-10

### Added

- `goal-prompt` skill in `session-tools`: turns a task, plan, or feature request into a ready-to-paste `/goal` command for an autonomous Claude Code run. Enforces the three-part shape the `/goal` evaluator needs: a measurable end state, a proof demonstrable in Claude's own output, and constraints that must not drift.

### Changed

- `session-tools` plugin bumped to v1.1.0; description updated in both `plugin.json` markers and both marketplace manifests.

## [1.10.1] - 2026-07-09

### Fixed

- `session-tools` was skipped during marketplace sync ("requires .claude-plugin/plugin.json or a top-level SKILL.md"). The plugin shipped only the top-level Antigravity `plugin.json` marker and was missing the Claude Code `.claude-plugin/plugin.json` manifest that every other plugin carries. Added the `.claude-plugin/plugin.json` manifest (identical contents); the Antigravity marker is unchanged, so both hosts now resolve the plugin.

## [1.10.0] - 2026-07-07

### Added

- `build-plugin` skill in `tool-build-kit`, a sibling to `build-mcp`. Bundles many tools (skills, hooks, agents, MCP servers) into one installable Claude Code plugin and ships it via a marketplace.
  - Establishes context first with `AskUserQuestion` (audience, then git host), then walks four phases: Analyze, Assemble, Ship, Maintain. A branch table maps each phase to the concrete move for Just-me / Team-org-GitHub / Team-org-GitLab / Public.
  - Four on-demand references: `assemble.md` (folder layout, manifest, local `claude --plugin-dir` test), `marketplace.md` (`marketplace.json` shape, per-host `source` types, install commands, public vs private), `team-enablement.md` (project `.claude/settings.json` auto-enable, org-wide managed settings), `maintain.md` (updates, version bumps, ownership).

### Changed

- `tool-build-kit` plugin bumped to v1.7.0 and its description broadened to cover building an MCP server AND bundling tools into a shareable plugin (both `plugin.json` markers and both marketplace manifests updated).

## [1.9.0] - 2026-06-29

### Added

- `session-tools` plugin (v1.0.0): two skills for session continuity.
  - `session-search`: moved from `ai-adoption`. Finds past Claude Code and Cowork sessions by title, cwd, time range, or full-text content. Scripts and host-aware platform detection unchanged.
  - `handoff`: new skill. Writes a tight `HANDOFF.md` resume note at the current working directory so a fresh session can continue without replaying the conversation. Two modes: write (default) and read (`/handoff read`). No platform dependency; works in Claude Code, Cowork, and Codex.
- Added `session-tools` to both marketplace manifests (`.claude-plugin/marketplace.json` and `.agents/plugins/marketplace.json`).

### Changed

- `ai-adoption` plugin bumped to v2.0.0. `session-search` removed and moved to `session-tools`. Plugin now covers two skills: `token-doctor` and `task-profile`. Users who relied on `session-search` from `ai-adoption` should install `session-tools`.

## [1.8.0] - 2026-06-12

### Added

- Host-aware session analysis for the **ai-adoption** plugin (token-doctor, task-profile, session-search), so the skills route to the correct per-platform session store or degrade honestly instead of silently scanning Claude Code paths on Codex/Antigravity.
  - `install.sh` now stamps a `platform` field (the `--ide` target) into each installed skill's `.techwolf-plugin.json`, making runtime host detection deterministic.
  - New shared helper `host_platform.py` (one copy per skill's `scripts/` dir, identical logic) resolves the host via, in order: `AI_FIRST_PLATFORM` env var, the installed `platform` stamp, then a `~/.claude` fallback (Claude Code native installs are never stamped). Exposes `detect_platform()` and a `degrade()` helper. Documented once in the README.
  - **All three skills now support Codex.** New `codex_sessions.py` adapter parses Codex rollouts (`~/.codex/sessions/**/rollout-*.jsonl`) into the same turn/session shapes the skills already use:
    - session-search: `find_sessions.py` + `show_session.py` route to Codex (list, time/cwd/title filters, full-text `--grep`, readable turn dump).
    - token-doctor: `inventory.py` builds session rows from Codex `token_count` events (per-response `last_token_usage`); `pricing.py` gains OpenAI list rates (gpt-5.4 family) so cost is real, and returns no rate for unknown models so the report shows token counts without a fabricated dollar figure.
    - task-profile: `inventory.py` builds the same condensate + token aggregates from Codex rollouts.
    Claude Code / Cowork behavior is unchanged on all three.
  - **Antigravity session analysis degrades by design.** Investigation found the Antigravity IDE store is AEAD-encrypted at rest (`~/.gemini/antigravity/conversations/*.pb`, chacha20poly1305/GCM via the `language_server` binary) and the unencrypted CLI SQLite store (`antigravity-cli/conversations/*.db`) carries no parseable turn/token content. All skills print a clear, accurate "not available on Antigravity" message and exit 0.

### Changed

- README gains a per-platform support matrix for ai-adoption ("Not using Claude Code?"). Each ai-adoption `SKILL.md` states its platform scope.

## [1.7.0] - 2026-06-12

### Added

- Google Antigravity support. The toolkit's plugins now install into Antigravity (and the Gemini CLI) end to end, reusing the existing `SKILL.md` packages unchanged.
  - `install.sh` gains an `--ide <codex|antigravity>` flag. `--ide antigravity` installs one self-contained dir per plugin into `~/.gemini/config/plugins/<plugin>/` (`plugin.json` + `installed_version.json` + `skills/`), matching where Antigravity keeps its own plugins. Codex remains the default (flat skills into `~/.codex/skills/`). An explicit `--target` still overrides either. All lifecycle commands (`install`, `update`, `verify`, `uninstall`, `list`) work for both targets, including the plugin-root shared-asset staging.
  - `.agents/plugins/marketplace.json`: vendor-neutral marketplace manifest (Antigravity schema with `interface.displayName`, per-plugin `source`, `policy`, and `category`) listing all 7 plugins, so Antigravity can discover the toolkit as a plugin marketplace.
  - `plugins/<plugin>/plugin.json`: an Antigravity plugin marker per plugin (name, version, description kept in sync with `.claude-plugin/plugin.json`).
- README and `AGENTS.md` document the third target and the dual-manifest convention; added an Antigravity badge.

## [1.6.1] - 2026-06-10

### Fixed

- Codex installs now stage plugin-root shared asset directories (`scripts/`, `templates/`, and any other non-framework plugin-root dir) into each skill so skills that read them "from this plugin" resolve under Codex's flat per-skill layout. Previously `install.sh` copied only `skills/<skill>/`, so these files never reached `~/.codex/skills/`.
  - `knowledge-base`: `setup-knowledge-base` can now read and copy its `kb-*.py` helpers and `kb/` templates in Codex (the setup flow and `kb-answer` were broken there).
  - `content-studio`: `setup-content-studio` can now copy the bundled Next.js app, `scripts/`, and `hooks/` in Codex; `repo-setup.md` documents how `<plugin-path>` resolves in Claude Code vs Codex.
- `people-management`: skills now reference their shared framework docs (`operating-principles.md`, `performance-framework.md`, `management-framework.md`, `values-guide.md`) via skill-relative paths instead of `../../references/`, which pointed outside the skill in Codex. The shared docs are bundled into each skill that uses them, so resolution works in both Claude Code and Codex.

### Changed

- `content-studio` `setup-content-studio`: the post-creation batching step now notes a sequential fallback for agents without sub-agents (e.g. Codex); output is identical.

## [1.6.0] - 2026-06-10

### Added

- `tool-build-kit` plugin: build an MCP server end to end, from first questions to published distribution.
  - `build-mcp` skill: asks who the server is for (personal, org, public) and where it runs (local stdio or hosted HTTP) before writing a line of code, then walks through analyze, build, deploy, scale, and distribute with every step tailored to those answers.
  - 6 reference files loaded progressively: `transports.md` (stdio vs Streamable HTTP, naming gotcha), `deploy-local.md` (`claude mcp add`, scopes, `.mcp.json`, Claude Desktop, `CLAUDE_PROJECT_DIR`), `distribute-marketplace.md` (Claude Code plugin packaging, org marketplace, public MCP registry + `mcp-publisher` flow), `scaling.md` (stateless design, OAuth 2.1 resource server, versioning, SSRF), `python-fastmcp.md` and `node-sdk.md` (thin quickstarts that hand off to `mcp-builder`).
  - Explicit branch table across five deployment targets: just-me-stdio, org-stdio, org-HTTP, public-package, public-HTTP. Phases that are N/A for the chosen branch are stated and skipped rather than padded.
  - Builds on the Anthropic `mcp-builder` skill for implementation depth; adds the scope-and-distribution decision flow it lacks.
- Added `tool-build-kit` to the marketplace manifest.

## [1.5.0] - 2026-05-13

### Added

- `ai-adoption` plugin: three skills for working with your Claude Code + Cowork session history. Runs entirely locally, no API calls.
  - `token-doctor`: two-stage cost diagnostic. Stage 1 walks transcripts, computes length-bucket distribution, marathon share, cache rebuild cost, per-project health, and writes a formatted terminal report inline. Stage 2 (opt-in) picks ~14 hotspot sessions, fans out parallel Haiku subagents per session, and synthesises a per-session habit-recommendation report.
  - `task-profile`: six-phase mining of session history into a role-level task profile. Clusters sessions by judgment, dispatches one Haiku subagent per cluster, aggregates into canonical tasks with success/iterations/friction/tokens, emits `profile.csv`, a single-file interactive `explorer.html` with progressive disclosure, AI-first coaching cards, and up to five task-centric skill proposals.
  - `session-search`: two stdlib-only Python scripts that discover and read Claude Code + Cowork transcripts from disk (`~/.claude/projects/**`, Cowork session dir). Filter by kind, time range, title, cwd, or full-text regex; print a session in readable markdown with optional grep/tail.
  - Privacy: regex-based redaction (API keys, JWTs, emails, phones, cards, IBANs) before any text is dispatched to a subagent or written to output; subagents see token counts and tool-call shape, never prompt or output text.
- Added `ai-adoption` to the marketplace manifest.
- Added `ai-adoption` to the Codex installer.

## [1.4.0] - 2026-05-08

### Added

- `knowledge-base` plugin: evidence-backed knowledge base creator. Every `/kb-answer` reply cites literal quotes from KB files, verified against the source.
  - 4 skills: `setup-knowledge-base`, `kb-answer`, `kb-import`, `kb-refresh`.
  - 4 scripts: `kb-index.py` (with `--write` to regenerate `kb/index.md` between markers, nested-category aware), `kb-verify.py` (strict pass plus a normalized-match fallback for markdown and whitespace drift; supports single- and multi-line citations), `kb-validate.py` (frontmatter, category, date, and related-link health checks; `--max-age N` flags stale entries), `kb-search.py` (keyword-ranked lookup across title, tags, description, path, and body; `--category` and `--tag` filters; `--json` output).
  - Bulk import mode in `/kb-import` for ingesting many documents from a folder in one pass.
  - Templates for setup scaffolding, a default scope, and a sample entry.
- Added `knowledge-base` to the marketplace manifest.
- Added `knowledge-base` to the Codex installer.

## [1.3.1] - 2026-05-07

### Fixed

- `people-management` plugin no longer redeclares hosted MCP servers (Slack, Notion, Gmail, Google Drive, Google Calendar) in its `.mcp.json`. The redeclaration triggered an OAuth dynamic client registration attempt on plugin load that hosted endpoints reject ("dynamic client configuration not supported"), breaking users' existing default Claude connectors until the plugin was uninstalled. Users should rely on their installed Claude connectors instead.

## [1.3.0] - 2026-04-10

### Added

- `techwolf-brand-kit` plugin with TechWolf logo skill providing 4 variants (dark, white, mono-dark, mono-white) in SVG and PNG formats.

### Changed

- Renamed `brand-kit` plugin to `techwolf-brand-kit` for consistency.

### Fixed

- Invalid hooks format in content-studio setup instructions.
- Missing `/api/content` route files in content-studio.

## [1.2.0] - 2026-03-24

### Added

- `people-management` plugin: AI-augmented management tooling for people managers.
  - 8 skills: setup, meeting-prep, one-on-one-prep, triage-messages, customer-status, priority-planner, team-health, performance-cycle.
  - 10-phase interactive setup that discovers team structure, performance frameworks, values, and ways of working.
  - Framework-agnostic: adapts to any org's performance dimensions, rating scale, management competencies, and values.
  - Sub-agent review for sensitive skills (one-on-one-prep, customer-status, team-health, performance-cycle).
  - Connector-unavailable fallbacks for manual-input setup when MCP connectors aren't available.
- Added `people-management` to the marketplace manifest.
- Added `people-management` to the Codex installer.

## [1.1.0] - 2026-03-10

### Added

- Codex support via `./install.sh` for installing plugin skills into Codex skill directories.
- Managed Codex install lifecycle commands for install, update, verify, uninstall, and list.
- Codex install metadata and plugin guidance files.
- A plugin-level `content-studio` Codex entry skill.

### Changed

- Documentation now explains both Claude Code and Codex installation flows.

## [1.0.0] - 2026-03-09

### Added

- Initial public release of the TechWolf AI-First Toolkit plugin marketplace.
- `ai-firstify` plugin.
- `content-studio` plugin.
