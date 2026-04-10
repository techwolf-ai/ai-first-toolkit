# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and this project follows Semantic Versioning.

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

- `people-management` plugin -- AI-augmented management tooling for people managers.
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
