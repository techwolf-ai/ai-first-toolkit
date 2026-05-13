# Automation filters

Sessions matching any of these get `is_automation: true` in the inventory and are excluded from Phase B–D. They stay visible in the explorer's "filtered automations" footer for transparency.

## Strong signals (any one triggers the flag)

1. **Non-cli entrypoint.** Any session with `entrypoint` set to `sdk-cli`, `api`, `cron`, or anything other than `cli`. These are programmatic invocations, not a human typing.

2. **Cowork scheduled routine path.** The session `path` contains `/agent/local_ditto_` or `/agent/local_routine_`.

3. **Paperclip cloud sandbox path.** The session `path` contains `--paperclip-instances-`. (These are already excluded by `session-search`; belt-and-braces check here.)

4. **`<scheduled-task>` opener.** First user turn contains `<scheduled-task name="…">`, Cowork scheduled runs announce themselves this way. Reason tag: `scheduled-task:<name>`.

5. **Slash-command-only opener.** First user turn is composed entirely of `<command-name>…</command-name>` / `<command-message>…</command-message>` / `<command-args>…</command-args>` blocks (possibly with surrounding whitespace), and the invoked command is in this list:
   ```
   /loop
   /schedule
   /babysit-prs
   /ultrareview
   /autonomous-loop
   /productivity:update
   /productivity:start
   ```
   Slash commands that are interactive aids (e.g. `/permissions`, `/compact`, `/fast`) do NOT trigger this flag.

## Composite signal (all three required)

1. **No freeform user prose anywhere in the transcript.** Every user turn is either a `<command-*>` wrapper, a `<task-notification>` block, a `<local-command-caveat>` wrapper, or a raw paste of structured data (JSON, code, tool output) with no natural-language framing.
2. **Short + few turns.** Duration < 5 minutes AND user+assistant text turn count < 6 (after `<task-notification>` stripping).
3. **Recurring title.** An exact-match session `summary` (Cowork `title` or Code first-line) appears ≥ 2 times on the same cwd within 7 days, suggesting a schedule.

## What this does NOT flag

- Human-run `/loop` or `/schedule` invocations where the user added a natural-language prompt after the slash, the first user turn contains freeform prose alongside the command wrapper. Keep these.
- Sessions where the user spoke to an automation later in the conversation. Keep these, they became interactive.
- Short interactive sessions. The composite signal requires all three conditions, not any one.

## `automation_reason` field

Set to a short tag: `sdk-cli`, `ditto-routine`, `paperclip`, `slash-command-opener:<cmd>`, or `composite:short-recurring`. Used for the footer breakdown.
