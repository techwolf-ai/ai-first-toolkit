# Node / TypeScript (MCP SDK) quickstart

Thin starter. For the full implementation guide (tool design, schemas, annotations, error handling, evaluation), invoke the `example-skills:mcp-builder` skill. Do not reimplement that material here.

## When to pick TypeScript

- The wrapped service has a strong TypeScript/JavaScript SDK.
- You will distribute via npm / `npx`.
- Your team already maintains a Node toolchain.

## Minimal stdio server

```typescript
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const server = new McpServer({ name: "service-mcp", version: "1.0.0" });

server.registerTool(
  "service_search",
  {
    title: "Search service",
    description: "Search the service and return matching items.",
    inputSchema: { query: z.string(), limit: z.number().default(20) },
    annotations: { readOnlyHint: true },
  },
  async ({ query, limit }) => ({
    content: [{ type: "text", text: "..." }],
  })
);

const transport = new StdioServerTransport();
await server.connect(transport);
```

Switch to hosted HTTP at the end with `StreamableHTTPServerTransport`. The tools do not change.

## Conventions (mcp-builder owns the detail)

- Use the modern `server.registerTool()` API (not the deprecated `server.tool()` / `setRequestHandler`).
- Define inputs as Zod schemas; add `outputSchema` and return `structuredContent` for modern clients.
- Set annotations: `readOnlyHint`, `destructiveHint`, `idempotentHint`, `openWorldHint`.
- Build with `tsc` to `dist/index.js`; that file is the entry point.

## Packaging

- Set `bin` in `package.json` so the server runs as `npx <package>`.
- Dependencies: `@modelcontextprotocol/sdk`, `zod`.
- Smoke-test with `npx @modelcontextprotocol/inspector`.

See `references/deploy-local.md` for registration and `references/distribute-marketplace.md` for publishing to npm and the MCP registry.
