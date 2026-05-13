# AI Adoption Personas

Twenty archetypes the main agent picks from when populating the persona card. Pick **one primary** and optionally **one secondary modifier**. Rewrite the baseline into a tailored blurb per the rules in `SKILL.md` Phase G.

Rules:

- Prefer the persona whose trigger signals fire most clearly in `out/persona-features.json`.
- Break ties by coherence with the coaching cards already written, the persona should complement the coaching, not contradict it.
- Do not force a modifier. Leave `modifier: null` when none fits cleanly. A clean single persona reads stronger than a bolted-on tag.
- Minimum sample size: below 10 sessions, fall back to **The Explorer** regardless of signals.

---

## Speed & style

### one-shot-wonder, **The One-Shot Wonder**
- Tagline: *You get it right the first time, most times.*
- Triggers: `avg_clean_pct_top10 ≥ 55`, `avg_iter_top10 ≤ 1.5`, total sessions ≥ 30.
- Modifier compat: `code-native`, `cowork-native`, `focused-craftsman-lite`.
- Baseline: *Opens with goal, constraints, paths, desired shape. Rarely goes back for a second pass when that happens, it's the prompt that changed, not the output.*
- Emblem: single arrow striking the bull's-eye of three concentric rings.

### iterator, **The Iterator**
- Tagline: *Conversations as craft, each turn sharpens the last.*
- Triggers: `avg_iter_top10 ≥ 4`, success still reached (`avg_clean_pct_top10 + avg_friction_pct ≥ 80`), high per-task session count.
- Modifier compat: `wordsmith-lean`, `opus-loyalist`.
- Baseline: *Doesn't ask for the final draft, works toward it. Accepts a few detours in exchange for a noticeably better last turn.*
- Emblem: tightening spiral, three loops.

### architect, **The Architect**
- Tagline: *The prompt is the design, the rest is just rendering.*
- Triggers: long first-user-msg median (≥ 400 chars), few corrections, plan-mode markers, many file paths in opener.
- Modifier compat: `code-native`, `opus-loyalist`, `polymath`.
- Baseline: *Sketches the whole building before the first brick. Openers read like a small spec, goal, constraints, shape of the output, acceptance criteria.*
- Emblem: nested arches in a blueprint rectangle.

### sprinter, **The Sprinter**
- Tagline: *Short prompts, quick wins, many of them.*
- Triggers: median turns ≤ 6, ≥ 80 sessions, `avg_iter_top10 ≤ 2`.
- Modifier compat: `cowork-native`, `morning-routine`.
- Baseline: *Doesn't linger, in, done, next. Prefers small tasks that fit into a coffee break.*
- Emblem: three parallel diagonal motion marks.

### marathoner, **The Marathoner**
- Tagline: *You and one session, all the way to the finish.*
- Triggers: ≥ 3 sessions over 100 turns, very high cache_read per session, high max_turns.
- Modifier compat: `code-native`, `opus-loyalist`.
- Baseline: *Goes long. Picks a hard problem, settles in, and doesn't resurface until it's done.*
- Emblem: single rising peak line, summit marker on top.

---

## Work-type

### wordsmith, **The Wordsmith**
- Tagline: *Writing is a two-player game, and you know your partner.*
- Triggers: writing share of tokens ≥ 25%, ≥ 2 writing-category tasks in top-10.
- Modifier compat: `iterator-lean`, `polymath`.
- Baseline: *Writes with a voice, drafts, nudges, edits against a real standard. Catches AI tics before they ship.*
- Emblem: flowing ligature stroke tapering into a single dot.

### engineer, **The Engineer**
- Tagline: *You build, and the AI picks up the sander.*
- Triggers: engineering share ≥ 30%, distinct_cwds ≥ 5 in engineering, code_token_share ≥ 0.6.
- Modifier compat: `code-native`, `focused-craftsman-lite`, `opus-loyalist`.
- Baseline: *Writes real code, ships real things. Uses AI where compilation would be faster with a second pair of eyes.*
- Emblem: isometric cube with one face detached (exploded module).

### researcher, **The Researcher**
- Tagline: *Every question opens three others, and you chase them all.*
- Triggers: research + analysis ≥ 35% combined, multi-source fetch patterns in friction_points.
- Modifier compat: `cowork-native`, `polymath`, `connector-lean`.
- Baseline: *Pulls threads. One question becomes four sub-queries before you're done, each answered with receipts.*
- Emblem: compass rose, four cardinal arms, aquamarine centre.

### diplomat, **The Diplomat**
- Tagline: *You show up prepared, AI handles the pre-reading.*
- Triggers: planning + communication ≥ 30%, meeting-prep tasks in top-5, heavy calendar/mail/chat signals.
- Modifier compat: `cowork-native`, `morning-routine`.
- Baseline: *Walks in having read everything, calendar, inbox, last exchange, open threads. The meeting is the easy part.*
- Emblem: two arcs intersecting at a single aquamarine node.

### data-whisperer, **The Data Whisperer**
- Tagline: *Rows in, decks out. Repeat.*
- Triggers: ops + analysis ≥ 30%, excel/pptx-conversion or data-to-deck patterns in top-10.
- Modifier compat: `code-native`, `focused-craftsman-lite`.
- Baseline: *Takes a spreadsheet and gets back a deck. The plumbing between raw data and a shareable artifact is muscle memory.*
- Emblem: three ascending bars rising out of a baseline, aquamarine dot atop the tallest.

### strategist, **The Strategist**
- Tagline: *You think in memos, not messages.*
- Triggers: planning ≥ 20% AND research ≥ 15%, ≥ 3 long-form memo-shape tasks.
- Modifier compat: `polymath`, `opus-loyalist`.
- Baseline: *Frames the problem before reaching for a tool. The AI work is mostly pressure-testing a position you already have.*
- Emblem: concentric circles with a single outbound vector.

---

## Tooling & behaviour

### connector, **The Connector**
- Tagline: *Your AI has read your whole stack, you wired it that way.*
- Triggers: `distinct_mcps ≥ 6`, cross-source research patterns, ≥ 4 distinct tool families.
- Modifier compat: `cowork-native`, `polymath`, `opus-loyalist`.
- Baseline: *Connected the AI to the rest of your life, calendar, mail, chat, docs, data, and it earns its keep by spanning them.*
- Emblem: central hub with six edges to satellite nodes; hub is the aquamarine dot.

### automator, **The Automator**
- Tagline: *Most of your AI hours run while you sleep.*
- Triggers: scheduled_run_count ≥ 20, recurring-title ratio high, morning-consistent timestamps.
- Modifier compat: `cowork-native`, `morning-routine`.
- Baseline: *Scheduled the repeating work away. Daily triage, weekly prep, periodic digests, all running while your kettle boils.*
- Emblem: infinity loop, single aquamarine dot at the crossing point.

### skill-crafter, **The Skill Crafter**
- Tagline: *Build once, invoke forever.*
- Triggers: ≥ 3 skill-plugin-development sessions, recurring invocations of those skills later.
- Modifier compat: `code-native`, `engineer-lean`.
- Baseline: *Notices the third time you explain the same thing to the AI and turns it into a skill. Your scaffolding compounds.*
- Emblem: cut-gem with four facets, aquamarine glint on one.

### conductor, **The Conductor**
- Tagline: *You don't just use AI, you orchestrate it.*
- Triggers: sub-agent dispatches ≥ 100, ≥ 4 active MCPs, ≥ 2 distinct scheduled routines, cross-category spread.
- Modifier compat: `cowork-native`, `polymath`, `opus-loyalist`.
- Baseline: *Runs AI like a full ensemble, scheduled routines handling triage, sub-agents working in parallel, a sure feel for which instrument belongs in which player's hands.*
- Emblem: four arrows merging into a single aquamarine dot.

### bench-builder, **The Bench-Builder**
- Tagline: *You don't polish the output, you polish the workshop.*
- Triggers: heavy skill development + long-lived reuse, ratio of meta-work to output-work is unusually high.
- Modifier compat: `code-native`, `focused-craftsman-lite`.
- Baseline: *Spends disproportionate time on the tools themselves. The payoff lands weeks later when everyone else on the team suddenly ships faster.*
- Emblem: four stacked bricks on a single baseline.

---

## Volume & efficiency

### token-titan, **The Token Titan**
- Tagline: *Your monthly AI spend has its own line item.*
- Triggers: total tokens in top decile (baseline or ≥ 500M), large Opus share, heavy cache usage.
- Modifier compat: `opus-loyalist`, `polymath`.
- Baseline: *Volume is the strategy. Where others pick carefully, you batch the thing and sort afterwards.*
- Emblem: three stacked chips with a single aquamarine one on top.

### cache-whisperer, **The Cache Whisperer**
- Tagline: *Same context, tenth the cost. You've seen this before.*
- Triggers: `cache_ratio ≥ 0.80`, long session chains reusing scope.
- Modifier compat: `code-native`, `focused-craftsman-lite`, `architect-lean`.
- Baseline: *Reuses context instead of rebuilding it. Most of your token bill is cached reads which means most of your time isn't spent re-briefing the AI.*
- Emblem: three concentric shells, thickest at the outside, aquamarine core.

### model-polyglot, **The Model Polyglot**
- Tagline: *Right tool, right turn, right size.*
- Triggers: ≥ 4 distinct models with ≥ 5% token share each.
- Modifier compat: `polymath`, `connector-lean`.
- Baseline: *Picks the model like picking the knife, Haiku for the chop, Opus for the reduce, Sonnet for the rest. Rarely wastes a big model on a small job.*
- Emblem: four dots in a quadrant, each a different aquamarine tint.

### focused-craftsman, **The Focused Craftsman**
- Tagline: *Few projects, deep water.*
- Triggers: distinct_cwds ≤ 5, high session count per cwd, low topic spread.
- Modifier compat: `code-native`, `cache-whisperer-lean`.
- Baseline: *Doesn't spread thin. Two or three things at a time, and each of them gets the full treatment.*
- Emblem: single deep engraved vertical mark, aquamarine base.

---

## Fallback

### explorer, **The Explorer**
- Tagline: *Still finding the shape of it, and that's where the good patterns start.*
- Triggers: ≤ 10 interactive sessions, or no persona scores convincingly.
- Modifier compat: any, but usually left null.
- Baseline: *Early days. The patterns aren't settled yet, and that's a feature, you're still trying things. Come back after another month of use and a persona will have formed around your fingerprints.*
- Emblem: a compass with a single dashed path unspooling from it.

---

## Secondary modifiers

Optional single-token tag that layers onto the primary persona. Pick one if it clearly fits, otherwise leave null.

| Modifier | Fires when | Reads as |
|---|---|---|
| `code-native` | code_token_share ≥ 0.70 | "lives in the CLI" |
| `cowork-native` | cowork_token_share ≥ 0.70 | "runs it from Cowork" |
| `morning-routine` | ≥ 15 recurring scheduled runs with consistent hour-of-day | "greets the day with a cron" |
| `opus-loyalist` | ≥ 70% tokens on Opus-class models | "always reaches for the big one" |
| `polymath` | active in ≥ 5 categories each above 8% token share | "jumps domains fluently" |
| `fresh-off-the-boat` | `last_session_date - first_session_date ≤ 30 days` | "just arrived, watch this space" |

---

## Blurb rules (short version; full rules in SKILL.md Phase G)

- Second person, 40–60 words, 2–3 sentences.
- Open with a concrete user behaviour, not the persona name.
- Include one surprising number lifted from `persona-features.json`.
- Land on a crisp style observation.
- No em-dashes. No hype words. No brand names. No "leverage", "game-changer", "next-level".
- Voice: observant friend, writing an affectionate roast.
