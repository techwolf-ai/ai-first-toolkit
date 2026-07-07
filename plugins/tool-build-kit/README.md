# tool-build-kit

Build and ship tools for Claude Code, end to end. Two sibling skills:

- `build-mcp`: build one MCP server the right way, tailored to who it's for.
- `build-plugin`: bundle many tools (skills, hooks, agents, MCP servers) into one installable plugin and distribute it via a marketplace.

Both ask who the work is for before they build anything, then tailor every step to that answer. `build-mcp` builds on the Anthropic [`mcp-builder`](https://github.com/anthropics/skills) skill for implementation depth; `build-plugin` picks up where `build-mcp` leaves off, packaging a server (or any other tools) into a shareable unit.

## Install

```bash
# Add the TechWolf marketplace (once)
claude plugin marketplace add techwolf-ai/ai-first-toolkit

# Install the plugin
claude plugin install tool-build-kit@techwolf-ai-first
```

## build-mcp

Triggers when you ask Claude Code to build an MCP server, wrap an API as a tool, make a tool for Claude, or expose a service to an agent. Or invoke it directly:

```
/build-mcp
```

### The decision flow

Before building, the skill uses `AskUserQuestion` to establish context:

1. **Audience** (asked first): just me, my team/org, or public/external.
2. **Runtime** (conditional): local stdio or hosted HTTP.
3. **Language** (after analysis): Python (FastMCP), Node/TypeScript (MCP SDK), or let the skill recommend.

That answer cascades through the five phases. A personal local server and a public hosted server share almost no steps past "build".

### The five phases

1. **Analyze**: understand the service to wrap, pick tool boundaries, scope secrets.
2. **Build**: scaffold and implement (delegates to `mcp-builder`).
3. **Deploy**: register or host it for the target runtime.
4. **Scale**: harden and operate it (substantive only for hosted servers).
5. **Distribute**: local registration, org marketplace, or public MCP registry, gated by the audience answer.

### Reference files

Loaded on demand by the skill:

- `transports.md`: stdio vs Streamable HTTP
- `deploy-local.md`: `claude mcp add`, scopes, `.mcp.json`, Desktop config
- `distribute-marketplace.md`: plugin packaging, org marketplace, public registry
- `scaling.md`: hosted-server statelessness, auth, versioning, security
- `python-fastmcp.md`, `node-sdk.md`: thin quickstarts that hand off to `mcp-builder`

## build-plugin

Triggers when you ask Claude Code to bundle tools into one plugin, package tools for a colleague, publish a plugin to a marketplace, share your tools with your team, or ship a plugin. Or invoke it directly:

```
/build-plugin
```

Where `build-mcp` builds one MCP server, `build-plugin` bundles many tools (including MCP servers from `build-mcp`) into a single installable plugin and distributes it. When `build-mcp` reaches its Distribute phase for a team or public audience, it hands off here.

### The decision flow

Before assembling, the skill uses `AskUserQuestion` to establish context:

1. **Audience** (asked first): just me, my team/org, or public/external.
2. **Git host** (conditional, skipped for "Just me"): GitHub, GitLab/other, or not sure yet.

Confirm the resolved tuple, then follow the branch table. A personal one-project bundle and a public team marketplace share almost nothing past "assemble".

### The four phases

1. **Analyze**: decide what tools go in the bundle, and name it.
2. **Assemble**: build the plugin folder and manifest, test locally with `claude --plugin-dir`.
3. **Ship**: marketplace repo, git host, public/private, one-click enablement for a team.
4. **Maintain**: versions, updates, ownership, and admin controls.

### Reference files

Loaded on demand by the skill:

- `assemble.md`: plugin folder layout, manifest fields, moving loose tools in, local `claude --plugin-dir` testing, validation
- `marketplace.md`: `marketplace.json` shape, per-host `source` types, add/install commands, public vs private and auth
- `team-enablement.md`: project `.claude/settings.json` auto-enable, org-wide managed-settings enforcement
- `maintain.md`: updates, version bumps, ownership, fixes via merge request

## License

This project is licensed under the [MIT License](../../LICENSE).
