# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and this project follows Semantic Versioning.

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
