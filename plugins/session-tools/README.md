# Session Tools

Three skills for session continuity — finding past sessions, preserving the current one, and launching autonomous runs.

- **`session-search`**, find a specific past session by title, working directory, time range, or free-text content across every transcript on disk.
- **`handoff`**, write a tight resume note at the end of a session so the next session can pick up exactly where you left off, without replaying the conversation.
- **`goal-prompt`**, turn a task, plan, or feature request into a ready-to-paste `/goal` command with a measurable end state, a demonstrable proof, and the constraints that must not drift.

## Getting Started

1. Install the plugin via Claude Code marketplace or `./install.sh session-tools`.
2. Use `/session-search` any time to dig up a past session.
3. Use `/handoff` at the end of any session to save your place; say "pick up the handoff" next session to continue.

## Skills

| Skill | What it does |
|-------|-------------|
| `/session-search` | Find a past session by title, working directory, time range, or full-text content |
| `/handoff` | Write a tight resume note so the next session starts from exactly where you stopped |
| `/goal-prompt` | Turn a task into a ready-to-paste `/goal` command for an autonomous Claude Code run |

## `session-search`

> **Platforms: Claude Code / Cowork and Codex.** `find_sessions.py` and `show_session.py` detect the host (via the `platform` stamp `install.sh` writes, or `AI_FIRST_PLATFORM`) and route to the right store: Claude Code (`~/.claude/projects`) + Cowork transcripts, or Codex rollouts (`~/.codex/sessions/**/rollout-*.jsonl`). **Antigravity is not supported**: its IDE conversations are AEAD-encrypted at rest and its CLI store carries no parseable turn content; the skill prints a clear "not available" message and exits.

Two scripts in `scripts/` locate past sessions and dump their content:

- `find_sessions.py` — discover and filter sessions (metadata and optional full-text grep).
- `show_session.py` — print a single session's conversation in readable form.

Both read directly from disk — no API calls, no auth. Paths resolve from `$HOME`:

- Claude Code CLI: `~/.claude/projects/*/*.jsonl`
- Claude Cowork: `~/Library/Application Support/Claude/local-agent-mode-sessions/*/*/local_*/audit.jsonl`

### How to use

Start narrow, widen if needed. Prefer `--grep` for content recall; use metadata filters to scope.

**Step 1 — find candidate sessions**

```bash
scripts/find_sessions.py --grep "recruitee logo api"      # content search
scripts/find_sessions.py --title "rippling"               # title substring
scripts/find_sessions.py --cwd "Recruitee"                # Code sessions under matching cwd
scripts/find_sessions.py --since 2026-03-01 --until 2026-03-31
scripts/find_sessions.py --kind cowork -n 30              # 30 most recent Cowork
```

Combine freely. Output is a table by default; add `--json` for structured piping.

`--grep PATTERN` is a regex (case-insensitive). It searches message text and prints 1-2 matching snippets per session.

**Step 2 — pull full context from a specific session**

```bash
scripts/show_session.py <path-from-step-1>       # full conversation
scripts/show_session.py <path> --grep "logo"     # only turns mentioning "logo"
scripts/show_session.py <path> --tail 20         # last 20 turns
```

### Filter reference

`find_sessions.py` flags:

- `--kind {code,cowork,all}` — default `all`
- `--since YYYY-MM-DD`, `--until YYYY-MM-DD` — by last-activity mtime
- `--title TEXT` — substring, case-insensitive
- `--cwd TEXT` — substring match against the working directory (Code sessions)
- `--grep PATTERN` — regex across transcript body
- `-n, --limit N` — cap results (default 50, `0` = all)
- `--snippets N` — matching lines to show per session under `--grep` (default 2)
- `--json` — machine-readable output

Sample phrasings:

- `where did I work on X`
- `find that session where I built the widget`
- `when did I last touch the recruitee integration`
- `pull up the conversation about Zyte`
- `/session-search`

## `handoff`

Writes a tight `HANDOFF.md` resume note at the current working directory so a fresh session can continue without replaying the conversation. Two modes:

- **Write** (default): `handoff`, `wrap up`, `park this session`, `save where we are`. Captures goal, what's done vs open, the single most concrete next step, decisions made, dead ends, run state (branch, tree, processes), a verify command, and open questions. Appends newest-first, keeps the 3 most recent entries; replaces today's entry rather than stacking.
- **Read**: `/handoff read`, `pick up the handoff`, `read the handoff`. Reads `HANDOFF.md` from cwd, surfaces the most recent entry's goal and Start-here steps, warns if the handoff is stale relative to git history, and asks before acting.

The skill writes to the project directory, not to tool memory. No platform dependency — works in Claude Code, Cowork, and any other Claude Code-compatible host.

Sample phrasings:

- `handoff`
- `wrap up`
- `park this session`
- `save where we are`
- `pick up the handoff`
- `read the handoff`
- `/handoff read`

If the directory is a git repo, the skill offers to add `HANDOFF.md` to `.gitignore` rather than staging it.

## `goal-prompt`

Turns whatever you are trying to accomplish into a single ready-to-paste `/goal` command for an autonomous Claude Code run. A good goal has three parts, and the skill enforces all of them:

1. A measurable end state: one concrete finish line (a passing test, a file that must exist, a count, an empty queue).
2. A stated proof: exactly how Claude demonstrates completion in its own output, since the `/goal` evaluator only reads the transcript.
3. Constraints that must not drift: files not to touch, framing to keep, no network or prod.

Output is one fenced `/goal ...` block plus 2-3 lines explaining why the end state is demonstrable.

Sample phrasings:

- `give me a goal`
- `turn this into a goal`
- `make this a /goal`
- `/goal-prompt`

## Requirements

- Claude Code ≥ 2.x
- session-search: Python ≥ 3.10 (stdlib only; no pip install needed), macOS primary; Linux falls back to Code-only; Windows supported for Cowork path resolution
- handoff, goal-prompt: no additional requirements

## Attribution

Skill sources: `skills/session-search/`, `skills/handoff/`, `skills/goal-prompt/`.
