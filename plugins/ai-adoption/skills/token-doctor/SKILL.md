---
name: token-doctor
description: Personal diagnosis of where your Claude Code + Cowork spend goes. Reads local transcripts, prints your conversation length distribution, marathon share, cache rebuild costs, and per-project diagnosis (good projects and problem projects) right in the terminal. Then offers a deeper dive that fans out parallel Haiku subagents over your most expensive (and most efficient) sessions and writes a tight Markdown report. Use when the user asks "why is my Claude spend so high", "where am I burning tokens", "diagnose my Claude habits", "audit my Claude usage", or asks for a personal token-cost diagnosis.
---

# Token Doctor

Two-stage diagnostic. Stage 1 is fast and lands directly in the terminal so the user always walks away with their numbers. Stage 2 is opt-in, fans out subagents over hotspots, and writes a tight Markdown report.

**Read this whole file before running.**

## When to run

Trigger phrases: "diagnose my Claude habits", "why am I spending so much", "where are my tokens going", "audit my spend", "token doctor", "what's driving my Claude bill".

Do NOT trigger for:
- "what tasks do I do with Claude" → that's `task-profile`.
- "where did I work on X" → that's `session-search`.

The line is: token-doctor is about cost **shape**, not task inventory or recall.

## Prerequisites

- Claude Code CLI transcripts: `~/.claude/projects/*/*.jsonl`
- Claude Cowork transcripts (optional): `~/Library/Application Support/Claude/local-agent-mode-sessions/*/*/local_*/audit.jsonl`
- Python 3, stdlib only. No external services.

If neither path exists, stop and say so.

---

## STAGE 1 — Fast diagnosis (always runs, you write the report)

The goal is: the user invokes the skill, sees a clean doctor's report within 10 seconds, knows which projects are healthy and which are bleeding, and can decide whether to go deeper. **You write the report directly in your message** based on the JSON the scripts produce. The scripts compute, you communicate.

### Step 1.1 — Inventory (deterministic)

```bash
~/.claude/skills/token-doctor/scripts/inventory.py --since YYYY-MM-DD --out out/sessions.jsonl
```

Default window: last 90 days. Flags: `--since`, `--until`, `--all`, `--include-automation`, `--no-cowork`. Automation runs (paperclip, `/loop`, `/schedule`, ditto-routines, scheduled-tasks) excluded by default.

### Step 1.2 — Aggregate (deterministic)

```bash
~/.claude/skills/token-doctor/scripts/personal_stats.py --in out/sessions.jsonl --out out/user-stats.json
```

Prints a single confirmation line. The full data is in `out/user-stats.json`.

### Step 1.3 — Read the JSON and write the doctor's report

Read `out/user-stats.json`. Then **write the report directly in your message** as terminal-style ASCII with emojis. The user reads your message; no intermediate file.

#### Report structure (mandatory sections, in order)

```
🩺 ┌────────────────────────────────────────────────────────────────────┐
   │            TOKEN DOCTOR · personal diagnosis                       │
   └────────────────────────────────────────────────────────────────────┘

  Patient: <user's first name or "you">
  Window:  <window dates from inventory>
  Spend:   $<total> list-price equivalent · <conv count> conversations

  ── Vital signs ─────────────────────────────────────────────────────────

  🔴/🟡/🟢 Marathon (≥300 turns)    <N> conv  ·  $<X>  ·  <Y>% of spend
  🔴/🟡/🟢 Zombie (≥4h wall clock)  <N> conv  ·  $<X>  ·  <Y>% of spend
  🔴/🟡/🟢 Cache rebuilds            <N> events · <Z>M tokens · ~$<X>
  🔴/🟡/🟢 Re-read ratio             <X>×   (healthy ≤15×, org avg 30×)
  📈 Peak context observed       <X>k tokens

  ── Spend by conversation length ────────────────────────────────────────

       1 to 5        <bar>   <%>   (<N> conv)
       6 to 20       <bar>   <%>   (<N> conv)
       …
       1,000+        <bar>   <%>   (<N> conv)

  ── Diagnosis ───────────────────────────────────────────────────────────

  <2-4 sentences synthesizing the vitals into one clear picture. Lead with
  the dominant antipattern in this user's data, then the corollary cost. End
  with one line about the strongest positive signal you see.>

  ── Project chart ───────────────────────────────────────────────────────

  ✅ clean · 🏃 marathon · 🔄 rebuilds · 🧟 zombie · ⚠️ multiple

  <emoji>  $<X>  <truncated cwd>                              <meta line>
  <emoji>  $<X>  <truncated cwd>                              <meta line>
  … up to 10-12 rows from by_cwd_top

  ── Treatment plan ──────────────────────────────────────────────────────

  💚 Keep doing:
     <bullet referencing a clean project from by_cwd_top or by_cwd_clean_deeper,
      OR a positive structural signal like a high short_share if no clean cwd is in top 12>
     <2-3 bullets total>

  🎯 Change first:
     <one concrete action tied to the biggest lever, with cited project>
     <2-3 bullets total, ordered by expected impact>

  ── Want a deeper look? ─────────────────────────────────────────────────

  <one-line question asking if they want the deep dive>
```

#### Rules when writing the report

- **Use the emojis above consistently.** Box-drawing characters (─ ┌ └ │) are fine and make the report look like a medical printout.
- **Traffic-light dots**: 🔴 = bad, 🟡 = watch, 🟢 = healthy. Apply the bands in the rubric below.
- **Per-project emoji** must come from `by_cwd_top[i].emoji` in the JSON. Do not re-classify.
- **Bars** for the length distribution: build them with `█` characters proportional to the share. Use a fixed width like 36 chars.
- **The diagnosis paragraph is yours to write** — it is the doctor's read on the data. Be specific. Don't restate the numbers; conclude from them. Aim for 3-5 sentences max. Examples of good diagnostic sentences:
  - "Your spend is concentrated in a small number of very long sessions: 22 conversations carry 70% of your bill."
  - "Cache rebuilds are minor at $388, but the re-read ratio of 23× tells me your context grows fast inside those long sessions."
  - "Three of your top five projects are evaluation runs from last month. Each is one long session; splitting them would compound."
- **Treatment plan must include both "keep doing" AND "change first" sections.** Skipping the positive section is forbidden. Pick from:
  - `by_cwd_top` entries with `emoji == "✅"` for clean
  - `by_cwd_clean_deeper` for clean projects below the top 12
  - `short_share` if neither is available — frame as "X% of your spend is in short focused sessions, so the habit is there, you just don't use it everywhere"
- **Cite specific projects.** Truncate cwds to the last 36-44 chars with a leading `…` if they're long. Drop the `/Users/<name>/` prefix when it makes the line cleaner.
- **No em-dashes.** Use commas, semicolons, or periods.
- **No "waste", "burning", "bad habit".** Use "cost", "spend", "context", "rebuild".

#### Traffic-light thresholds

| Metric | 🟢 | 🟡 | 🔴 |
|---|---|---|---|
| Marathon share | < 20% | 20-50% | ≥ 50% |
| Zombie share | < 20% | 20-50% | ≥ 50% |
| Cache rebuild $ | < $50 | $50-$200 | ≥ $200 |
| Re-read ratio | ≤ 15× | 15-35× | ≥ 35× |

#### Asking about the deep dive

End with one short line, not a paragraph. Example:

> Want me to pull apart your top sessions one by one — what specifically drove each marathon, plus a couple of your most efficient runs to learn from? Takes about a minute, runs ~15 Haiku subagents in parallel.

If they say no, stop. The report is the deliverable.

---

## STAGE 2 — Deep dive (opt-in)

### Step 2.1 — Pick hotspots

```bash
~/.claude/skills/token-doctor/scripts/pick_hotspots.py --in out/sessions.jsonl --out out/hotspots.json
```

Selects ~14 sessions:
- 8 by absolute cost
- 3 by cache rebuild tokens
- 3 by raw turn count
- 3 by read:create ratio at ≥$5 cost
- **3 positive examples** (lowest cost-per-turn at 20-100 turns)

Briefly tell the user the list before fan-out so they can drop sensitive sids. Keep it to one line per session: `$X · N turns · short title`.

### Step 2.2 — Build payloads

```bash
~/.claude/skills/token-doctor/scripts/build_payloads.py --sessions out/sessions.jsonl --hotspots out/hotspots.json --outdir out/payloads
```

Writes one redacted payload per hotspot. Payloads include token shape, tool-call counts, timeline samples, and a 120-char title. They do NOT include user prompt bodies or model output text.

### Step 2.3 — Parallel subagent fan-out

For each payload in `out/payloads/`, dispatch one subagent. **Send all calls in one message with multiple tool blocks so they run in parallel.**

```
Agent(
  description="Diagnose one session",
  subagent_type="general-purpose",
  model="haiku",
  run_in_background=true,
  prompt="""
Diagnose the session at out/payloads/<sid>.json.

Read first, in order:
  1. ~/.claude/skills/token-doctor/references/antipattern-taxonomy.md
  2. ~/.claude/skills/token-doctor/references/diagnosis-rubric.md
  3. out/payloads/<sid>.json

Apply the rubric. Emit strictly the JSON schema (see rubric §Output) to out/analyses/<sid>.json. Hard length limits: what_happened max 2 sentences (~25 words), trigger_moment.what max 14 words, would_have_helped max 18 words. Lead with structural facts (turn count, context size, key signal). No restating the schema.

Tone: second-person, neutral, no "waste" / "burning".
"""
)
```

Wait for all to complete.

### Step 2.4 — Synthesize the report (main agent)

Read every `out/analyses/*.json`. Then:

1. **Group by cwd**. For each cwd that has ≥2 analyzed sessions, decide if it shows a dominant pattern.
2. **Find the signature**: the one antipattern that recurs most across the user's data, and the one positive habit they have consistently.
3. **Write `out/recommendations.md`** — tight, scannable, no padding. Structure:

```markdown
# Token Doctor — your diagnosis

**Signature.** <one sentence: dominant antipattern + dominant strength>

**Bottom-line lever.** <one sentence: the single habit change with the biggest expected impact>

## What you're doing well

- **<positive pattern>** in `<cwd>`. <one sentence with one cited sid>
- **<positive pattern>** in `<cwd>`. <one sentence with one cited sid>

(2-3 bullets. At least one is mandatory; do not skip this section.)

## What's driving your bill

- **<antipattern>** in `<cwd>`. <one sentence. Cite the worst sid and one specific turn or signal>
- ...

(3-5 bullets ordered by estimated savings)

## Per-session diagnoses

| Cost | Turns | Verdict | What happened |
|---:|---:|---|---|
| $XXX | NNN | <label> | <1-2 line what_happened from the analysis> |
| ...

(Only the analyzed sessions. Use the `what_happened` field verbatim from each analysis JSON.)
```

Also write `out/recommendations.json` with structured form for re-use:

```json
{
  "signature": {
    "primary_antipattern": "marathon | drip-feed | zombie | bloat | grind | drift | fanout | none",
    "primary_strength": "focused | front-loaded | time-bounded | lean | directed | none",
    "one_line": "<one sentence about how this user's spend is shaped>"
  },
  "bottom_line_lever": "<one sentence>",
  "positives": [{"pattern": "...", "cwd": "...", "evidence_sid": "...", "note": "..."}],
  "antipatterns": [{"pattern": "...", "cwd": "...", "evidence_sids": ["..."], "note": "...", "expected_impact": "small|medium|large"}],
  "session_table": [{"sid": "...", "cost": 0, "turns": 0, "verdict": "...", "what_happened": "..."}]
}
```

Keep the prose terse. The user already has the terminal numbers; the report's job is to point at specific projects and habits, not to recite stats.

---

## Privacy contract

- Everything runs locally. No transcript text leaves the machine.
- Subagents receive token counts, tool-call names, turn indices, and a 120-char title. They do not receive user prompt text or model output text.
- Output files in `out/` contain session ids and short titles. They do not contain conversation content.
- The user can `rm -rf out/` to wipe everything.

## Tone

- Descriptive, not punitive. The user is reading their own data.
- Both antipatterns and positive habits get airtime. Skipping the "what you're doing well" section is forbidden.
- Specific numbers, specific turn indices, specific sids. Avoid hedging.
- No em-dashes. No "waste", "burning", "bad habit".
- Emojis are allowed in the terminal output (the `personal_stats.py` script uses them). Keep them out of the Markdown report — there it should look like an engineering doc.

## Failure modes

- **No transcripts found.** Stop with a clear message.
- **Subagent emitted invalid JSON.** Skip that sid, log a warning once, continue.
- **All sessions are automation.** Tell the user to re-run with `--include-automation` if they want those analyzed; otherwise note the interactive count.
- **Single-cwd user.** Skip the per-cwd grouping in the report; recommendations still work as a flat list.
