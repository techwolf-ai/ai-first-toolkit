# Distribute: org marketplace and public registry

The distribute phase, branched by audience. Pick the path(s) that match the Phase 0 answer. They are additive: you can ship an org plugin and a public package.

> Distribution mechanics change quickly (the plugin system and the registry are both young). Verify before relying on exact syntax: plugins and marketplaces at `https://code.claude.com/docs/en/plugins` and `https://code.claude.com/docs/en/plugin-marketplaces`; the registry at `https://modelcontextprotocol.io/registry`. Append `.md` to any modelcontextprotocol.io URL to fetch it as markdown.

## Org / team: bundle as a Claude Code plugin

The cleanest way to give colleagues an MCP server is a Claude Code plugin that ships the server. Installing the plugin auto-registers the server, so nobody runs `claude mcp add` by hand.

### Declare the server in the plugin

Two equivalent, documented ways:

1. A standalone `.mcp.json` in the plugin root (auto-discovered):

```json
{
  "mcpServers": {
    "service": {
      "command": "${CLAUDE_PLUGIN_ROOT}/servers/service-server",
      "args": ["--config", "${CLAUDE_PLUGIN_ROOT}/config.json"],
      "env": { "SERVICE_API_KEY": "${SERVICE_API_KEY}" }
    }
  }
}
```

2. An `mcpServers` key in `.claude-plugin/plugin.json` (a path string, an array of paths, or an inline object):

```json
{
  "name": "service-tools",
  "version": "0.1.0",
  "mcpServers": "./.mcp.json"
}
```

Use `${CLAUDE_PLUGIN_ROOT}` for any bundled paths, because marketplace plugins are copied into `~/.claude/plugins/cache`. Plugin MCP servers start automatically when the plugin is enabled and go through the same per-server approval as a project `.mcp.json`. Run `/reload-plugins` after enabling, or after changing a bundled `.mcp.json`.

Note: a plugin's *agents* cannot declare their own `mcpServers` (security restriction); declare at the plugin level.

### List it in a marketplace

`.claude-plugin/marketplace.json` at the marketplace repo root:

```json
{
  "name": "company-tools",
  "owner": { "name": "DevTools Team", "email": "devtools@example.com" },
  "plugins": [
    {
      "name": "service-tools",
      "source": "./plugins/service-tools",
      "description": "MCP tools for the internal service",
      "version": "0.1.0"
    }
  ]
}
```

Required: top-level `name` (kebab-case), `owner.name`, and a `plugins[]` array where each entry has at least `name` and `source`. `source` is a relative path string or an object like `{ "source": "github", "repo": "org/repo" }`. The TechWolf `ai-first-toolkit` repo is a live example of this layout.

### Install flow for colleagues

```bash
/plugin marketplace add your-org/claude-plugins      # owner/repo shorthand for GitHub
/plugin install service-tools@company-tools
/reload-plugins
```

CLI equivalents exist (`claude plugin marketplace add ...`, `claude plugin install ...@... --scope project`).

### Auto-provision for the whole team

Add the marketplace to the project's `.claude/settings.json` so anyone who trusts the folder is prompted to install:

```json
{
  "extraKnownMarketplaces": {
    "company-tools": { "source": { "source": "github", "repo": "your-org/claude-plugins" } }
  }
}
```

### Versioning lever

Set `version` (semver) in `plugin.json` and users only get updates when you bump it. Omit it everywhere and Claude Code falls back to the git commit SHA, treating every commit as a new version. `plugin.json` wins over the marketplace entry.

## Public: package managers + the MCP registry

The official MCP registry holds **metadata only, not artifacts**. Publish the package first, then register metadata.

> Caveat: the registry is in preview. Its schema and commands can change, and data resets may occur before general availability. Treat this section as the least stable part of the workflow and re-check `modelcontextprotocol.io/registry` before publishing.

### Steps with the mcp-publisher CLI

```bash
# 0. add mcpName to package.json (npm only — required for ownership verification)
#    the registry checks this field matches server.json `name` before accepting publish
#    "mcpName": "io.github.<username>/<server-name>"
# 1. publish the package to its registry
npm publish --access public          # or: build + upload to PyPI
# 2. install the publisher CLI
brew install mcp-publisher           # or download the binary from registry releases
# 3. scaffold server.json
mcp-publisher init
# 4. authenticate (GitHub namespace requires GitHub auth)
mcp-publisher login github
# 5. publish metadata
mcp-publisher publish
```

GitHub auth means the server name must start with `io.github.<your-username>/`.

`server.json` for an npm stdio package:

```json
{
  "$schema": "https://static.modelcontextprotocol.io/schemas/2025-12-11/server.schema.json",
  "name": "io.github.you/service",
  "description": "An MCP server for the service.",
  "repository": { "url": "https://github.com/you/service-mcp", "source": "github" },
  "version": "1.0.0",
  "packages": [
    { "registryType": "npm", "identifier": "@you/service-mcp", "version": "1.0.0", "transport": { "type": "stdio" } }
  ]
}
```

For PyPI, use `registryType: "pypi"`; ownership is verified by an `mcp-name: <server-name>` line in the package README rather than a manifest field (see `modelcontextprotocol.io/registry/package-types` for the full per-registry verification rules). For a public hosted server, use a `remotes` array instead of `packages`:

```json
{
  "remotes": [
    { "type": "streamable-http", "url": "https://service.example.com/mcp" }
  ]
}
```

`packages` and `remotes` can coexist so hosts choose. Verify after publish:

```bash
curl "https://registry.modelcontextprotocol.io/v0.1/servers?search=io.github.you/service"
```

## Just me

Nothing to distribute. The server is already registered (see `references/deploy-local.md`). Confirm it works in a session and stop.
