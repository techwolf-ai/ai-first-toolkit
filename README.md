# TechWolf AI-First Toolkit

Open-source AI skills and plugins from [TechWolf](https://techwolf.ai)'s [AI-First Bootcamp](https://ai-first.techwolf.ai).

This repository is a **plugin marketplace** for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Each plugin bundles skills, agents, hooks, and other resources that extend Claude Code with domain-specific capabilities.

## Available Plugins

| Plugin | Description | Status |
|--------|-------------|--------|
| [ai-firstify](plugins/ai-firstify/) | AI-first project auditor and re-engineer based on the 9 design principles and 7 design patterns from the TechWolf AI-First Bootcamp | Available |
| [content-studio](plugins/content-studio/) | Content studio for thought leadership (LinkedIn, blog, opinion) with visual editor and Claude Code skills | Available |

## Repository Structure

```
ai-first-toolkit/
├── .claude-plugin/
│   └── marketplace.json        # Marketplace manifest (registers all plugins)
├── plugins/
│   ├── ai-firstify/            # Plugin: AI-first auditor & re-engineer
│   │   ├── .claude-plugin/     #   Plugin manifest
│   │   └── skills/             #   SKILL.md files + reference docs
│   └── content-studio/         # Plugin: Content studio
│       ├── .claude-plugin/     #   Plugin manifest
│       ├── skills/             #   SKILL.md files per content type
│       ├── hooks/              #   Event handlers
│       ├── templates/          #   Guidelines & reference templates
│       ├── content/            #   Content storage (posts, drafts)
│       ├── content-studio/     #   Next.js visual editor app
│       └── scripts/            #   Utility scripts
├── LICENSE
└── README.md
```

Each plugin lives in `plugins/<plugin-name>/` and contains at minimum a `.claude-plugin/` manifest directory and a `skills/` directory with one or more `SKILL.md` files. Plugins can optionally include hooks, templates, scripts, and companion apps.

## Installation

### Claude Code

Install a plugin directly from this marketplace:

```bash
# Add the TechWolf marketplace (once)
claude plugin marketplace add techwolf-ai/ai-first-toolkit

# Install a specific plugin
claude plugin install ai-firstify@techwolf-ai-first
claude plugin install content-studio@techwolf-ai-first
```

Update to the latest version:

```bash
claude plugin update ai-firstify@techwolf-ai-first
claude plugin update content-studio@techwolf-ai-first
```

## License

This project is licensed under the [MIT License](LICENSE).
