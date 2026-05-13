---
name: task-profile
description: Mine the user's Claude Code + Cowork session history into a structured task profile, what they do with AI, how often, how successfully where friction lives, then propose atomic skills that would reduce iteration. Use when the user asks to "analyse my Claude use", "build a task profile", "what tasks do I do with Claude", "where am I spending tokens", "what skills would help me", or mentions reviewing past sessions for patterns. Produces profile.csv (shareable), explorer.html (personal coaching view with AI-first principle comparison + token-spend chart), and skill-proposals.md.
---

# task-profile

End-to-end skill: session inventory → LLM clustering → parallel Haiku analysis → aggregation → branded explorer HTML + shareable CSV + atomic skill proposals.

## When to run

When the user asks to understand their own Claude usage patterns: what tasks they repeat, how much friction those tasks generate where tokens go which principles they already follow vs. where they slip, and which new skills would compound across many tasks.

## Prerequisites

- Session history on this machine:
  - Claude Code: `~/.claude/projects/*/\*.jsonl`
  - Claude Cowork: `~/Library/Application Support/Claude/local-agent-mode-sessions/*/*/local_*/audit.jsonl`
- The `session-search` skill is already installed at `~/.claude/skills/session-search/` (optional but recommended; this skill does its own inventory pass).
- None beyond Python 3, the HTML generator ships with its own light theme baked in. No external design or logo skill required.

## Workflow

Run from any working directory, outputs land under `./out/` in that directory.

### Phase A, Inventory (deterministic script)

```bash
~/.claude/skills/task-profile/scripts/inventory.py --out out/inventory.json
```

Flags: `--since YYYY-MM-DD`, `--until YYYY-MM-DD`, `--all` (default window: last 6 months).

Writes per-session rows with: summary, token totals (per model, from `message.usage`), automation flag + reason, and a structured condensate (intent turns + correction turns + tool-flail episodes + outcome turns). Automated sessions (paperclip, scheduled-task, sdk-cli, ditto-routine) are flagged and excluded from downstream analysis but kept for transparency.

### Phase B, Cluster (main agent reads + judges)

You (the main agent) read the non-automation rows and group them into ~40–80 clusters by judgment, no scripted heuristics past cwd. Write `out/clusters.json`. Merge sessions with the same cwd, similar Cowork titles, or clearly similar topics. Show the cluster list to the user before the Haiku fan-out so they can adjust.

### Phase C, Per-cluster payloads + Haiku fan-out (parallel)

Run `out/build_payloads.py` (generated per-run, sample below) to produce one payload per cluster. Sampling: ≤ 10 sessions → all included; > 10 → include 10 biased to outliers (3 longest by turns, 3 most corrections, oldest, newest, even-spaced fill).

Dispatch one `Agent(subagent_type="general-purpose", model="haiku", run_in_background=true)` per cluster **in parallel**. Each subagent reads:

1. `~/.claude/skills/task-profile/references/task-style.md`
2. `~/.claude/skills/task-profile/references/success-rubric.md`
3. `~/.claude/skills/task-profile/references/friction-signals.md`
4. Its cluster payload at `out/payloads/<cluster_id>.json`

And emits strict JSON to `out/analyses/<cluster_id>.json` with a 1–3 task list per cluster.

### Phase D, Aggregate (main agent + script)

You (the main agent) read `out/analyses/*.json`, decide cross-cluster merges, and write `out/canonical-merges.json` with entries of the form:

```json
{"canonical": "<sentence>", "category": "<cat>", "source_tasks": [{"cluster": "...", "match": "<substring>"}]}
```

Then run:

```bash
~/.claude/skills/task-profile/scripts/write_profile.py
```

The script normalises success/category enums, applies redaction one more time, sums tokens per task from the inventory (no estimation, real `message.usage` values), and writes:

- `out/profile.csv`, shareable, one row per canonical task, with `tokens_by_model` as a compact string.
- `out/profile.json`, richer, includes per-task friction points and session list (for the explorer).

### Phase E, Coaching panel + skill proposals (main agent, MANDATORY)

**Do not skip this phase.** The explorer is half-empty without it. `build_explorer.py` will refuse to run unless both `out/coaching-panel.json` and `out/skill-proposals.json` exist; override with `--allow-empty` is only for debugging.

#### E.1, Coaching panel

Read `out/profile.json` and `~/.claude/skills/task-profile/references/ai-first-principles.md`. Pick 3–5 principles where the user has a clear, evidenced gap. For each, cite ≥ 1 good-example session path and ≥ 1 friction-example session path. Write `out/coaching-panel.json`.

Schema:

```json
{
  "cards": [
    {
      "principle": "<short name of the habit>",
      "pattern": "<one-line description of the observed pattern>",
      "good_example": {"description": "<what worked here>", "session_path": "<path>"},
      "friction_example": {"description": "<what slipped>", "session_path": "<path>"},
      "suggested_adjustment": "<concrete habit to try next time>"
    }
  ]
}
```

#### E.2, Skill proposals

**Step 1, MANDATORY: enumerate what's already installed.** Before you write a single proposal, list every skill the user already has access to:

```bash
# User-level skills
ls ~/.claude/skills/ 2>/dev/null
# Project-level skills (if present)
ls .claude/skills/ 2>/dev/null
# Plugin-namespaced skills (read SKILL.md frontmatter to capture `description`)
for f in ~/.claude/plugins/cache/*/*/skills/*/SKILL.md ~/.claude/plugins/*/skills/*/SKILL.md; do
  [ -f "$f" ] && echo "=== $f ===" && head -5 "$f"
done 2>/dev/null
```

Also scan the transcripts: any `mcp__...` tool call, any `/<namespace>:<name>` slash command the user has typed, and anything the `coaching-panel.json` cites as "you do this well already", all of those are skills already in play. Collect the full list into a working set before proposing anything.

**Step 2, de-duplicate against reality.** For every task cluster you might propose a skill for, ask:
- Is there already an installed skill whose `description` covers this territory? If yes, DO NOT propose a parallel skill. Either skip the proposal or reframe it as "enhance `<existing-skill>` with X", scoped narrowly to the gap.
- Is the gap just that the user doesn't know the skill exists, or that the trigger description is weak? If yes, the proposal is "update trigger for `<existing-skill>`", not a new skill.
- Does this overlap with a plugin skill (e.g. a memo template, a design system, a people-management namespace)? Plugins already ship the canonical implementation; re-inventing them is noise.

A proposal that duplicates an installed skill is a worse recommendation than no proposal at all. Five sharp proposals are better than five padded ones, and two sharp proposals beat five mediocre ones. **Do not pad the list to reach 5.**

**Step 3, propose.** Up to 5 atomic skills, each impacting ≥ 2 top tasks (breadth) and following the **task-centric** shape: prescriptive `mandatory_steps`, bundled sources-of-truth (guidelines, prior-art scripts, templates), fixed `output_shape`, invocation-as-slash-command. Avoid abstract workflow shapers ("opener-template", "staged-drafts", "checkpoint"), these sit outside a task and so don't get invoked in context.

For each proposal emit to `out/skill-proposals.json`:

- `name`, slug for the skill
- `trigger_description`, SKILL.md frontmatter description
- `modelled_after`, the existing installed skill it takes inspiration from, one line (REQUIRED, non-empty, references a real skill from Step 1)
- `overlaps_considered`, list of installed skills that cover adjacent territory + one-line why this proposal is still distinct (REQUIRED; empty list is only valid if the domain is genuinely uncovered)
- `mandatory_steps`, ordered list the skill runs every time (MANDATORY reads of guidelines/prior-art/references)
- `output_shape`, fixed filename convention + required sections
- `tasks_impacted`, ≥ 2 entries with `task_id` + `why_relevant`
- `expected_savings`, small/medium/large + why
- `invocation_hint`, `/skill-creator <name>`

Add a top-level `_installed_skills_checked` array to `skill-proposals.json` listing every skill enumerated in Step 1, so the user can verify the pre-check actually ran.

### Phase G, Persona card (main agent, MANDATORY)

**Do not skip.** `build_explorer.py` refuses to run without `out/persona.json`.

1. Run the deterministic feature helper:
   ```bash
   ~/.claude/skills/task-profile/scripts/persona_features.py
   ```
   Produces `out/persona-features.json` with the numbers only.
2. Read `~/.claude/skills/task-profile/references/personas.md` (the 20-persona catalogue + fallback Explorer).
3. Read `out/persona-features.json`, `out/profile.json`, `out/coaching-panel.json`, `out/skill-proposals.json`.
4. Pick **one primary persona** whose triggers fire most clearly in the feature sheet. Break ties by coherence with the coaching cards. If fewer than ~10 interactive sessions, pick **The Explorer**.
5. Optionally pick **one secondary modifier**. Leave `modifier: null` when none fits cleanly.
6. Write a 40–60-word tailored blurb, in second person, opening with a concrete behaviour and including one surprising number from the feature sheet. No em-dashes, hype words, brand names. Voice: observant friend, not marketing coach.
7. Write `out/persona.json`:

```json
{
  "id": "<persona-slug>",
  "name": "<The Xxxx>",
  "tagline": "<catalogue tagline>",
  "modifier": "<slug or null>",
  "confidence_note": "<why this persona beats the others, one sentence>",
  "blurb": "<your rewritten 40–60-word blurb>",
  "highlight_stat": {"label": "<short>", "value": <number>},
  "top3_task_names": ["<short>", "<short>", "<short>"],
  "features_used": { ... relevant numbers cited in the blurb ... }
}
```

### Phase F, Explorer HTML

```bash
~/.claude/skills/task-profile/scripts/build_explorer.py
```

Fixed light theme baked into the generator: off-white background, aquamarine accents, subtle dot-grid atmosphere, Geist sans-serif via Google Fonts, glassmorphism adapted for light. Single-file, no network at runtime (fonts via CDN). Data embedded as a JSON blob. Uses **progressive disclosure**, categories open to reveal tasks; tasks open to reveal friction and tokens; coaching and proposals open to reveal detail. Includes:

- Token-spend chart (horizontal stacked bars per task, clickable to jump to task detail)
- Sortable/filterable task table with search, category, min-frequency, since-date
- Row-click expands per-task detail: friction points with what-would-prevent guidance, per-model token table, session list
- Personal coaching panel (AI-first principle comparison)
- Skill proposals cards
- Automation-filter transparency footer

Open with `open out/explorer.html`.

## Final manual review

Before considering the run done, scan `out/profile.csv` and the explorer for the top-100 highest-entropy tokens (any random-looking string of mixed case + digits ≥ 16 chars). These are the most likely way a secret slipped past automated redaction. Ask the user to confirm the scan is clean.

## Outputs at a glance

| File | Audience | Shape |
|---|---|---|
| `out/inventory.json` | Internal | Full per-session rows with condensates |
| `out/clusters.json` | Internal | `[{cluster_id, label, session_paths}]` |
| `out/payloads/*.json` | Haiku subagents | Sampled condensates per cluster |
| `out/analyses/*.json` | Internal | Haiku output, 1–3 tasks per cluster |
| `out/canonical-merges.json` | Internal | Main-agent cross-cluster merge decisions |
| `out/profile.csv` | Shareable with company | One row per canonical task |
| `out/profile.json` | Feeds the explorer | Rich task rows + session detail |
| `out/coaching-panel.json` | Feeds the explorer | Personal AI-first coaching cards |
| `out/skill-proposals.json` | Feeds the explorer + user action | Up to 5 cross-cutting skill proposals |
| `out/explorer.html` | Personal | Single-file UI with progressive disclosure |

## References

- `references/task-style.md`, CSV-style task sentence rules, good/bad examples
- `references/success-rubric.md`, 4-level success taxonomy with signals
- `references/friction-signals.md`, correction phrases + behavioural markers
- `references/automation-filters.md`, rules for flagging non-interactive sessions
- `references/redaction-rules.md`, regex + heuristic rules for stripping secrets
- `references/ai-first-principles.md`, bootcamp + prompting principles used for coaching
