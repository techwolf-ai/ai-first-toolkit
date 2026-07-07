---
name: build-plugin
description: "Bundle skills, hooks, agents, or an MCP server into one installable Claude Code plugin and ship it. Use when asked to bundle tools into one plugin, package tools for a colleague, publish a plugin to a marketplace, share my tools with my team, or ship a plugin. Asks who it's for and where it's hosted, then walks analyze, assemble, ship, and maintain, tailored to that answer. Sibling to build-mcp."
---

# Build Plugin

Bundle many tools (skills, hooks, agents, MCP servers) into one installable Claude Code plugin and distribute it. The defining move of this skill: establish who the plugin is for and where it will live with `AskUserQuestion` before assembling anything, then tailor every phase to that answer. A personal one-project bundle and a public team marketplace share almost nothing past "assemble", so branch early and commit to the branch.

## How this relates to build-mcp

`build-mcp` builds one MCP server: analyze a service, implement the tools, deploy, scale. `build-plugin` bundles many tools (including MCP servers produced by `build-mcp`) into a single shareable unit and distributes it. When `build-mcp` reaches its Distribute phase for a team or public audience, it hands off here: packaging into a plugin and listing it on a marketplace is this skill's job. Use `build-mcp` to make a server, then `build-plugin` to ship it alongside your skills, hooks, and agents.

## The four phases

1. **Analyze**: decide what tools go in the bundle, and name it.
2. **Assemble**: build the plugin folder and manifest, test it locally with `claude --plugin-dir`.
3. **Ship**: put it on a marketplace repo, on the right git host, public or private, with one-click enablement for a team.
4. **Maintain**: versions, updates, ownership, and admin controls.

Run them in order. The `AskUserQuestion` answers from Phase 0 gate Ship and Maintain.

## Phase 0: Establish context (AskUserQuestion, do this first)

Before assembling anything, branch on the user's context. Ask the **audience** question first; it is the headline decision and it cascades into everything downstream. Then ask the git host only if it is still ambiguous. Ask one question at a time.

**Question 1 (always, ask first): Audience:**

Use `AskUserQuestion`:
- header: "Audience"
- question: "Who is this plugin for? This decides where it's hosted and how it's shared."
- options:
  1. "Just me": personal bundle of my own tools, one machine or a couple of projects.
  2. "My team / org": shared internally, installed by colleagues.
  3. "Public / external": published openly for anyone to install.

**Question 2 (conditional, skip for "Just me"): Git host:**

Skip entirely for "Just me" (no remote needed). Ask for team or public:
- header: "Git host"
- question: "Where will the marketplace repo live?"
- options:
  1. "GitHub": unlocks the `owner/repo` shorthand and Anthropic's public directory.
  2. "GitLab or other git host": works via the full `https://...git` URL, no GitHub mirror needed.
  3. "Not sure yet": decide during Ship; GitHub is the smoothest default.

Confirm the resolved tuple back to the user in one line before proceeding (e.g. "Bundling a team plugin of three skills plus one MCP server, hosted on a private GitHub marketplace repo"). That tuple drives the branch table below.

## Branch table (the spine of this skill)

| Phase | Just me | Team/org (GitHub) | Team/org (GitLab/other) | Public |
|-------|---------|-------------------|-------------------------|--------|
| **Ship** | N/A, no marketplace. Load via `claude --plugin-dir`, or scaffold it in your skills dir (`claude plugin init`) to auto-load every session. | Marketplace repo on GitHub; entry `source: {source:"github", repo:"org/repo"}` or a relative `"./path"`. Private repo optional to keep it internal. | Marketplace repo on GitLab/Bitbucket/self-hosted; entry `source: {source:"url", url:"https://...git"}`. | Public marketplace repo; entry by host as above. Be deliberate: anyone who knows the repo can install, and plugins run arbitrary code. |
| **Enable** | N/A, stop here. It is already loaded on your machine. | `/plugin marketplace add org/repo` then `/plugin install name@marketplace`; or auto-enable for the team via project `.claude/settings.json`. | `/plugin marketplace add https://gitlab.com/team/plugins.git` then `/plugin install name@marketplace`; same `.claude/settings.json` auto-enable. | Same commands; `owner/repo` shorthand is GitHub-only, others use the full URL. |
| **Maintain** | Bump `version` in `plugin.json` for a clean update boundary; you are the only user. | `/plugin marketplace update`; one maintainer per plugin; fixes land via merge request. Org-wide enforcement via managed settings. | Same, via the GitLab/other merge-request flow. | Same, plus a public changelog and a clear versioning policy. |

If a cell says "N/A, stop here" for the chosen branch, say so explicitly and move on. Do not pad it. The **Enable** row is the team-facing half of Ship (turning the marketplace on for colleagues), not a separate phase.

Reference files:
- **references/assemble.md**: plugin folder layout, the manifest fields, moving existing `~/.claude/` tools in, local `claude --plugin-dir` testing, skill namespacing, `claude plugin validate`.
- **references/marketplace.md**: the `marketplace.json` shape, per-host `source` types, add and install commands, public vs private and auth.
- **references/team-enablement.md**: project `.claude/settings.json` auto-enable, org-wide managed-settings enforcement.
- **references/maintain.md**: updates, version bumps, ownership, fixes via merge request.

Load only the references the current branch and phase need. Progressive disclosure.

## Phase 1: Analyze

Decide what goes in the bundle before you build the folder.

1. **Inventory the tools.** List every skill, hook, agent, and MCP server the plugin should carry. A plugin can hold any mix; each type sits in its own place in the layout (see assemble.md).
2. **Draw the boundary.** One plugin is one coherent unit that updates together. If two groups of tools serve different audiences or version on different clocks, that is two plugins.
3. **Name it.** Kebab-case, distinct, describes the bundle not one tool inside it. The name becomes the skill namespace (`/my-plugin:skill`) and the marketplace entry key.
4. **Note what already exists loose.** Tools sitting in `~/.claude/skills`, `~/.claude/agents`, or a personal `settings.json` will move into the plugin and the loose originals get deleted, so you do not run duplicates (assemble.md covers this).

Deliverable: the plugin name plus a list of what it will contain. Confirm with the user before assembling.

## Phase 2: Assemble

Read **references/assemble.md**. Build the folder to the layout, write the manifest, then test locally.

1. Create the plugin dir. Only `plugin.json` goes inside `.claude-plugin/`; `skills/`, `agents/`, `hooks/hooks.json`, and `.mcp.json` sit at the plugin ROOT.
2. Write `.claude-plugin/plugin.json` with `name`, `description`, `version`, `author`.
3. Move the inventoried tools in and delete the loose originals.
4. Validate, then load-test. `claude plugin validate .` checks the manifest and layout with no login. `claude plugin details <name>` lists the skills, hooks, and servers it discovered, also login-free. `claude --plugin-dir ./my-plugin` (it also accepts a `.zip`) loads it into a live session so you can invoke a tool; that one needs you logged in.

For a "Just me" bundle this is the last substantive phase: it is loaded, it works, stop.

## Phase 3: Ship

Only for team or public. Read **references/marketplace.md**, and **references/team-enablement.md** for the auto-enable path. Branch on the git-host answer.

1. Create the marketplace repo, or reuse an existing one. Add `.claude-plugin/marketplace.json` at its root with `name`, `owner`, and a `plugins[]` entry for this plugin.
2. Set the entry `source` by host: relative `"./path"` if the plugin lives in the same repo, `{source:"github", repo:"owner/repo"}` for GitHub, or `{source:"url", url:"https://...git"}` for GitLab, Bitbucket, or self-hosted. There is no `gitlab` source type.
3. Choose public vs private to match the audience. A private repo keeps a team plugin internal; a public repo is installable by anyone who knows it, running arbitrary code with the user's privileges, so make that choice deliberately.
4. Confirm the install path a colleague runs: `/plugin marketplace add owner/repo` (GitHub shorthand) or the full `https://...git` URL for any other host, then `/plugin install name@marketplace`.

## Phase 4: Maintain

Read **references/maintain.md**. Branch lightly; the mechanics are the same across hosts.

1. **Updates.** Users pull new versions with `/plugin marketplace update` or at startup.
2. **Version boundary.** Bump `version` in `plugin.json` so users get a clean update boundary; omit it and Claude Code treats every commit SHA as a new version.
3. **Ownership.** One maintainer per plugin. Fixes land via merge request, since the source is a git repo.
4. **Org controls (team/public, admin job).** Force-install, an allowlist (`strictKnownMarketplaces`), or a denylist (`blockedMarketplaces`) live in a managed-settings file, set by an admin, not per user (team-enablement.md).

## Done criteria

- The plugin validates (`claude plugin validate`) and its tools show up (`claude plugin details`); loading it via `claude --plugin-dir` in a session invokes at least one.
- It is on a marketplace repo the resolved audience can reach, public or private matching that audience (or, for "Just me", it is loaded locally and there is no marketplace).
- The user can name exactly how a colleague installs it, two-command or one-click, matching the audience answer.
