# Assemble: folder, manifest, local test

Build the plugin folder, write its manifest, move your loose tools in, and test it before shipping anything.

## Folder layout

Only `plugin.json` lives inside `.claude-plugin/`. Everything else sits at the plugin ROOT:

```
my-plugin/
  .claude-plugin/
    plugin.json          # the manifest, the ONLY thing inside .claude-plugin/
  skills/
    my-skill/
      SKILL.md
  agents/
    my-agent.md
  hooks/
    hooks.json
  .mcp.json              # MCP servers this plugin ships
  README.md
```

`skills/`, `agents/`, `hooks/hooks.json`, and `.mcp.json` are auto-discovered at the plugin root. A plugin can carry any mix of these; none is required.

## The manifest

`.claude-plugin/plugin.json`:

```json
{
  "name": "my-plugin",
  "description": "One line on what the bundle does.",
  "version": "0.1.0",
  "author": { "name": "Your Name" }
}
```

`name` (kebab-case) and `description` are the essentials; `version` (semver) gives users a clean update boundary; `author` is an object with `name`. Keep `name`/`description` in sync with any marketplace entry that points at this plugin, but do not repeat `version` there: `plugin.json` always wins, so a stale marketplace version is silently ignored (see maintain.md).

To ship MCP servers, add a `.mcp.json` at the plugin root (auto-discovered) or point `plugin.json` at one with an `mcpServers` key. Use `${CLAUDE_PLUGIN_ROOT}` for any bundled paths, since marketplace plugins are copied into `~/.claude/plugins/cache`.

## Move existing tools in, delete the originals

Tools you already run loose from `~/.claude/` (a skill in `~/.claude/skills`, an agent in `~/.claude/agents`, hooks in your personal `settings.json`) should move INTO the plugin folder. Then delete the loose originals, otherwise the tool loads twice and you run duplicates. After moving, the plugin is the single source for those tools.

## Scaffold and validate

- `claude plugin init <name>` scaffolds a new plugin skeleton INTO your skills directory (`~/.claude/skills/<name>/`), not the current folder. A plugin living there auto-loads every session as `<name>@skills-dir`, no `--plugin-dir` flag needed, which is the smoothest path for a personal ("Just me") bundle.
- `claude plugin validate .` (or `claude plugin validate ./my-plugin`) checks the manifest and layout. It needs no login.

## Local test

```bash
claude --plugin-dir ./my-plugin
```

Loads the plugin straight from disk, no marketplace needed. It also accepts a `.zip` of the plugin. In the session, confirm every bundled tool shows up and invoke at least one. Skills are namespaced by plugin: a skill named `my-skill` in plugin `my-plugin` is invoked as `/my-plugin:my-skill`.

`claude --plugin-dir` opens an interactive session, so it needs you logged in. For a quick login-free check that the plugin is well-formed and its tools are discovered, use `claude plugin validate ./my-plugin` and `claude plugin details my-plugin`.

This local path is the whole story for a "Just me" bundle: assemble, load, verify, stop.
