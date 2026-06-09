# Python (FastMCP) quickstart

Thin starter. For the full implementation guide (tool design, schemas, annotations, error handling, evaluation), invoke the `example-skills:mcp-builder` skill. Do not reimplement that material here.

## When to pick Python

- The wrapped service has a clean Python SDK or is easy to call with `httpx`.
- You want the fastest path to a working stdio server.
- You will distribute via PyPI / `uvx`.

## Minimal stdio server

```python
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("service_mcp")

@mcp.tool()
async def service_search(query: str, limit: int = 20) -> str:
    """Search the service. Returns matching items as readable text."""
    # call the service, format results
    return "..."

if __name__ == "__main__":
    mcp.run()  # stdio by default
```

Switch to hosted HTTP at the end with `mcp.run(transport="streamable_http", port=8000)`. The tools do not change.

## Conventions (mcp-builder owns the detail)

- Validate inputs with Pydantic `BaseModel` + `Field(...)` constraints; set `ConfigDict(extra="forbid")`.
- Return both a concise human-readable string and, where useful, structured data.
- Add a `CHARACTER_LIMIT` guard and pagination (`limit`, `has_more`, `next_offset`) so large results do not flood context.
- Never write logs to stdout on stdio (it corrupts the protocol stream); use stderr.
- Read secrets from environment variables; validate on startup.

## Packaging

- Define an entry point in `pyproject.toml` so the server runs as `uvx <package>`.
- Dependencies: `mcp`, `httpx`, `pydantic`.
- Build and smoke-test: `python -m py_compile server.py`, then `npx @modelcontextprotocol/inspector`.

See `references/deploy-local.md` for registration and `references/distribute-marketplace.md` for publishing to PyPI and the MCP registry.
