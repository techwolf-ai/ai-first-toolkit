# Team enablement: one-click and org-wide

Two levers past a plain marketplace: a project-level auto-enable that prompts teammates on trust, and an org-wide managed-settings enforcement that an admin controls.

## Project auto-enable (one-click for teammates)

Commit a `.claude/settings.json` to the project repo. Anyone who trusts the folder gets a one-click prompt to install the listed plugins.

```json
{
  "extraKnownMarketplaces": {
    "company-tools": {
      "source": { "source": "github", "repo": "org/plugins-repo" }
    }
  },
  "enabledPlugins": {
    "my-plugin@company-tools": true
  }
}
```

- `extraKnownMarketplaces` is an object keyed by marketplace name; the value is `{ "source": { ... } }` using the same source shapes as a marketplace entry (`github` repo, or `url` for GitLab/other).
- `enabledPlugins` is an object keyed by `"plugin@marketplace"` with a boolean value.
- On trusting the folder, teammates are prompted to install; they do not run the `/plugin` commands by hand.

## Org-wide enforcement (admin job)

For a whole org, an admin uses a managed-settings file (system-level, not per-user) to enforce policy:

- **Force-install**: push plugins to every user automatically.
- **`strictKnownMarketplaces`**: an allowlist; only these marketplaces may be added.
- **`blockedMarketplaces`**: a denylist of marketplaces users may not add.

This is an administrator action on managed machines, not something an individual sets. Flag it as such when the audience is a large org.
