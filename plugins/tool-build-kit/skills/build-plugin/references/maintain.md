# Maintain: updates, versions, ownership

Once a plugin is shipped, keep it updatable and owned.

## Updates

Users pull new versions with `/plugin marketplace update`, or Claude Code checks at startup. There is nothing to redeploy on your side beyond pushing to the marketplace repo.

## Version boundary

Set `version` (semver) in `plugin.json`. Users only get an update when you bump it, so a version bump is a clean, intentional update boundary. Omit `version` everywhere and Claude Code falls back to the git commit SHA, treating every commit as a new version, which is noisier than you usually want. Claude Code resolves the version from `plugin.json` first, then the marketplace entry, then the commit SHA, so do not set `version` in both places: `plugin.json` always wins, and a stale one there silently masks the value in the marketplace entry.

## Ownership

One maintainer per plugin. Because the source is a git repo, fixes and new tools land the normal way: a merge request against the marketplace repo, reviewed and merged, then a version bump. Contributors do not need any special plugin tooling, just the git host's PR/MR flow.

## Admin controls (team/org)

Org-wide update and install policy (force-install, allowlist, denylist) lives in a managed-settings file set by an administrator, not per user. See `team-enablement.md`. Keep the maintainer role and the admin role distinct: the maintainer ships versions, the admin decides which marketplaces and plugins are allowed on managed machines.
