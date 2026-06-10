# Transports: stdio vs Streamable HTTP

The MCP spec (current version 2025-06-18) defines two standard transports. SSE is deprecated.

## stdio

The client launches the server as a subprocess and talks to it over stdin/stdout with newline-delimited JSON-RPC. The server may log to stderr but must write nothing else to stdout.

Use stdio when:
- The server runs on the user's own machine (personal tools, local data access).
- Each user supplies their own credentials via environment variables.
- You want the simplest possible setup and testing path.

The spec says clients should support stdio whenever possible. Default to it for "just me" and org-local servers. Build and test on stdio even if the final target is hosted HTTP; the switch is a one-line transport change, not a rewrite.

## Streamable HTTP

A single HTTP endpoint (for example `https://example.com/mcp`) that handles both POST and GET, optionally upgrading to an SSE stream for multi-message responses. This is the current recommended remote transport. It replaced the old HTTP+SSE transport from protocol version 2024-11-05.

Use Streamable HTTP when:
- One server serves many users (hosted/shared).
- You want centralized credentials, auth, and updates.
- The server needs to run somewhere always-on.

Security requirements for HTTP servers (from the spec):
- Validate the `Origin` header on all incoming connections (DNS-rebinding defense).
- Bind to `127.0.0.1`, not `0.0.0.0`, when running locally.
- Require authentication for anything non-public.
- After initialization, clients must send the `MCP-Protocol-Version` header on every request; if absent the server assumes `2025-03-26`.

## The naming gotcha

The same transport has two names depending on where you read:
- Claude Code CLI and `.mcp.json` use `type: "http"` (and accept `streamable-http` as an alias).
- The MCP spec and registry use `streamable-http`.

They mean the same thing. When copy-pasting a config from either source, either spelling works in `.mcp.json`.

## SSE (deprecated)

The old HTTP+SSE transport (protocol 2024-11-05). Kept only for backward compatibility. Do not build new servers on it. Claude Code's own docs warn to use HTTP servers instead where available.
