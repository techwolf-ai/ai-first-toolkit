# TechWolf AI-First Toolkit

This repository publishes TechWolf AI-first plugins and skills for Claude Code, Codex, and Google Antigravity.

## Repository Purpose

- `plugins/<plugin>/` is the source of truth for each plugin.
- The `skills/` directory in each plugin holds the `SKILL.md` packages, shared verbatim across all three targets (agentskills.io spec). There is no per-target skill rewrite.
- Per-target metadata is the only thing that differs:
  - Claude Code: `.claude-plugin/marketplace.json` (root) and `plugins/<plugin>/.claude-plugin/plugin.json`.
  - Antigravity / vendor-neutral: `.agents/plugins/marketplace.json` (root) and `plugins/<plugin>/plugin.json` (Antigravity plugin marker).
- Codex and Antigravity installs are both managed via `./install.sh` (Codex is the default; `--ide antigravity` installs one self-contained plugin dir per plugin into `~/.gemini/config/plugins/`, matching where Antigravity keeps its own plugins).

## Working Conventions

- Preserve the mapping between a plugin and its installed skills across all targets.
- When adding or renaming a plugin, update **both** marketplace manifests (`.claude-plugin/marketplace.json` and `.agents/plugins/marketplace.json`) and add the per-plugin `plugin.json` marker, keeping name/version/description in sync with `.claude-plugin/plugin.json`.
- When changing a plugin, update Claude-, Codex-, and Antigravity-facing docs if behavior changes.
- If install behavior changes, update `README.md`, plugin READMEs, and `CHANGELOG.md`.
- Prefer adding plugin-specific agent guidance under `plugins/<plugin>/codex/AGENTS.md` (the installer copies it into the install state dir for both Codex and Antigravity targets).

## Codex Install Notes

- `./install.sh` installs skills into `~/.codex/skills` by default.
- The installer also manages plugin metadata, verification, and uninstall state under `~/.codex/skills/.techwolf-ai-first/`.
- `content-studio` has a plugin-level Codex entry skill in addition to its specialized skills.
- `people-management` has 8 skills that require `/setup` to be run first to configure org-specific frameworks and context.
- `knowledge-base` ships three Python helper scripts (`kb-index.py`, `kb-verify.py`, `kb-validate.py`) that are copied into the user's project by `/setup-knowledge-base`. The plugin's `/kb-answer` workflow depends on `kb-verify.py` existing in the project's `scripts/` directory.
- `session-tools` has two skills: `session-search` (moved from `ai-adoption` in v1.9.0; host-aware, reads disk transcripts) and `handoff` (writes `HANDOFF.md` resume notes; no platform dependency). `ai-adoption` no longer includes `session-search`.
- `ai-adoption` now covers two skills only: `token-doctor` and `task-profile`.
