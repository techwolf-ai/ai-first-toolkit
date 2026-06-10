# TechWolf tool-build-kit for Codex

Use the `build-mcp` skill when the user wants to build an MCP server, wrap an API as a tool, make a tool for Claude, or expose a service to an agent.

The defining step: before building anything, establish the user's context with up-front questions, then tailor every phase to it.

- Audience (ask first): just me, my team/org, or public/external. This cascades into deploy and distribute.
- Runtime (conditional): local stdio or hosted HTTP.
- Language (after analyzing the service): Python (FastMCP) or Node/TypeScript (MCP SDK).

Then run five phases in order: analyze, build, deploy, scale, distribute. Phases deploy, scale, and distribute branch on the audience and runtime answers.

Build on the `mcp-builder` skill for implementation depth (FastMCP and TypeScript SDK, tool design, schemas, evaluation). Do not duplicate it. This skill's own depth is in the scope and distribution references.

Load only the reference files the current branch and phase need.
