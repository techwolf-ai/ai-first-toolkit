# Marketplace: list, host, install

A marketplace is a git repo with a `marketplace.json` that lists one or more plugins. Colleagues add the marketplace once, then install plugins from it.

> For the plugin-packaging and marketplace mechanics shared with build-mcp, see `../../build-mcp/references/distribute-marketplace.md`. This file stays self-contained; that one goes deeper on shipping an MCP server specifically.

## The manifest

`.claude-plugin/marketplace.json` at the marketplace repo root:

```json
{
  "name": "company-tools",
  "owner": { "name": "DevTools Team", "email": "devtools@example.com" },
  "description": "Internal DevTools plugins.",
  "plugins": [
    {
      "name": "my-plugin",
      "source": "./plugins/my-plugin",
      "description": "What the bundle does."
    }
  ]
}
```

Required: top-level `name` (kebab-case), `owner.name`, and a `plugins[]` array. Each entry needs at least `name`, `source`, and `description`. Add a top-level `description` too: without it `claude plugin validate` warns `No marketplace description provided`.

## Source by git host

The `source` field tells Claude Code where the plugin lives:

- **Same repo**: a relative path string, `"./plugins/my-plugin"`.
- **GitHub**: `{ "source": "github", "repo": "owner/repo" }`.
- **GitLab, Bitbucket, self-hosted**: `{ "source": "url", "url": "https://gitlab.com/team/plugins.git" }`. There is NO `gitlab` source type; the generic `url` source covers every non-GitHub host.
- **A subdirectory of a monorepo**: `{ "source": "git-subdir", "url": "https://...git", "path": "plugins/my-plugin" }`, which sparse-clones just that path. Handy when many plugins live in one repo.

## Add and install

Run these at your terminal as `claude plugin ...`, or inside a Claude Code session as the `/plugin ...` slash form. The terminal form:

```bash
# GitHub: owner/repo shorthand works
claude plugin marketplace add owner/repo

# Any other host: full .git URL
claude plugin marketplace add https://gitlab.com/team/plugins.git

# then install a plugin from the added marketplace
claude plugin install my-plugin@company-tools
```

In a session the same commands are `/plugin marketplace add ...` and `/plugin install ...`. The `owner/repo` shorthand is GitHub-only. Every other host uses the full `https://...git` URL. Anthropic's public plugin directory is likewise a GitHub-only convenience; a GitLab marketplace works directly, no GitHub mirror needed.

## Public vs private, and auth

- A **private** repo keeps a team plugin internal. Public GitHub repos work for team enablement just as well; a private repo is an option for keeping tools internal, not a requirement.
- **Manual** `/plugin` use rides your existing git credential helper, so a private repo just works if you can already clone it.
- **Background auto-updates** read `GITHUB_TOKEN` or `GITLAB_TOKEN` from the environment for private repos.
- Making a marketplace **public** is a real decision: anyone who knows the repo can add and install from it, and plugins run arbitrary code with the user's privileges. Do it deliberately.
