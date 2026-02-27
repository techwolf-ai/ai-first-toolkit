# TechWolf AI-First Toolkit

Open-source AI skills, plugins, and MCP servers from [TechWolf](https://techwolf.com)'s [AI-First Engineering](https://ai-first.techwolf.ai) program.

This repository is a **plugin marketplace** for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) and provides **MCP servers** for Cursor, Windsurf, and other AI coding tools.

## Available Plugins

| Plugin | Description | Status |
|--------|-------------|--------|
| [content-studio](plugins/content-studio/) | Content studio for thought leadership (LinkedIn, blog, opinion) with visual editor and Claude Code skills | Available |

## Installation

### Claude Code (Recommended)

Add the marketplace and install any plugin:

```bash
# Add the TechWolf marketplace
/plugin marketplace add techwolf-ai/ai-first-toolkit

# Install a specific plugin
/plugin install <plugin-name>@techwolf-ai-first
```

### Cursor / Windsurf / Other MCP Clients

Our plugins include MCP servers that work with any MCP-compatible client.

1. Open your IDE settings and find the MCP server configuration
2. Add a new server with the appropriate `npx` command:

```json
{
  "mcpServers": {
    "techwolf-example": {
      "command": "npx",
      "args": ["-y", "@techwolf/<server-name>"]
    }
  }
}
```

Refer to each plugin's README for the exact server name and configuration.

## Contributing

We welcome contributions! Whether it's a bug fix, a new skill, or an improvement to an existing plugin — feel free to open an issue or submit a pull request.

### Adding a New Plugin

Each plugin lives in `plugins/<plugin-name>/` and follows this structure:

```
plugins/my-plugin/
├── .claude-plugin/
│   └── plugin.json       # Plugin manifest
├── skills/               # Agent skills (SKILL.md files)
├── agents/               # Specialized subagents (optional)
├── hooks/                # Event handlers (optional)
├── .mcp.json             # MCP server config (optional)
├── src/                  # MCP server source code (optional)
├── package.json          # For NPM publishing (optional)
└── README.md             # Plugin documentation
```

## License

[MIT](LICENSE)

---

Built by [TechWolf](https://techwolf.com) as part of the [AI-First Engineering](https://ai-first.techwolf.ai) program.
