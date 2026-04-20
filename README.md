# TechWolf AI-First Toolkit

![MIT License](https://img.shields.io/badge/license-MIT-blue.svg) ![v1.4.0](https://img.shields.io/badge/version-1.4.0-green.svg) ![Claude Code](https://img.shields.io/badge/Claude%20Code-plugin-blueviolet.svg) ![Codex](https://img.shields.io/badge/Codex-compatible-orange.svg) ![agentskills.io](https://img.shields.io/badge/agentskills.io-spec-lightgrey.svg)

Open-source Claude Code skills and Codex skills from [TechWolf](https://techwolf.ai)'s [AI-First Bootcamp](https://ai-first.techwolf.ai).

<!-- TODO: Replace with hero GIF showing ai-firstify audit in action -->

## What's inside

### ai-firstify: AI-First Skill

Audit, re-engineer, or bootstrap any codebase to align with 9 AI-first design principles and 7 design patterns. Three modes:

- **Audit**: deep analysis across 7 dimensions with a scored report
- **Re-engineer**: actively restructures your project to be AI-first
- **Bootstrap**: guides new project setup with discovery questions

### content-studio: Thought Leadership Pipeline

Full content pipeline for LinkedIn posts, blog posts, and opinion pieces. Includes 8 specialized skills, a visual Kanban editor, and hooks that auto-start the companion app.

- **Write**: LinkedIn posts, blog posts, opinion pieces with voice-matched style
- **Brainstorm**: generate ideas from URLs, files, or recent posts
- **Analyze**: engagement pattern analysis across published content
- **Setup**: interactive onboarding that learns your voice and creates a personalized content repo

### people-management: AI-Augmented Management

AI-augmented tooling for people managers. Surfaces the right context at the right time, before meetings, during 1:1 prep, when triaging messages, or reviewing performance. Adapts to any org's frameworks and values.

- **Setup**: interactive onboarding (10 phases) that discovers your team, frameworks, values, and ways of working
- **8 skills**: meeting prep, 1:1 prep, triage, customer status, priority planner, team health, performance cycle
- **Framework-agnostic**: configures to your org's performance dimensions, rating scale, management competencies, and values

### knowledge-base: Evidence-Backed Knowledge Base

Build and query a structured knowledge base where every answer cites literal quotes from your KB files. Prevents hallucinations by grounding all responses in documented facts.

- **Setup**: interactive onboarding that defines categories, scaffolds the KB structure, and populates from your existing sources (Notion, Slack, Confluence, local files)
- **KB Answer**: answer questions with evidence-backed citations from your KB
- **KB Import**: import knowledge from documents (Markdown, PDF, plain text) into structured entries
- **KB Refresh**: add new sources or re-scrape existing ones to keep the KB current

### techwolf-brand-kit: Brand Assets

Official TechWolf brand assets for AI-generated outputs. Ensures agents use the correct logo files instead of guessing or approximating.

- **TechWolf Logo**: 4 variants (dark, white, mono-dark, mono-white) in SVG and PNG
- **currentColor SVG**: inline variant that inherits color from parent CSS for themed contexts

## Quick start

### Claude Code

```bash
claude plugin marketplace add techwolf-ai/ai-first-toolkit
claude plugin install ai-firstify@techwolf-ai-first
claude plugin install content-studio@techwolf-ai-first
claude plugin install people-management@techwolf-ai-first
claude plugin install knowledge-base@techwolf-ai-first
claude plugin install techwolf-brand-kit@techwolf-ai-first
```

### Codex

Skills follow the [agentskills.io](https://agentskills.io) spec:

```bash
./install.sh
./install.sh ai-firstify
./install.sh content-studio
./install.sh people-management
./install.sh knowledge-base
./install.sh techwolf-brand-kit
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
│   ├── content-studio/         # Content pipeline (8 skills, visual editor, hooks)
│   ├── people-management/      # Management tooling (8 skills, 5 reference docs)
│   ├── knowledge-base/         # Evidence-backed KB (4 skills, templates, index + verify scripts)
│   └── techwolf-brand-kit/     # Brand assets (logo variants in SVG + PNG)
├── install.sh                  # Codex skill installer
└── README.md
```

Each plugin lives in `plugins/<name>/` with a `.claude-plugin/` manifest and `skills/` directory containing `SKILL.md` files. See individual plugin READMEs for details:

- [ai-firstify README](plugins/ai-firstify/README.md)
- [content-studio README](plugins/content-studio/README.md)
- [people-management README](plugins/people-management/README.md)
- [knowledge-base README](plugins/knowledge-base/README.md)
- [techwolf-brand-kit README](plugins/techwolf-brand-kit/README.md)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[MIT](LICENSE). See [CHANGELOG.md](CHANGELOG.md) for release history.
