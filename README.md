# TechWolf AI-First Toolkit

![MIT License](https://img.shields.io/badge/license-MIT-blue.svg) ![v1.1.0](https://img.shields.io/badge/version-1.1.0-green.svg) ![Claude Code](https://img.shields.io/badge/Claude%20Code-plugin-blueviolet.svg) ![Codex](https://img.shields.io/badge/Codex-compatible-orange.svg) ![agentskills.io](https://img.shields.io/badge/agentskills.io-spec-lightgrey.svg)

Open-source Claude Code skills and Codex skills from [TechWolf](https://techwolf.ai)'s [AI-First Bootcamp](https://ai-first.techwolf.ai).

<!-- TODO: Replace with hero GIF showing ai-firstify audit in action -->

## What's inside

### ai-firstify — AI-First Skill

Audit, re-engineer, or bootstrap any codebase to align with 9 AI-first design principles and 7 design patterns. Three modes:

- **Audit** — deep analysis across 7 dimensions with a scored report
- **Re-engineer** — actively restructures your project to be AI-first
- **Bootstrap** — guides new project setup with discovery questions

### content-studio — Thought Leadership Pipeline

Full content pipeline for LinkedIn posts, blog posts, and opinion pieces. Includes 8 specialized skills, a visual Kanban editor, and hooks that auto-start the companion app.

- **Write** — LinkedIn posts, blog posts, opinion pieces with voice-matched style
- **Brainstorm** — generate ideas from URLs, files, or recent posts
- **Analyze** — engagement pattern analysis across published content
- **Setup** — interactive onboarding that learns your voice and creates a personalized content repo

## Quick start

### Claude Code

```bash
claude plugin marketplace add techwolf-ai/ai-first-toolkit
claude plugin install ai-firstify@techwolf-ai-first
claude plugin install content-studio@techwolf-ai-first
```

### Codex

Skills follow the [agentskills.io](https://agentskills.io) spec:

```bash
./install.sh
./install.sh ai-firstify
./install.sh content-studio
```

<details>
<summary>More install commands</summary>

```bash
./install.sh list
./install.sh verify
./install.sh update ai-firstify
./install.sh uninstall ai-firstify
./install.sh --target ~/custom/
```

**What the installer does:**
- Installs each skill under `~/.codex/skills/<skill-name>/`
- Adds per-skill metadata for traceability back to the source plugin and version
- Verifies required files are present after install
- Copies plugin guidance into `~/.codex/skills/.techwolf-ai-first/plugins/<plugin>/AGENTS.md`

</details>

## Repository structure

```
ai-first-toolkit/
├── .claude-plugin/
│   └── marketplace.json        # Marketplace manifest
├── plugins/
│   ├── ai-firstify/            # Auditor & re-engineer (1 skill, 9 reference docs)
│   └── content-studio/         # Content pipeline (8 skills, visual editor, hooks)
├── install.sh                  # Codex skill installer
└── README.md
```

Each plugin lives in `plugins/<name>/` with a `.claude-plugin/` manifest and `skills/` directory containing `SKILL.md` files. See individual plugin READMEs for details:

- [ai-firstify README](plugins/ai-firstify/README.md)
- [content-studio README](plugins/content-studio/README.md)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[MIT](LICENSE) — see [CHANGELOG.md](CHANGELOG.md) for release history.
