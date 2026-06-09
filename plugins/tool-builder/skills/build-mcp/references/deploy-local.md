# Deploy: local registration

How to register a finished server so Claude can use it. For the "just me" and org-local-stdio branches this is the whole deploy phase. For hosted servers, see the HTTP section at the end and `references/scaling.md`.

## claude mcp add (stdio)

Options come before the name. `--` separates Claude's flags from the server command; everything after `--` is passed to the server untouched.

```bash
claude mcp add [options] <name> -- <command> [args...]
```

Example, a uvx-published Python server with an env var:

```bash
claude mcp add --env SERVICE_API_KEY=sk-xxx --scope user service -- uvx service-mcp
```

Gotcha: do not put the server name immediately after `--env`, or the CLI reads the name as another `KEY=value` pair. Keep at least one other option between `--env` and the name.

### Scopes

| Scope | Loads in | Shared | Stored in |
|-------|----------|--------|-----------|
| `local` (default) | current project only | no | `~/.claude.json` keyed by project path |
| `project` | current project | yes, via version control | `.mcp.json` in project root |
| `user` | all your projects | no | `~/.claude.json` |

For a personal server you use everywhere, pick `--scope user`. For a server tied to one repo, use `project` so it lands in a committed `.mcp.json`.

## .mcp.json (project scope)

```json
{
  "mcpServers": {
    "service": {
      "command": "uvx",
      "args": ["service-mcp"],
      "env": { "SERVICE_API_KEY": "${SERVICE_API_KEY}" }
    }
  }
}
```

- Env-var expansion works in `command`, `args`, `env`, `url`, `headers`: `${VAR}` and `${VAR:-default}`. A required-but-unset var with no default fails parsing.
- Project-scoped servers require user approval before first use (`claude mcp reset-project-choices` resets approvals).
- Optional per-server fields: `timeout` (ms, hard per-tool-call wall-clock limit), `alwaysLoad: true` (exempt from Tool Search deferral).

## Run-on-demand configs (no install step)

Node via npx:

```json
{ "mcpServers": { "weather": { "command": "npx", "args": ["-y", "@you/mcp-weather"] } } }
```

Python via uvx:

```json
{ "mcpServers": { "db": { "command": "uvx", "args": ["db-query-mcp"], "env": { "DB_URL": "..." } } } }
```

## Claude Desktop

Config file: macOS `~/Library/Application Support/Claude/claude_desktop_config.json`, Windows `%APPDATA%\Claude\claude_desktop_config.json`. Same `mcpServers` shape:

```json
{
  "mcpServers": {
    "service": { "command": "uvx", "args": ["service-mcp"], "env": { "SERVICE_API_KEY": "..." } }
  }
}
```

## Hosted HTTP registration

```bash
claude mcp add --transport http service https://service.example.com/mcp
# static bearer token:
claude mcp add --transport http service https://service.example.com/mcp \
  --header "Authorization: Bearer your-token"
```

If the server returns 401/403 with a `WWW-Authenticate` header, Claude runs the OAuth discovery flow; the user completes it via `/mcp`. See `references/scaling.md` for the auth model.

## Verify

```bash
claude mcp list      # shows configured servers and connection status
claude mcp get <name>
```

Then open a session and run `/mcp` to confirm the tools load.
