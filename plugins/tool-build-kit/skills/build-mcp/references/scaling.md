# Scale: operating a hosted MCP server

Only substantive for the hosted-HTTP branch. For local/personal servers, scaling is N/A; the priorities there are maintainability and versioning, and you should skip to distribute.

> There is no Anthropic-published "operate an MCP server in production" guide. This rests on the MCP spec (sessions, lifecycle, security best practices) plus normal infrastructure practice. Items not in the spec are marked as operator choices.

## Stateless vs session-bearing

Statefulness is optional and controlled by the session-ID mechanism in Streamable HTTP:

- A server **may** assign a session ID at initialization by returning an `Mcp-Session-Id` header on the `InitializeResult` response. It should be globally unique and cryptographically secure (UUID, JWT, or hash) and contain only visible ASCII.
- If a session ID was issued, the client **must** send it on all subsequent requests. A server requiring it should answer requests without it (other than init) with `400 Bad Request`.
- A server may terminate a session at any time; afterward it must answer that session ID with `404 Not Found`, and the client must start a new session with a fresh `InitializeRequest`.

Scaling implication: if you issue **no** session ID, each request is independent and you can run N replicas behind a load balancer with no shared store. If you issue session IDs and hold in-memory session state, you need sticky sessions or a shared session store. The transport is per-request; the application layer still tracks negotiated protocol version, capabilities, and enabled tools, so "stateless" servers re-establish that cheaply per request rather than holding nothing.

## Resumability

Servers may attach SSE `id` fields (a per-stream cursor, unique within the session); clients resume a dropped stream with the `Last-Event-ID` header on a GET. A server must not replay messages that belonged to a different stream. This lets a client survive a dropped connection or a replica restart without losing messages.

## Auth: OAuth 2.1 resource server

For HTTP servers that need auth (stdio servers should use environment credentials instead):

- The server is an OAuth 2.1 **resource server**. It must implement Protected Resource Metadata (RFC 9728) and, on 401, return a `WWW-Authenticate` header pointing at the resource-metadata URL. Discovery: 401 -> `/.well-known/oauth-protected-resource` -> authorization server metadata (RFC 8414) -> OAuth 2.1 flow with PKCE.
- Clients must include the `resource` parameter (RFC 8707) set to your canonical server URI.
- **Validate the token audience**: the server must verify access tokens were issued specifically for it. Invalid/expired -> 401; bad scopes -> 403; malformed -> 400. Bearer token on every request; never in the query string.
- **Never pass tokens through.** The server must not accept tokens not issued for it, and when it calls an upstream API it acts as a separate OAuth client there with its own token. Passthrough breaks the audit trail and the trust boundary.

## Least-privilege scopes

Do not advertise every scope or use wildcard/omnibus scopes (`*`, `all`, `full-access`). Start minimal and elevate incrementally via `WWW-Authenticate scope="..."` challenges. Log elevation events with correlation IDs.

## Session hijacking defense

Servers that implement authorization must verify every inbound request and must not use sessions for authentication. Use non-deterministic (CSPRNG) session IDs, and bind them to user identity with a key like `<user_id>:<session_id>` so a guessed session ID cannot cross users. This matters specifically once you scale to multiple replicas.

## Timeouts

Establish timeouts on all sent requests to prevent hung connections and resource exhaustion. Progress notifications may reset the clock, but always enforce a maximum timeout regardless. Note that Claude Code's per-tool `timeout` is a hard wall-clock limit that progress notifications do not extend.

## Versioning and tool changes

- Protocol versions are date-stamped (`2024-11-05`, `2025-03-26`, `2025-06-18`), negotiated in `initialize`. If the server does not support the requested version it responds with one it does; the client disconnects if it cannot match.
- Your server's own version is the free-form `serverInfo.version` string; semver is convention.
- Tool-list changes are announced at runtime via the `tools.listChanged` capability and `notifications/tools/list_changed`.
- There is **no spec-level tool-deprecation marker**. Adding tools or adding optional inputs is backward-compatible; removing tools or making optional inputs required is breaking. Deprecate by description plus a `list_changed` notification plus a server semver bump.

## Operator choices (not mandated by the spec)

Rate limiting, caching, structured-logging backends, and metrics are not prescribed by MCP. Enforce rate limiting and request validation at the resource-server boundary (it depends on the token audience). The spec does define a server `logging` capability for emitting structured logs over the protocol.

## SSRF and external content

If the server fetches external content: require HTTPS for metadata fetches, block private/reserved IP ranges (including cloud metadata `169.254.169.254`), and prefer an egress proxy over hand-rolled IP validation. Treat any externally fetched content as a prompt-injection risk.
