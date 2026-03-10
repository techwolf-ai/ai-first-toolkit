# Contributing

Thanks for your interest in contributing to the TechWolf AI-First Toolkit!

## Getting Started

1. Fork the repository
2. Clone your fork locally
3. Create a branch for your change

## What You Can Contribute

- **New skills** -- Add skills to existing plugins or propose new plugins
- **Bug fixes** -- Fix issues in existing skills, scripts, or docs
- **Documentation** -- Improve READMEs, add examples, fix typos
- **Ideas** -- Open an issue to discuss new plugins or improvements

## Project Structure

```
plugins/
  <plugin-name>/
    .claude-plugin/     # Plugin manifest
    skills/
      <skill-name>/
        SKILL.md        # Skill definition (agentskills.io spec)
        references/     # Supporting docs the skill can read
        scripts/        # Helper scripts the skill can run
```

## Adding a New Skill

1. Create a directory under `plugins/<plugin>/skills/<skill-name>/`
2. Add a `SKILL.md` following the [agentskills.io](https://agentskills.io) spec
3. Add any supporting files in `references/` and `scripts/`
4. Update the plugin's README with the new skill

## Submitting Changes

1. Keep PRs focused -- one feature or fix per PR
2. Update relevant READMEs if your change affects usage
3. Test your skills with Claude Code (and Codex via `./install.sh` if possible)
4. Open a PR against `main` with a clear description of what and why

## Code Style

- Keep skills concise and self-contained
- No unnecessary comments or boilerplate
- Shell scripts should use `set -euo pipefail`

## Questions?

Open an issue or start a discussion on GitHub.
