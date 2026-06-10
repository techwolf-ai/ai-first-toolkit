# Python (FastMCP) quickstart

Thin starter. For the full implementation guide (tool design, schemas, annotations, error handling, evaluation), invoke the `example-skills:mcp-builder` skill. Do not reimplement that material here.

## When to pick Python

- The wrapped service has a clean Python SDK or is easy to call with `httpx`.
- You want the fastest path to a working stdio server.
- You will distribute via PyPI / `uvx`.

## Environment setup

```bash
python -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install "mcp[cli]" httpx pydantic
```

Use `.venv/bin/python` (or `.venv\Scripts\python.exe` on Windows) any time you reference Python directly so you stay inside the venv instead of the system interpreter.

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
- Build and smoke-test: `.venv/bin/python -m py_compile server.py`, then `npx @modelcontextprotocol/inspector`.
- If the Inspector is blocked (SSL-restricted network, corporate proxy), fall back to manual JSON-RPC: pipe a JSON-RPC `initialize` + `tools/list` request to the server via stdin and confirm the response on stdout. Example: `echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"0"}}}' | .venv/bin/python server.py`.
- When registering a development server before packaging, use the full venv path so the subprocess inherits the right interpreter: `claude mcp add myserver -- /abs/path/to/.venv/bin/python server.py`. Bare `python` resolves to whatever is on `$PATH` at spawn time, which is usually not your venv.

See `references/deploy-local.md` for registration and `references/distribute-marketplace.md` for publishing to PyPI and the MCP registry.
