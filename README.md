# TechWolf AI-First Toolkit

![MIT License](https://img.shields.io/badge/license-MIT-blue.svg) ![v1.5.0](https://img.shields.io/badge/version-1.5.0-green.svg) ![Claude Code](https://img.shields.io/badge/Claude%20Code-plugin-blueviolet.svg) ![Codex](https://img.shields.io/badge/Codex-compatible-orange.svg) ![agentskills.io](https://img.shields.io/badge/agentskills.io-spec-lightgrey.svg)

Open-source Claude Code skills and Codex skills from [TechWolf](https://techwolf.ai)'s [AI-First Bootcamp](https://ai-first.techwolf.ai).

<!-- TODO: Replace with hero GIF showing ai-firstify audit in action -->

**New here?** Add the marketplace, then install any plugin below. Full commands in [Quick start](#quick-start).

```bash
claude plugin marketplace add techwolf-ai/ai-first-toolkit
```

## Plugins at a glance

6 plugins, 27 skills. One install command each.

| Plugin | What it does | Install |
|--------|--------------|---------|
| **ai-firstify** | Audit, re-engineer, or bootstrap any codebase to 9 AI-first design principles | `claude plugin install ai-firstify@techwolf-ai-first` |
| **content-studio** | Thought-leadership pipeline (LinkedIn, blog, opinion) with a visual editor | `claude plugin install content-studio@techwolf-ai-first` |
| **people-management** | AI-augmented management: 1:1 prep, meeting prep, triage, performance cycles | `claude plugin install people-management@techwolf-ai-first` |
| **knowledge-base** | Evidence-backed KB; every answer cites literal quotes from your files | `claude plugin install knowledge-base@techwolf-ai-first` |
| **ai-adoption** | Claude history analytics: token-doctor, task-profile, session-search | `claude plugin install ai-adoption@techwolf-ai-first` |
| **techwolf-brand-kit** | Official TechWolf logo assets (SVG + PNG) for AI-generated outputs | `claude plugin install techwolf-brand-kit@techwolf-ai-first` |

Not using Claude Code? Every skill follows the [agentskills.io](https://agentskills.io) spec and installs into Codex via [`./install.sh`](#codex).

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

- **Setup**: interactive onboarding that defines categories (flat or nested), scaffolds the KB structure, and populates from your existing sources (Notion, Slack, Confluence, local files)
- **KB Answer**: answer questions with evidence-backed citations from your KB
- **KB Import**: import knowledge from documents (Markdown, PDF, plain text) into structured entries, single-document or bulk-from-folder
- **KB Refresh**: add new sources or re-scrape existing ones to keep the KB current
- **KB Search**: `kb-search.py` keyword-ranked lookup across title, tags, description, and body, with category and tag filters

### ai-adoption: Claude History Analytics

Three skills for working with your Claude Code + Cowork session history. Local-only, no API calls.

- **token-doctor**: diagnoses where your token spend goes (length distribution, marathon share, cache rebuilds, per-project health) and writes a doctor-style terminal report. Opt-in deep dive fans out parallel Haiku subagents over hotspot sessions for habit-level recommendations.
- **task-profile**: mines sessions into a role-level map of what you actually do with AI, ranked by frequency and friction. Emits a shareable CSV, an interactive HTML explorer, AI-first coaching cards, and up to five skill proposals.
- **session-search**: finds a specific past session by title, working directory, time range, or free-text content across every transcript on disk.

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
claude plugin install ai-adoption@techwolf-ai-first
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
./install.sh ai-adoption
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
│   ├── ai-adoption/            # Claude history analytics (3 skills: token-doctor, task-profile, session-search)
│   └── techwolf-brand-kit/     # Brand assets (logo variants in SVG + PNG)
├── install.sh                  # Codex skill installer
└── README.md
```

Each plugin lives in `plugins/<name>/` with a `.claude-plugin/` manifest and `skills/` directory containing `SKILL.md` files. See individual plugin READMEs for details:

- [ai-firstify README](plugins/ai-firstify/README.md)
- [content-studio README](plugins/content-studio/README.md)
- [people-management README](plugins/people-management/README.md)
- [knowledge-base README](plugins/knowledge-base/README.md)
- [ai-adoption README](plugins/ai-adoption/README.md)
- [techwolf-brand-kit README](plugins/techwolf-brand-kit/README.md)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[MIT](LICENSE). See [CHANGELOG.md](CHANGELOG.md) for release history.
