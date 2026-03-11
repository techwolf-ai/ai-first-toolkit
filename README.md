# TechWolf AI-First Toolkit

[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![v1.1.0](https://img.shields.io/badge/version-1.1.0-green.svg)](CHANGELOG.md)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-plugin-blueviolet.svg)](https://docs.anthropic.com/en/docs/claude-code)
[![Codex](https://img.shields.io/badge/Codex-compatible-orange.svg)](https://github.com/openai/codex)
[![agentskills.io](https://img.shields.io/badge/agentskills.io-spec-lightgrey.svg)](https://agentskills.io)

Production-tested Claude Code plugins and Codex skills from [TechWolf](https://techwolf.ai)'s engineering team. Battle-tested across 200+ engineers in the [AI-First Bootcamp](https://ai-first.techwolf.ai).

<!-- TODO: Add hero GIF showing ai-firstify audit in action -->

## What's inside

### ai-firstify — AI-First Project Auditor

Audits any codebase against 9 AI-first design principles and 7 design patterns. Three modes:

- **Audit** — deep analysis across 7 dimensions with a scored report
- **Re-engineer** — actively restructures your project to be AI-first
- **Bootstrap** — guides new project setup with discovery questions

```
> /ai-firstify audit

Scanning project structure...
Analyzing 7 dimensions: foundation, agents, skills, complexity, context, safety, workflows

AI-First Assessment Report
==========================
Overall Score: 6.2 / 10

  Foundation & Structure    ████████░░  8/10
  De-agentification         ███░░░░░░░  3/10
  Skill Architecture        ██████░░░░  6/10
  Complexity Management     ████████░░  8/10
  Context Hygiene           █████░░░░░  5/10
  Safety & Guardrails       ███████░░░  7/10
  Workflow Optimization     ██████░░░░  6/10

Top recommendations:
1. Extract inline agent logic into standalone skills (SKILL.md)
2. Add validation gates to your content pipeline
3. Reduce context window pollution — move reference docs to load-on-demand
```

### content-studio — Thought Leadership Pipeline

Full content pipeline for LinkedIn posts, blog posts, and opinion pieces. Includes 8 specialized skills, a visual Kanban editor, and hooks that auto-start the companion app.

- **Write** — LinkedIn posts, blog posts, opinion pieces with voice-matched style
- **Brainstorm** — generate ideas from URLs, files, or recent posts
- **Analyze** — engagement pattern analysis across published content
- **Setup** — interactive onboarding that learns your voice and creates a personalized content repo

## Quick start

### Claude Code

```bash
# Add the marketplace (once)
claude plugin marketplace add techwolf-ai/ai-first-toolkit

# Install plugins
claude plugin install ai-firstify@techwolf-ai-first
claude plugin install content-studio@techwolf-ai-first
```

### Codex

Skills follow the [agentskills.io](https://agentskills.io) spec:

```bash
./install.sh                    # install all plugins
./install.sh ai-firstify       # install one plugin
./install.sh content-studio
```

<details>
<summary>More install commands</summary>

```bash
./install.sh list               # list installed skills
./install.sh verify             # check installation
./install.sh update ai-firstify # update a plugin
./install.sh uninstall ai-firstify
./install.sh --target ~/custom/ # custom install directory
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
