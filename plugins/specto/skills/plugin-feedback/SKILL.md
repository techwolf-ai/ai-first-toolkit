---
name: plugin-feedback
description: Use to capture and file friction encountered while using specto (or other plugin) skills, so gaps become tracked work items instead of being forgotten. Triggers on "this skill should have…", "capture plugin feedback", "file specto friction", "log a plugin gap", "drain feedback", or when you notice a specto skill stopping short, misclassifying, or missing an obvious follow-up. Two modes — `--capture "<one-liner>"` appends a dated entry to `.specto/plugin-feedback.md` mid-session (cheap, no prompts); `--drain` (the default) walks pending entries and offers to file each as a forge work item, rewriting the local line to its `→ !N` (GitLab) / `→ #N` (GitHub) pointer.
---

# Plugin feedback

Bakes the specto plugin-feedback loop into the plugin itself. Friction surfaced while using `specto:*` skills — a skill not prompting for an obvious follow-up, misclassifying, hitting a missing case, or stopping short of what the workflow needs — gets captured locally the moment it happens, then drained into forge work items on the plugin repo. The loop is two cheap moves: **capture** in-flight, **drain** at a natural break.

This is the one skill that owns the convention. Don't re-derive the capture-file path or format from memory — it lives here.

## Capture-file convention

- **Path:** `.specto/plugin-feedback.md` in the repo you're working in.
- **Format:** one entry per line. Once filed, the same line gains a `→ !N` (GitLab) / `→ #N` (GitHub) pointer (so a glance shows what's pending vs filed):

  ```
  - YYYY-MM-DD <plugin>:<skill>: short description of the gap
  - YYYY-MM-DD <plugin>:<skill>: short description → !<N>   # once filed
  ```

- **Gitignored, deliberately.** `plugin-feedback.md` is **not** whitelisted in `.specto/.gitignore` — it stays local. Friction notes are in-flight personal scratch; the durable record is the filed work item (the `→ !N` pointer is just a local breadcrumb). Do **not** add `plugin-feedback.md` to the `.specto/.gitignore` whitelist to "fix" it being untracked — that is the intended state. (Contrast `v2-candidates.md`, which *is* whitelisted because it must survive an MR.)

If `.specto/.gitignore` does not exist yet, scaffold it (same snippet `new-spec` uses) so the catch-all keeps `plugin-feedback.md` local:

```bash
if [ ! -f .specto/.gitignore ]; then
  mkdir -p .specto
  cat > .specto/.gitignore <<'EOF'
*
!.gitignore
!config.yml
!okrs.md
!v2-candidates.md
EOF
fi
```

## `--capture "<one-liner>"`

Cheap, append-only, no prompts. Call it the moment friction is felt — mid-flow, while the context is fresh.

1. Ensure `.specto/.gitignore` exists (scaffold per the snippet above).
2. If `.specto/plugin-feedback.md` doesn't exist, create it with a one-line header (`# Plugin feedback (local scratch — drain with \`plugin-feedback --drain\`)`).
3. Append `- <today's date> <one-liner>`. Prefix the one-liner with `<plugin>:<skill>:` when known (e.g. `specto:resolve-spec-comments: …`).
4. Confirm in one line that it was captured. Don't prompt, don't offer to file — that's `--drain`'s job.

## `--drain` (default when no flag)

Interactive. Walks pending entries and files the ones the user picks.

1. Read `.specto/plugin-feedback.md`. **Pending** entries are lines without a `→ !N` / `→ #N` pointer. If there are none, say so and stop.
2. List the pending entries and ask the user which to file (multi-select). Filing is opt-in per entry — never file an entry the user didn't pick.
3. For each chosen entry, draft a richer **title** and **body** with the user (the captured one-liner is just the seed). Mirror the structure of the existing items in the repo: a `## Proposal` / `## Why this is worth doing` / `## Encountered on` shape. Confirm the title and body before filing.
4. Write the body to a temp file and file the work item:

   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/forge/create-issue.sh" "<title>" <body-file> --repo "$("${CLAUDE_PLUGIN_ROOT}/scripts/plugin-config.sh" get feedback_repo)"
   ```

   The target repo comes from the `feedback_repo` machine config key (where your team collects plugin friction). If it is unset, tell the user to set it (`plugin-config.sh set feedback_repo <owner/repo>`) and stop — never guess a repo. The helper prints **only the new issue IID/number** on stdout.
5. Rewrite that entry's local line to append `→ !<IID>` (`!` on GitLab, `#` on GitHub). Leave already-pointered entries untouched.

## Hard rules

- **All forge writes go through `${CLAUDE_PLUGIN_ROOT}/scripts/forge/create-issue.sh`** — never inline the forge CLI (`glab issue create` / `gh issue create`).
- **`plugin-feedback.md` stays gitignored.** Never whitelist it.
- **Capture never prompts; drain never files an unselected entry.** Keep the two modes distinct so capture stays cheap enough to use mid-flow.
- **Never re-file a pointered entry.** A line already carrying `→ !N` is done.

## When this skill should NOT run

- It's not friction with a plugin skill — a genuine bug in the user's own code is `systematic-debugging`, not this.
- For *spec*-scope deferrals from MR review, `resolve-spec-comments` already routes to `.specto/v2-candidates.md`; this skill is for *plugin/tooling* friction, not spec content.

## Optional: session-end draining (not wired in this version)

`context-flywheel:reflect-context` (or a Stop hook at maturity level L4) *could* invoke `--drain` automatically at session-end, so pending friction never rots. That wiring is intentionally **not** shipped here — drain stays user-invoked for now. If you want it automatic, add a Stop hook in `.claude/settings.json` that runs the drain step (hand the hook change to the `update-config` skill).
