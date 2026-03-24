# TechWolf AI-First Toolkit

This repository publishes TechWolf AI-first plugins and skills for both Claude Code and Codex.

## Repository Purpose

- `plugins/<plugin>/` is the source of truth for each plugin.
- Claude-specific plugin metadata lives in `.claude-plugin/`.
- Codex-compatible skills live in each plugin's `skills/` directory.
- Codex installs are managed via `./install.sh`.

## Working Conventions

- Preserve the mapping between a plugin and its Codex-installed skills.
- When changing a plugin, update both Claude-facing and Codex-facing docs if behavior changes.
- If Codex install behavior changes, update `README.md`, plugin READMEs, and `CHANGELOG.md`.
- Prefer adding Codex guidance under `plugins/<plugin>/codex/AGENTS.md` when plugin-specific instructions are needed.

## Codex Install Notes

- `./install.sh` installs skills into `~/.codex/skills` by default.
- The installer also manages plugin metadata, verification, and uninstall state under `~/.codex/skills/.techwolf-ai-first/`.
- `content-studio` has a plugin-level Codex entry skill in addition to its specialized skills.
- `people-management` has 8 skills that require `/setup` to be run first to configure org-specific frameworks and context.
