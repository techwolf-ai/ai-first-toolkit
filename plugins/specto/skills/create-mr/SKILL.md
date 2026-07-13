---
name: create-mr
description: Use when the user wants to turn the current branch into a merge request (MR) / pull request (PR). Triggers on "create MR", "open merge request", "make an MR", "push and create MR", "submit MR", "create PR", "open pull request", "submit for review". For end-to-end ticket → branch → MR flows that anchor to a specto spec, use `implement-ticket` instead — this skill is for the standalone "I have changes, ship them" case.
argument-hint: "[ticket-key]"
allowed-tools: Bash, Read, AskUserQuestion
---

# create-mr

Turn the current branch into a draft MR on the forge (GitLab/GitHub) linked (when applicable) to a tracker ticket. Shells out to the vetted helpers under `${CLAUDE_PLUGIN_ROOT}/scripts/forge/` and `${CLAUDE_PLUGIN_ROOT}/scripts/tracker/` — never inline the forge/tracker CLIs (`glab`/`gh`/`acli`). Exit codes: `0` ok · `1` data missing · `2` bad usage · `3` external-command failure; warnings land on stderr.

**Invocation.** This skill is intentionally model-invocable (no `disable-model-invocation`) so flows like `implement-ticket` and `resolve-mr-comments` can hand off to it. Its safety gate is that the MR is created as a **draft** and `create-mr.sh` is idempotent — a re-run updates the existing branch MR rather than opening a duplicate, so an accidental invocation is recoverable rather than destructive.

## Prerequisite check

- The forge CLI (`glab`/`gh`) is on PATH and authenticated (the forge CLI auth check, `glab auth status` / `gh auth status`, succeeds).
- The current directory is inside a git repo with a configured forge remote (GitLab or GitHub).
- The tracker CLI (`acli` for Jira) is on PATH if a ticket is being linked (warn but do not abort if missing — the MR can still be created without a tracker link).
- The working tree is not detached HEAD on a tag.

## Inputs the user provides

- **Ticket key** (optional argument, e.g. `APP-1234`). If absent, ask whether the changes should be linked to an existing ticket, create a new one (dispatch `create-ticket`), or skip tracker linking entirely.
- **Reviewer** (optional). Default reviewer is `@me`; if `.specto/config.yml` defines a `reviewers:` list, use those instead.
- **Target branch** (optional). Defaults to the repo's default branch.

## Steps

### 1. Prepare the branch

- If on the repo's default branch (`main`, `master`, or whatever `git symbolic-ref --short refs/remotes/origin/HEAD` reports), create a new feature branch first. Branch name rules:
  - Maximum 20 characters.
  - Prefix by type: `f-` (feature), `fix-` (bug fix), `r-` (refactor).
  - Short kebab-case slug after the prefix (`f-add-export`, `fix-login`, `r-clean-utils`).
  - Do NOT include ticket keys — they make branch names and staging URLs too long.
  - Validate: `[[ ${#BRANCH} -le 20 ]] || error`.
- If there are uncommitted changes: stage the relevant files (`git add <paths>` — never `git add .`) and commit with a short imperative summary derived from the diff. Don't fetch the ticket yet — that happens in step 2 so the title in the MR (not the commit) carries the key.
- Push the branch: `git push --set-upstream origin <current-branch>` if no upstream, otherwise plain `git push`.

### 2. Resolve the tracker ticket (optional)

- If the user supplied a ticket key, fetch it for the MR title/description:
  ```bash
  "${CLAUDE_PLUGIN_ROOT}/scripts/tracker/get-ticket-description.sh" "<KEY>"
  ```
  Capture the summary and (if present) acceptance criteria for the description.
- If the user did NOT supply a key:
  - Offer to invoke the `create-ticket` skill to create one (only Task or Bug — keep this fast; reach for the full skill for more nuanced types).
  - Or skip tracker linking entirely and proceed with a ticketless MR.

### 3. Draft the MR title and description

- **Title:** `[<KEY>] <ticket summary>` when a ticket exists, otherwise derive from the branch name + most recent commit subject. No `[WIP]` prefix — the MR is created as a draft via `--draft` internally.
- **Description:** the standalone-MR template lives inline here (each skill owns its own template; `implement-ticket` has a different one because spec-tracked work has more upstream context):

  ```markdown
  ## Summary

  <bulleted list of what changed>

  ## Test plan

  <bulleted list of how it was verified — commands run, tests added>

  ## Ticket

  [<KEY> — <ticket summary>](<url from "${CLAUDE_PLUGIN_ROOT}/scripts/tracker/ticket-url.sh" <KEY>>)
  ```

  Drop the `## Ticket` section entirely if the MR is ticketless.

### 4. Create the MR

Write the description to a temp file (or pipe via stdin) and call:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/forge/create-mr.sh" \
  "<TITLE>" "<DESCRIPTION_FILE_OR_-->" \
  --reviewer '@me'
```

The helper is idempotent: if an MR already exists for the current branch, it updates that existing MR instead of creating a duplicate. It always creates as `--draft`; flip out of draft with `${CLAUDE_PLUGIN_ROOT}/scripts/forge/mr-ready.sh` once the work is ready for review.

To add more reviewers, pass `--reviewer <user>` repeatedly. To target a non-default branch, pass `--target <branch>`.

### 4b. Transition the ticket to "In Review" (when a key was supplied)

Once the MR is open, move the tracker ticket forward so the board reflects that the work is up for review. The transition helper warns-and-continues if the target status name doesn't match the project's workflow — never block on this.

```bash
[[ -n "$TICKET_KEY" ]] && \
  "${CLAUDE_PLUGIN_ROOT}/scripts/tracker/transition-ticket.sh" "$TICKET_KEY" "In Review"
```

Skip entirely if the MR is ticketless. Re-running on an MR whose ticket is already in `In Review` is a no-op (the helper recognises the current state and either swallows it or warns).

### 5. Output

Print the MR web URL (returned on stdout by the helper) as a clickable markdown link. If a ticket was linked, also point the user at the ticket URL. Don't write any planning file — the MR description lives on the forge.

### 6. List pending manual CI jobs

Manual jobs (staging deploys, teardowns, …) are intentional gates — the skill must not trigger them, but it must SHOW them so the user can decide. Use pipeline-status's `--manual-jobs` mode, which prints `<stage>\t<name>\t<web_url>` per manual job (empty stdout if none):

```bash
manual="$("${CLAUDE_PLUGIN_ROOT}/scripts/forge/pipeline-status.sh" --manual-jobs)"
if [[ -n "$manual" ]]; then
  printf '%s\n' "$manual" | awk -F'\t' '{ printf "- **%s/%s** — %s\n", $1, $2, $3 }'
fi
```

If the rendered list is non-empty, append it under a `## Manual jobs pending` heading in the chat response. Example:

> ## Manual jobs pending
> - **deploy/staging-deploy** — https://gitlab.com/…/jobs/12345
> - **teardown/staging-teardown** — https://gitlab.com/…/jobs/12346

If the list is empty, omit the heading entirely. This makes the "don't auto-trigger" rule actionable rather than aspirational.

## Hard rules

- **All forge CLI calls go through the helper.** Never inline `glab`/`gh` (`glab mr create` / `glab mr update`) in a skill — the helper handles the create-vs-update decision, the `--draft` flag, and the multi-reviewer comma joining.
- **`@me` is quoted.** `'@me'` (single quotes) is the canonical form — zsh extended glob can otherwise eat it.
- **No ticket keys in branch names.** Branch lengths drive staging-URL lengths on many setups; keep them short (this skill caps at 20 characters).
- **Commit before MR.** `scripts/forge/create-mr.sh` exits non-zero if the branch has nothing to MR; commit + push first.
- **Do NOT trigger manual CI jobs.** They are intentional gates (staging deploys, teardowns). List them for the user instead.

## When this skill should NOT run

- The user wants to implement a tracker ticket end-to-end (anchored to a spec section, TDD-driven) — use `implement-ticket`, which composes the ticket fetch, branch creation, TDD loop, and MR open into one flow.
- The MR already exists and the user is iterating on reviewer feedback — use `resolve-mr-comments`.
- The user wants reviewer feedback on a spec — `review-spec` runs the lint pre-pass + reviewer agents.
