# AI Adoption

Three skills for working with your Claude history:

- **`token-doctor`**, diagnose where your Claude Code + Cowork spend goes. Writes a doctor-style terminal report (length distribution, marathon share, cache rebuilds, per-project health) and offers an opt-in deep dive that fans out parallel Haiku subagents over your top sessions for habit-level recommendations.
- **`task-profile`**, mine your Claude Code + Cowork session history into a role-level map of what you actually do with AI, ranked by frequency and friction, with the tokens beside every row.
- **`session-search`**, find a specific past session by title, working directory, time range, or free-text content across every transcript on disk.

## Why

Most teams roll out Claude without ever measuring how people actually use it. Token bills land monthly with no signal on what's healthy, what's wasteful, and which habits compound. This plugin turns your local transcript history into three concrete artifacts: a personal cost diagnosis, a role-level task profile, and a transcript search index. Everything runs on disk; no API calls, no auth.

## Skills

| Skill | What it does |
|-------|-------------|
| `/token-doctor` | Diagnose where Claude spend goes. Two-stage: fast terminal report + opt-in deep dive over hotspot sessions |
| `/task-profile` | Mine sessions into a task profile with friction signals, tokens per task, AI-first coaching cards, and skill proposals |
| `/session-search` | Find a past session by title, working directory, time range, or full-text content |

## Getting Started

1. Install the plugin via Claude Code marketplace or `./install.sh ai-adoption`.
2. Run `/token-doctor` to get an instant terminal report on where your tokens go.
3. Run `/task-profile` for a 5-10 minute deep analysis that produces an interactive HTML explorer.
4. Use `/session-search` any time to dig up a specific past session.

All output lands under `./out/` in your current working directory. Nothing leaves your machine.

## `token-doctor`

Two-stage diagnostic. Stage 1 is fast (≤10 seconds) and prints a formatted doctor's report straight to the terminal so the user always walks away with their numbers. Stage 2 is opt-in, runs parallel subagents over hotspot sessions, and writes a tight Markdown report.

| File | What it is |
|---|---|
| `out/sessions.jsonl` | Per-session inventory with token usage, late-context events, peak context, duration |
| `out/user-stats.json` | Aggregated stats (length buckets, marathon share, cache rebuilds, per-cwd health) |
| `out/hotspots.json` | The ~14 sessions selected for deep analysis (top cost + drip-feed + marathon + grind + 3 positive examples) |
| `out/payloads/<sid>.json` | Per-hotspot payloads dispatched to Haiku subagents (token shape only, no prompt text) |
| `out/analyses/<sid>.json` | One per hotspot, strict-schema verdicts and habit recommendations |
| `out/recommendations.md` | Tight final report: signature, what-to-keep, what-to-change, per-session table |

Sample phrasings:

- `diagnose my Claude habits`
- `why is my Claude spend so high`
- `where are my tokens going`
- `audit my Claude usage`
- `/token-doctor`

The skill always produces the Stage 1 report inline; the deep dive only runs if the user opts in. **Both antipatterns and positive habits get airtime**: the rubric forces the report to highlight what's working, not only what's broken.

## `task-profile`

Run the skill from any working directory; outputs land under `./out/` in that directory.

| File | Audience | What it is |
|---|---|---|
| `out/profile.csv` | Shareable | One row per canonical task with frequency, success distribution, avg iterations, top friction, token totals |
| `out/explorer.html` | Personal | Single-file UI with progressive disclosure: token chart by category, category accordion, task accordion, friction + model breakdown + sessions |
| `out/skill-proposals.json` + `.md` | Personal | Up to five task-centric skills that would compound across multiple top tasks |
| `out/coaching-panel.json` | Personal | Four AI-first habit cards with a session where the habit held and one where it slipped |
| `out/inventory.json` | Internal | Full per-session inventory with token usage and structured condensates (feeds the analysis) |

Sample phrasings:

- `analyse my Claude use over the last 6 months`
- `build a task profile`
- `what tasks do I do with Claude`
- `where am I spending tokens`
- `what skills would help me`

The skill's `SKILL.md` is the entry point; it drives the multi-phase workflow: inventory, cluster, parallel Haiku analysis, aggregation, HTML build, skill proposals.

## `session-search`

Two small scripts that read transcripts directly from disk, no API calls, no auth. Activates on phrasings like `where did I work on X`, `find that session where I...`, `when did I last do Y`, `pull up the conversation about Z`.

| Script | Purpose |
|---|---|
| `scripts/find_sessions.py` | Discover + filter sessions by `--kind`, `--since`, `--until`, `--title`, `--cwd`, `--grep` (full-text regex), with a tabular or `--json` output |
| `scripts/show_session.py` | Print a single session's conversation in readable markdown; supports `--grep` and `--tail` for focused slices |

Code sessions live at `~/.claude/projects/*/*.jsonl`; Cowork sessions at `~/Library/Application Support/Claude/local-agent-mode-sessions/*/*/local_*/audit.jsonl`. Both paths are resolved from `$HOME`, so it works for any user.

## How `task-profile` works

Six phases, mostly LLM-driven with small deterministic scripts around the edges:

1. **Inventory**, `scripts/inventory.py` walks `~/.claude/projects/**/*.jsonl` and the Cowork session directory, extracts per-session token usage from `message.usage`, flags automations (scheduled tasks, paperclip runs, sdk-cli sub-agents), strips `<task-notification>` noise, and builds a structured "condensate" of each session (first three user turns, corrections, tool-flail episodes, outcome).
2. **Cluster**, main agent reads the inventory and groups sessions by judgment (same cwd, similar Cowork title, shared topic). ~40–80 clusters.
3. **Analyse**, one parallel Haiku subagent per cluster. Each returns strict JSON with role-level task sentences, success level (`delivered_clean` / `with_friction` / `partial` / `abandoned`), iteration count, friction points with "what would prevent" guidance, and frequency.
4. **Aggregate**, main agent writes `out/canonical-merges.json` (cross-cluster dedup decisions). `write_profile.py` applies the merges, sums tokens per task and per model, redacts again as a belt-and-braces pass, writes `profile.csv` and `profile.json`.
5. **Coach + propose**, main agent writes `coaching-panel.json` (AI-first habit cards with evidence) and `skill-proposals.json` (up to five task-centric skills, each impacting ≥ 2 top tasks).
6. **Build**, `scripts/build_explorer.py` renders the single-file HTML with TechWolf palette, Work Sans + Geist + JetBrains Mono typography, and progressive-disclosure accordions.

## How `token-doctor` works

Seven phases. Stage 1 is always shown; Stage 2 is opt-in.

**Stage 1 (fast, inline)**

1. **Inventory**, `scripts/inventory.py` walks Claude Code + Cowork transcripts, computes per-session token totals, late-context events (`cache_create > 20k` at turn ≥ 5), peak `cache_read`, duration, computed cost from list rates, and a per-model breakdown.
2. **Aggregate**, `scripts/personal_stats.py` rolls up to length buckets (1-5, 6-20, …, 1,000+ turns), marathon share (≥300 turns, the p95 of the org distribution), zombie share (≥4h wall clock), cache rebuild $, re-read ratio, and per-cwd health classification (✅ clean · 🏃 marathon · 🔄 rebuilds · 🧟 zombie · ⚠️ multiple).
3. **Report**, the main agent reads `user-stats.json` and writes a formatted doctor's report directly to the terminal with traffic-light dots, an ASCII bar chart, a diagnosis paragraph, project chart, and a treatment plan that includes both "keep doing" and "change first" sections.

**Stage 2 (opt-in, deep dive)**

4. **Pick hotspots**, `scripts/pick_hotspots.py` selects ~14 sessions: top cost, top drip-feed, top marathon length, top cache-grind, plus three positive examples (most efficient short-to-mid sessions). The positive picks matter: the user needs to see what good looks like in their own data.
5. **Build payloads**, `scripts/build_payloads.py` writes one redacted payload per hotspot with token timeline, tool counts, late-event list, and a 120-char title. No user prompt text or model output text is included.
6. **Fan out**, the main agent dispatches one Haiku subagent per payload **in parallel**. Each reads `references/antipattern-taxonomy.md` and `references/diagnosis-rubric.md`, applies a five-step classification, and emits strict JSON with a 1-2 sentence diagnosis, trigger moment, habit suggestion, and verdict (`antipattern` / `mixed` / `positive`).
7. **Synthesize**, the main agent groups analyses by cwd, identifies the user's signature pattern (and signature strength), and writes `out/recommendations.md` with mandatory "what you're doing well" and "what's driving your bill" sections plus a per-session table.

## Privacy

- **Local only**: every transcript stays on disk. Subagents in `token-doctor` receive token counts, tool-call names, turn indices, and a 120-char title — never user prompts or model output.
- **Redaction before dispatch and output**: API keys, tokens, JWTs, private key blocks, emails (local-part), phone/card/IBAN patterns are regex-stripped before any text is dispatched to a subagent or written to the CSV/HTML/Markdown.
- **Automation exclusion**: scheduled-task, paperclip, ditto-routine, and sdk-cli sub-agent sessions are filtered from the analysis (counts kept in the footer for transparency).
- **Final manual review**: after generation, spot-check outputs for any high-entropy tokens the regex might have missed.

## Requirements

- Python ≥ 3.10 (stdlib only; no pip install needed)
- Claude Code ≥ 2.x with access to the `general-purpose` Agent subagent and Haiku
- Cowork desktop for the Cowork side; Cowork-side analysis is optional (Code CLI sessions work stand-alone)
- macOS primary; Windows supported for Cowork path resolution; Linux falls back to Code-only

## Attribution

Skill sources: `skills/token-doctor/`, `skills/task-profile/`, `skills/session-search/`. Branded with the TechWolf aquamarine + dark palette and the TechWolf logo (via `assets/logo.svg`). Swap the logo if repurposing externally, the generator falls back to a neutral glyph if the asset is missing.
