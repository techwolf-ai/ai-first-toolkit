---
name: session-search
description: Find context from past Claude Code (CLI) and Claude Cowork (desktop) sessions on this Mac. Use when the user wants to recall something they did before but can't find it, phrasings like "where did I work on X", "find that session where I…", "when did I last do Y", "pull up the conversation about Z", "that time I built/tried/discussed …". Searches by kind (code/cowork), time range, title, working directory, or free-text content across all transcripts.
---

# session-search

> **Platforms: Claude Code / Cowork and Codex.** `find_sessions.py` and `show_session.py` detect the host (via the `platform` stamp `install.sh` writes, or `AI_FIRST_PLATFORM`) and route to the right store: Claude Code (`~/.claude/projects`) + Cowork transcripts, or Codex rollouts (`~/.codex/sessions/**/rollout-*.jsonl`). Both support list, time/cwd/title filters, and full-text `--grep`. **Antigravity is not supported**: its IDE conversations are AEAD-encrypted at rest (`~/.gemini/antigravity/conversations/*.pb`) and its unencrypted CLI store carries no parseable turn content, so the skill prints a clear "not available" message and exits.

Two scripts in `scripts/` locate past sessions and dump their content:

- `find_sessions.py` , discover + filter sessions (metadata + optional full-text grep).
- `show_session.py` , print a single session's conversation (user/assistant turns) in readable form.

Both read directly from disk , no API calls, no auth. They resolve paths from `$HOME` so they work for any macOS user:

- Claude Code CLI: `~/.claude/projects/*/\*.jsonl`
- Claude Cowork: `~/Library/Application Support/Claude/local-agent-mode-sessions/*/*/local_*/audit.jsonl` (sibling `local_*.json` holds title/metadata)

## How to use

Start narrow, widen if needed. Prefer `--grep` for content recall; use metadata filters to scope.

### Step 1 , find candidate sessions

```bash
scripts/find_sessions.py --grep "recruitee logo api"      # content search
scripts/find_sessions.py --title "rippling"              # title substring
scripts/find_sessions.py --cwd "Recruitee"               # Code sessions under matching cwd
scripts/find_sessions.py --since 2026-03-01 --until 2026-03-31
scripts/find_sessions.py --kind cowork -n 30             # 30 most recent Cowork
```

Combine freely. Output is a table by default; add `--json` for structured piping.

`--grep PATTERN` is a regex (case-insensitive). It searches message text inside every transcript and prints 1-2 matching snippets per session along with the session row. Use this when the user remembers a phrase or topic, not a title.

### Step 2 , pull full context from a specific session

```bash
scripts/show_session.py <path-from-step-1>       # full conversation
scripts/show_session.py <path> --grep "logo"     # only turns mentioning "logo" (with ±1 surrounding turn)
scripts/show_session.py <path> --tail 20         # last 20 turns
```

The script strips tool calls/results and renders user + assistant text only. Output is markdown-ish; pipe to a pager if long.

## Filter reference

`find_sessions.py` flags:

- `--kind {code,cowork,all}` , default `all`
- `--since YYYY-MM-DD`, `--until YYYY-MM-DD` , by last-activity mtime
- `--title TEXT` , substring, case-insensitive (Cowork uses the stored title; Code uses the first user message)
- `--cwd TEXT` , substring match against the working directory recorded in Code transcripts
- `--grep PATTERN` , regex across transcript body
- `-n, --limit N` , cap results (default 50, `0` = all)
- `--snippets N` , how many matching lines to show per session under `--grep` (default 2)
- `--json` , machine-readable output

## Tips

- If the user's description is vague, run `--grep` with 2–3 alternative phrasings in parallel before narrowing.
- For Code sessions the "title" is a best-effort extraction of the first user message; for Cowork it comes from the `.json` sidecar written by the desktop app.
- A session can have many transcripts (resumes, forks). `find_sessions.py` lists each transcript separately; that's usually what you want , the most recent one is the live thread.
- Transcripts can be large (several MB). When dumping content to the user, prefer `show_session.py --grep` or `--tail` over the full file.
