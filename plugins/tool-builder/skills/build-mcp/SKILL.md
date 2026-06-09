---
name: build-mcp
description: "Build an MCP server end to end, tailored to how it will be used. Use when asked to build an MCP, create an MCP server, wrap an API as a tool, make a tool for Claude, expose a service to an agent, build a Claude connector, or turn a service into MCP tools. Asks up front who the server is for (just me, my org, or public) and what it wraps, then walks through analyze, build, deploy, scale, and distribute with steps tailored to that answer. Builds on the example-skills:mcp-builder skill for implementation depth."
---

# Build MCP

Build a Model Context Protocol (MCP) server the right way, end to end. The defining move of this skill: establish the user's context with `AskUserQuestion` before building anything, then tailor every phase to that context. A personal local server and a public hosted server share almost no steps past "build", so branch early and commit to the branch.

## How this relates to mcp-builder

The Anthropic `example-skills:mcp-builder` skill is the gold-standard reference for the *implementation* itself: FastMCP and TypeScript SDK patterns, tool design, input/output schemas, annotations, error handling, and evaluation. Do not duplicate it. This skill is the **scope-and-distribution wrapper around it**: it decides what to build, for whom, where it runs, and how it ships. When you reach the build phase, invoke `example-skills:mcp-builder` for the deep implementation guidance and keep this skill's references thin.

## The five phases

1. **Analyze**: understand the service to wrap and pick the right tool boundaries.
2. **Build**: scaffold and implement the server (delegates to mcp-builder).
3. **Deploy**: get it running and registered for the target runtime.
4. **Scale**: harden and operate it (only substantive for hosted servers).
5. **Distribute**: make it reachable by the intended audience.

Run them in order. The `AskUserQuestion` answers from Phase 0 gate phases 3, 4, and 5.

## Phase 0: Establish context (AskUserQuestion, do this first)

Before analyzing or writing anything, branch on the user's context. Ask the **audience** question first; it is the headline decision and it cascades into everything downstream. Then ask runtime only if it is still ambiguous, and ask language after Analyze (so you can recommend based on the wrapped service).

**Question 1 (always, ask first): Audience / scope:**

Use `AskUserQuestion`:
- header: "Audience"
- question: "Who is this MCP server for? This decides how we deploy and distribute it."
- options:
  1. "Just me": personal local tool on my machine.
  2. "My team / org": shared internally, installed by colleagues.
  3. "Public / external": published openly for anyone to install.

**Question 2 (conditional): Where it runs:**

Skip for "Just me" (assume local stdio). Ask for org/public when unclear:
- header: "Runtime"
- question: "Where should the server run?"
- options:
  1. "Local stdio": runs as a subprocess on each user's machine. Simplest. Each user supplies their own secrets.
  2. "Hosted HTTP": one Streamable HTTP server many users connect to. Needs auth, deploy, and scaling.

**Question 3 (after Analyze): Language:**

- header: "Language"
- question: "What should the server be written in?"
- options:
  1. "Python (FastMCP)": fastest path, great for wrapping Python-friendly APIs.
  2. "Node / TypeScript (MCP SDK)": best when the wrapped service has a strong TS SDK or you ship via npm.
  3. "Recommend for me": pick based on the service analyzed in Phase 1.

Ask one question at a time. Confirm the resolved context back to the user in one line before proceeding (e.g. "Building a personal, local, Python stdio server that wraps the Linear API"). That resolved tuple drives the branch table below.

## Branch table (the spine of this skill)

| Phase | Just me (local stdio) | My org (local stdio) | My org (hosted HTTP) | Public (package) | Public (hosted HTTP) |
|-------|----------------------|----------------------|----------------------|------------------|----------------------|
| **Deploy** | `claude mcp add --scope user` or `.mcp.json` | Bundle in a Claude Code plugin; `${CLAUDE_PLUGIN_ROOT}` paths | Deploy Streamable HTTP endpoint + OAuth/bearer | Publish to PyPI/npm; users run via `uvx`/`npx` | Deploy HTTP endpoint; document the URL |
| **Scale** | N/A (keep it maintainable) | N/A per-user; version the plugin | Real: statelessness, sessions, auth, rate limits | Versioning + backward-compat tool changes | Full: statelessness, auth, rate limits, observability |
| **Distribute** | Not shared. Stop after registration. | Org marketplace (`.claude-plugin/marketplace.json` + `/plugin install`) | Org marketplace entry pointing at the hosted URL | PyPI/npm + MCP registry via `mcp-publisher` | MCP registry `remotes` entry + public docs |

If a phase says N/A for the chosen branch, say so explicitly and move on. Do not pad it.

Reference files for each branch:
- **references/transports.md**: stdio vs Streamable HTTP, when each applies, the `http`/`streamable-http` naming gotcha.
- **references/deploy-local.md**: `claude mcp add`, scopes, `.mcp.json`, Claude Desktop config, uvx/npx run configs.
- **references/distribute-marketplace.md**: bundling an MCP server in a Claude Code plugin, org marketplace, the public MCP registry.
- **references/scaling.md**: hosted-server statelessness, sessions, auth, versioning, security.
- **references/python-fastmcp.md** and **references/node-sdk.md**: thin quickstarts that hand off to mcp-builder.

Load only the references the current branch and phase need. Progressive disclosure.

## Phase 1: Analyze

Understand what you are wrapping before you write tools. Output a short tool plan, then confirm it.

1. **Identify the service/API.** Read its docs or SDK. Note auth model (API key, OAuth, none), base URL, rate limits, pagination style.
2. **Pick tool boundaries.** Tools should map to user *intents*, not raw endpoints. Prefer a few high-value workflow tools over one-tool-per-endpoint. Each tool does one focused thing. (mcp-builder has the full tool-design rubric; apply it here.)
3. **Decide read vs write.** Mark which tools are read-only and which mutate state; this becomes the `readOnlyHint` / `destructiveHint` annotations later.
4. **Scope the secrets.** What credentials does each tool need? For "Just me" they live in local env. For hosted, they live server-side and must never be passed through from the client (see scaling.md).
5. **Now ask the language question** (Phase 0 Q3) if it was deferred, recommending based on what you found.

Deliverable: a numbered list of proposed tools, each with name, one-line purpose, inputs, read/write, and the service call it makes. Confirm with the user before building.

## Phase 2: Build

Hand off to the implementation reference for the chosen language, which in turn defers to mcp-builder for depth.

- Python: read **references/python-fastmcp.md**, then invoke `example-skills:mcp-builder` for the full FastMCP guide.
- Node/TS: read **references/node-sdk.md**, then invoke `example-skills:mcp-builder` for the full TypeScript SDK guide.

Build to the tool plan from Phase 1. Apply mcp-builder's rules: clear tool names, Pydantic/Zod input schemas with descriptions and constraints, structured + human-readable output, pagination with limits, actionable error messages, and tool annotations. Compile and test with the MCP Inspector (`npx @modelcontextprotocol/inspector`) before moving on. Write the evaluation set mcp-builder describes (about 10 realistic, read-only, verifiable questions) and run it.

Start the server on **stdio** regardless of final runtime; it is the simplest thing to test locally. Switching to Streamable HTTP is a transport change at the end, not a rewrite (see transports.md).

## Phase 3: Deploy

Branch on the resolved runtime. Read **references/deploy-local.md** for stdio, **references/transports.md** for HTTP.

- **Local stdio (just me, or org-local):** register it. `claude mcp add --scope user <name> -- <command> <args>` for a personal server across all your projects, or a project-scoped `.mcp.json`. Verify with `claude mcp list` and `/mcp`. For org-local distribution, you do *not* register by hand on each machine; you bundle into a plugin (Phase 5).
- **Hosted HTTP:** expose a single Streamable HTTP endpoint (POST+GET on one path). Validate the `Origin` header, bind to localhost when local, require auth. Connect with `claude mcp add --transport http <name> <url>` (add `--header "Authorization: Bearer ..."` for static tokens, or rely on the OAuth 401/`WWW-Authenticate` discovery flow). Containerize for repeatable deploys.

## Phase 4: Scale

Only substantive for hosted HTTP servers. For local/personal servers, state plainly that scaling is N/A and that the priority is maintainability and versioning, then skip to Distribute.

For hosted servers, read **references/scaling.md** and cover: stateless vs session-bearing design (`Mcp-Session-Id`), horizontal scaling, auth as an OAuth 2.1 resource server (validate token audience, never pass tokens through), least-privilege scopes, rate limiting, timeouts, observability, and protocol-version negotiation. Carry the caveat that there is no Anthropic-published "operate an MCP server" guide; this rests on the MCP spec plus normal infra practice.

## Phase 5: Distribute

The payoff phase. Branch hard on the audience answer. Read **references/distribute-marketplace.md**.

- **Just me:** nothing to distribute. The server is registered (Phase 3). Stop here; confirm it works in a session.
- **My org / team:** package as a **Claude Code plugin** and list it in your org's `.claude-plugin/marketplace.json`. The plugin ships the server via an `mcpServers` key in `plugin.json` or a bundled `.mcp.json` (use `${CLAUDE_PLUGIN_ROOT}` for bundled paths). Colleagues run `/plugin marketplace add <org>/<repo>` then `/plugin install <name>@<marketplace>`. For auto-provisioning, add the marketplace to the project's `.claude/settings.json` under `extraKnownMarketplaces`. The TechWolf `ai-first-toolkit` repo is a working example of this layout.
- **Public / external:** publish the package first (PyPI for Python, npm for Node), then register metadata with the **MCP registry** using the `mcp-publisher` CLI (`init` -> `login github` -> `publish`). For a hosted public server, register a `remotes` entry pointing at your URL instead of a package. Note the registry is in preview and its schema can change.

You can do more than one (e.g. an org plugin *and* a public package). Distribution paths are additive.

## Done criteria

- The server compiles, the Inspector lists the tools, and the evaluation set passes.
- It is registered or published for the resolved audience, and you verified it loads in a real Claude session.
- The user can name how a colleague (or the public) would install it, matching their audience answer.
