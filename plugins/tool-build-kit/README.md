# tool-build-kit

Build an MCP server the right way, end to end. One skill, `build-mcp`, that asks who the server is for before it builds anything, then tailors every step to that answer. Builds on the Anthropic [`mcp-builder`](https://github.com/anthropics/skills) skill for implementation depth and adds the scope-and-distribution decision flow it lacks.

## Install

```bash
# Add the TechWolf marketplace (once)
claude plugin marketplace add techwolf-ai/ai-first-toolkit

# Install the plugin
claude plugin install tool-build-kit@techwolf-ai-first
```

## Usage

The skill triggers automatically when you ask Claude Code to build an MCP server, wrap an API as a tool, make a tool for Claude, or expose a service to an agent. Or invoke it directly:

```
/build-mcp
```

## The decision flow

Before building, the skill uses `AskUserQuestion` to establish context:

1. **Audience** (asked first): just me, my team/org, or public/external.
2. **Runtime** (conditional): local stdio or hosted HTTP.
3. **Language** (after analysis): Python (FastMCP), Node/TypeScript (MCP SDK), or let the skill recommend.

That answer cascades through the five phases. A personal local server and a public hosted server share almost no steps past "build".

## The five phases

1. **Analyze**: understand the service to wrap, pick tool boundaries, scope secrets.
2. **Build**: scaffold and implement (delegates to `mcp-builder`).
3. **Deploy**: register or host it for the target runtime.
4. **Scale**: harden and operate it (substantive only for hosted servers).
5. **Distribute**: local registration, org marketplace, or public MCP registry, gated by the audience answer.

## Reference files

Loaded on demand by the skill:

- `transports.md`: stdio vs Streamable HTTP
- `deploy-local.md`: `claude mcp add`, scopes, `.mcp.json`, Desktop config
- `distribute-marketplace.md`: plugin packaging, org marketplace, public registry
- `scaling.md`: hosted-server statelessness, auth, versioning, security
- `python-fastmcp.md`, `node-sdk.md`: thin quickstarts that hand off to `mcp-builder`

## License

This project is licensed under the [MIT License](../../LICENSE).
