# TechWolf AI-First Toolkit

![MIT License](https://img.shields.io/badge/license-MIT-blue.svg) ![v1.7.0](https://img.shields.io/badge/version-1.7.0-green.svg) ![Claude Code](https://img.shields.io/badge/Claude%20Code-plugin-blueviolet.svg) ![Codex](https://img.shields.io/badge/Codex-compatible-orange.svg) ![Antigravity](https://img.shields.io/badge/Antigravity-compatible-4285F4.svg) ![agentskills.io](https://img.shields.io/badge/agentskills.io-spec-lightgrey.svg)

Open-source agent skills from [TechWolf](https://techwolf.ai)'s [AI-First Bootcamp](https://ai-first.techwolf.ai), for Claude Code, Codex, and Google Antigravity.

<!-- TODO: Replace with hero GIF showing ai-firstify audit in action -->

**New here?** Add the marketplace, then install any plugin below. Full commands in [Quick start](#quick-start).

```bash
claude plugin marketplace add techwolf-ai/ai-first-toolkit
```

## Plugins at a glance

7 plugins, 28 skills. One install command each.

| Plugin | What it does | Install |
|--------|--------------|---------|
| **ai-firstify** | Audit, re-engineer, or bootstrap any codebase to 9 AI-first design principles | `claude plugin install ai-firstify@techwolf-ai-first` |
| **content-studio** | Thought-leadership pipeline (LinkedIn, blog, opinion) with a visual editor | `claude plugin install content-studio@techwolf-ai-first` |
| **people-management** | AI-augmented management: 1:1 prep, meeting prep, triage, performance cycles | `claude plugin install people-management@techwolf-ai-first` |
| **knowledge-base** | Evidence-backed KB; every answer cites literal quotes from your files | `claude plugin install knowledge-base@techwolf-ai-first` |
| **ai-adoption** | Claude history analytics: token-doctor, task-profile, session-search | `claude plugin install ai-adoption@techwolf-ai-first` |
| **techwolf-brand-kit** | Official TechWolf logo assets (SVG + PNG) for AI-generated outputs | `claude plugin install techwolf-brand-kit@techwolf-ai-first` |
| **tool-build-kit** | Build an MCP server end to end: analyze, build, deploy, scale, distribute | `claude plugin install tool-build-kit@techwolf-ai-first` |

Not using Claude Code? Every skill follows the [agentskills.io](https://agentskills.io) spec and installs into Codex or Google Antigravity via [`./install.sh`](#codex).

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

### tool-build-kit: Build an MCP Server

End-to-end guide for building a Model Context Protocol server, from first questions to published distribution. Asks who the server is for before building anything, then tailors every phase to that answer.

- **build-mcp**: one skill, five phases (analyze, build, deploy, scale, distribute). Establishes audience (personal / org / public) and runtime (local stdio / hosted HTTP) with `AskUserQuestion` before writing a line of code. Builds on the Anthropic `mcp-builder` skill for implementation depth and adds the scope-and-distribution decision flow it lacks.
- Branch table drives the deploy and distribute phases across five targets: personal local, org local, org hosted, public package, public hosted.
- 6 reference files loaded on demand: transports, local deploy, marketplace distribution, scaling, Python and TypeScript quickstarts.

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
claude plugin install tool-build-kit@techwolf-ai-first
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
./install.sh tool-build-kit
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

### Google Antigravity

The same skills install into Antigravity, which keeps one self-contained dir per plugin under `~/.gemini/config/plugins/`. Pass `--ide antigravity`:

```bash
./install.sh install --ide antigravity                 # all plugins
./install.sh install ai-firstify --ide antigravity     # one plugin
./install.sh list --ide antigravity
./install.sh uninstall ai-firstify --ide antigravity
```

Each plugin installs as `~/.gemini/config/plugins/<plugin>/` with a `plugin.json`, an `installed_version.json`, and a `skills/` directory, the same shape Antigravity uses for its own plugins. For repo-side discovery as a marketplace, Antigravity reads [`.agents/plugins/marketplace.json`](.agents/plugins/marketplace.json) (the vendor-neutral `.agents/` standard), and each plugin carries an Antigravity `plugin.json` marker at `plugins/<plugin>/plugin.json`. Skills are the same `SKILL.md` files used by Claude Code and Codex, no per-target rewrite.

## Repository structure

```
ai-first-toolkit/
├── .claude-plugin/
│   └── marketplace.json        # Claude Code marketplace manifest
├── .agents/
│   └── plugins/
│       └── marketplace.json    # Antigravity / vendor-neutral marketplace manifest
├── plugins/
│   ├── ai-firstify/            # Auditor & re-engineer (1 skill, 9 reference docs)
│   ├── content-studio/         # Content pipeline (8 skills, visual editor, hooks)
│   ├── people-management/      # Management tooling (8 skills, 5 reference docs)
│   ├── knowledge-base/         # Evidence-backed KB (4 skills, templates, index + verify scripts)
│   ├── ai-adoption/            # Claude history analytics (3 skills: token-doctor, task-profile, session-search)
│   ├── techwolf-brand-kit/     # Brand assets (logo variants in SVG + PNG)
│   └── tool-build-kit/         # MCP server builder (1 skill: build-mcp, 6 reference files)
├── install.sh                  # Codex + Antigravity skill installer
└── README.md
```

Each plugin lives in `plugins/<name>/` with a `.claude-plugin/` manifest, an Antigravity `plugin.json` marker, and a `skills/` directory of `SKILL.md` files shared across all targets. See individual plugin READMEs for details:

- [ai-firstify README](plugins/ai-firstify/README.md)
- [content-studio README](plugins/content-studio/README.md)
- [people-management README](plugins/people-management/README.md)
- [knowledge-base README](plugins/knowledge-base/README.md)
- [ai-adoption README](plugins/ai-adoption/README.md)
- [techwolf-brand-kit README](plugins/techwolf-brand-kit/README.md)
- [tool-build-kit README](plugins/tool-build-kit/README.md)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[MIT](LICENSE). See [CHANGELOG.md](CHANGELOG.md) for release history.
