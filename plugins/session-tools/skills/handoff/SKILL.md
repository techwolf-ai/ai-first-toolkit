---
name: handoff
description: Write a session handoff at the end of a session so the next session can start from where this one stopped without rereading the whole conversation. Use when user says "handoff", "wrap up", "write a handoff", "end of session", "park this session", "save where we are", or to RESUME with "/handoff read", "pick up the handoff", "read the handoff". Writes a tight resume note (HANDOFF.md) into the working directory, not a full transcript. Scope is the current project's resume note only: not searching or summarizing past sessions, and not any project-specific "resume" command the environment may have.
---

# Handoff

Capture the minimum a fresh session needs to continue this work: what it is, where it stands, the exact next action. The next session reads ONE file instead of replaying the conversation. Optimized for "start from here", not "understand everything that happened".

The handoff is written to **the current working directory** (the project/folder being worked in), as `HANDOFF.md` at its root. It travels with the project, not with any tool's memory.

Two modes:
- **Write** (default): no args, or "handoff", "wrap up", "park this session", "save where we are".
- **Read**: "/handoff read", "pick up the handoff", "read the handoff".

**Scope.** Handoff only reads/writes the resume note in the current project directory. It does not search or summarize past sessions ("where did I work on X / when did I last do Y" is a different job). And a bare "resume" or "continue" may belong to a project-specific resume command rather than this skill — only fire handoff-read on the explicit phrasings above.

## Write mode

### 1. Reconstruct the session from THIS conversation

Do NOT re-run searches or re-read source files. Pull everything from what already happened in this session:

- The actual goal being worked toward (the real one, not the first ask if it shifted).
- What got done vs. what's still open.
- The exact next step — the single most concrete thing the next session should do first.
- Decisions made and WHY (so the next session doesn't relitigate them).
- Dead ends and out-of-scope lines already drawn (so the next session doesn't repeat them or wander).
- Run state being inherited: branch, dirty/clean tree, any long-running or background processes/servers still in flight (and their ports), env set this session. If your environment exposes them, note background jobs or the model tier too.
- How to verify "done": the command that proves the done-claims are real, and its expected result.
- Files created/edited, commands that matter, branches/PRs, links.
- Open questions waiting on the user.

Skip the file if there's no meaningful **open next action** (a quick lookup, a finished one-off). A handoff isn't worth writing when there's nothing to start from. Offer it instead of forcing it.

Never put secrets (API keys, tokens, PII) or unresolved placeholders in the file.

### 2. Locate the target file

- Determine the working directory (e.g. `pwd`) and state the resolved target path in your report before writing. A handoff in the wrong project is worse than none.
- If the session's work spanned more than one directory, target the dir where the *next action* happens, and say which you chose.
- Target: `HANDOFF.md` at the root of that directory.
- If you reference a weekday, verify it programmatically rather than computing it in your head. The `date` flags differ across platforms: GNU/Linux `date -d 'YYYY-MM-DD' +%A`, macOS/BSD `date -j -f '%Y-%m-%d' 'YYYY-MM-DD' '+%A'`.

### 3. Write the file

Dense bullets, not prose. Cap each entry to ~25 lines. Template for one entry:

```markdown
# Handoff — <YYYY-MM-DD> — <one-line theme>
<!-- ISO date: machine-parsed file, not user-facing display. Don't "fix" to DD-MM. -->

status: in-progress | blocked: <waiting on what> | ready-to-ship
branch: <branch> @ <short-sha> | tree: clean/dirty | running: <none / processes or servers still up>

## Goal
<one or two lines: what we are actually trying to achieve>

## Where it stands
- <bullet: done>
- <bullet: in progress>
- <bullet: not started>

## Start here (next session)
1. <the single most concrete first action>
2. <then this>
3. <then this>

## Verify
- <command the next session runs to confirm it works, and the expected result>

## Decisions made (don't relitigate)
- <decision> — because <why>

## Dead ends / out of scope (don't repeat)
- <thing tried that didn't work, or a line not to cross>

## Open questions
- <question blocking progress, or none>

## Artifacts
- <file path / branch / PR / command / link>
```

Drop any section that's empty rather than leaving a placeholder.

**Appending to an existing file:** read it and split into entries on each `# Handoff —` H1 (that header is the only delimiter — do not split on `---`). Write the new entry first, then the previous entries, newest-first. If the most recent existing entry has today's date, REPLACE it instead of stacking. Keep the 3 newest entries, drop the rest. After writing, re-read and confirm the entry count.

### 4. Report inline

Print the handoff in chat (it's the deliverable, the file is the durable copy) and end with the path. Offer to start the next step now if it's actionable.

## Read mode

1. Read `HANDOFF.md` from the current working directory. If it's not there, say so and check one level up / common subfolders before giving up. If more than one is found, prefer the one in cwd and say which you used.
2. Read only that file. Do NOT replay the conversation history or re-derive context from source.
3. Pick the entry. Default to the TOP (most recent). If there's more than one entry, list their dates + themes and confirm which thread to resume rather than auto-picking.
4. **Flag staleness.** Surface the entry's date. If a git repo has commits newer than that date (`git log -1 --format=%cd`), or the date is well in the past, warn that the handoff may be stale before acting on it.
5. **Read back before acting** (the highest-evidence error-reducer in human handoffs): restate the Goal and the **Start here** step 1 in one line, then surface Where it stands and Start here as a numbered list.
6. Ask: "Want me to pick up at step 1?" and proceed if yes. If the work reads as already landed, offer to clear the stale handoff instead.

## Notes

- This is for cross-SESSION continuity within a project. A handoff is disposable: once the work lands, it's stale. Don't treat it as permanent documentation, and don't let it grow into architecture/design docs.
- `HANDOFF.md` lives in the project. If it's a git repo, check whether the file is already tracked (`git ls-files HANDOFF.md`). Default to keeping it out of version control: if there's a `.gitignore`, offer to add `HANDOFF.md` in the same step. Never stage or commit it without asking.
- Keep it honest: if a step failed, say so in "Where it stands", and anchor every "done" to the Verify command. A handoff that overstates progress wastes the next session's time.
- The whole value is the **Start here** block. If you write nothing else well, write that.
