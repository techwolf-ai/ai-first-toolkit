---
name: goal-prompt
description: Turn a task, plan, or feature request into a ready-to-paste Claude Code /goal command — a single completion condition with a measurable end state, a demonstrable proof, and the constraints that must not drift. Use when the user says "give me a goal", "goal prompt", "make this a /goal", "turn this into a goal", or wants an autonomous long-running objective for Claude Code.
---

# goal-prompt

Produce a ready-to-paste `/goal ...` command from whatever the user is trying to accomplish.

## Why the shape matters
`/goal` runs Claude autonomously until a separate fast-model evaluator decides, after a turn, that the condition is met. The evaluator does NOT run commands or read files itself — it only reads Claude's output. So the completion condition must be demonstrable by Claude's own output, never by hidden side effects.

## A good goal has three parts
1. **Measurable end state** — one concrete finish line: a test/exit code, a file that must exist, a count, an empty queue, named sections present.
2. **Stated proof** — exactly how Claude demonstrates it: the command to run and its expected result, or the grep/check whose output shows done. Phrase it as "Prove it by showing X."
3. **Constraints that must not drift** — what stays unchanged on the way there: files not to touch, framing to keep, no network/prod, don't modify tests.

## How to write it
- One sentence of objective, then `Done when: <end state + proof>`, then `Constraints that must not change: <list>`.
- If the full spec is long, point to a plan/doc file (e.g. a path under `~/.claude/plans/` or `docs/`) and keep the goal itself scannable.
- Make the proof something the transcript can show: prefer `command exits 0` + a summary line, or `grep` for markers, over vague "it works".
- Translate conditions the evaluator can't see ("the UI looks good") into an observable check.
- Keep constraints tight enough to stop scope creep, not so rigid they block the obvious path.

## Output
Give the user a single fenced block starting with `/goal`, then 2-3 lines explaining the end state, the proof, and why it's demonstrable. Nothing else.

## Example
```
/goal Add a --json flag to the export CLI per docs/export-json.md. Done when: `pytest tests/test_export.py -q` exits 0 and `python -m app.export --json` prints valid JSON whose top-level keys include "rows" and "meta". Prove it by showing the pytest summary and the piped `... --json | jq keys` output. Constraints that must not change: only edit app/export.py and add tests/test_export.py; do not alter the existing CSV output path; no network.
```
Its finish line is a passing test plus a schema check, both visible in Claude's transcript; the constraints pin the blast radius so the autonomous run can't wander.
