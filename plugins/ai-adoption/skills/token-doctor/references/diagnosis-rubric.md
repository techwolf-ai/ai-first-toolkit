# Diagnosis rubric

Decision rules a Haiku subagent applies to a single session payload. Read this **before** the payload.

The output JSON must follow the schema in §Output. Be concise, neutral, and tie every claim to specific turn indices in the payload.

---

## Step 1: Classify the session shape

Read the payload header. Use the numeric signals first, before the transcript.

| Signal | Threshold | Label |
|---|---|---|
| `turn_count >= 300` AND `cost >= 50` | true | **marathon-candidate** |
| `late_create_count >= 3` | true | **drip-feed-candidate** |
| `duration_min >= 240` AND `resume_count >= 2` | true | **zombie-candidate** |
| `peak_cache_read >= 400_000` | true | **bloat-candidate** |
| `rc_ratio >= 45` | true | **grind-candidate** |
| `tool_read_count / max(tool_edit_count, 1) >= 10` AND turns > 10 | true | **fanout-candidate** |
| None of the above + `turn_count <= 100` + `cost <= 5` | true | **focused-candidate** |

A session can carry multiple labels.

## Step 2: Confirm with transcript reading

For each candidate label, look at the transcript sample to confirm or downgrade:

- **marathon**: Are the user prompts about one cohesive task across the whole arc, or do they jump topics? If single task → downgrade to "long-focused-task" (positive). If multi-topic → confirm.
- **drip-feed**: Look at the turns flagged in `late_create_events`. Were they file `@`-references the user typed at turn 50, or were they `Read` calls the model made because the user asked something new mid-flight? Either way, they were avoidable.
- **zombie**: Compare first 3 user prompts to last 3. If topics differ → confirm. If same task throughout → downgrade to "extended-focus" (positive).
- **bloat**: Was the peak context warranted (large codebase the user genuinely needed) or accidental (model `Read` ten irrelevant files)? Inspect the tool_calls list at the peak turn.
- **grind**: Look at output volume across turns. Many turns producing little output = grind. Few turns producing lots of output = healthy.
- **fanout**: Are the reads concentrated in early turns (research phase) or sprinkled throughout (lost agent)?

## Step 3: Identify the trigger moment

Pick **one** specific turn where the session went wrong, if applicable. This becomes the user's "next time, don't do this" anchor.

Examples of good trigger moments:
- Turn 47: user pasted a 50k file body inline instead of using `@path/to/file`.
- Turn 95: user said "actually let's also look at X" — should have been a new session.
- Turn 12: model read 8 files via `Read` when the user had named just one.

If the session is genuinely positive (no trigger), say so.

## Step 4: Estimate savings

Conservative rule of thumb:
- If marathon + drift confirmed: 30-50% of the session cost could have been avoided.
- If drip-feed confirmed: 10-25% (the late-cache rebuild plus its tail of inflated re-reads).
- If bloat confirmed: 20-40% (reading fewer files at the start).
- If grind confirmed: 15-30% (tighter prompts mean fewer back-and-forth turns).
- If focused/positive: 0% savings, name it as a model session to repeat.

Round to nearest 5%. State your confidence.

## Step 5: Suggest one habit

One sentence, second person, action-oriented. Tie it back to the trigger moment.

Bad: "Try to use shorter sessions in the future."
Good: "When you switched topics at turn 47, that was the moment to `/clear` and start fresh."

Bad: "Drop fewer files."
Good: "The 95k file pasted at turn 23 could have been an `@` reference, which keeps the prefix cache stable."

For positive sessions, the "habit" becomes "what to keep doing":
- "This is a model of a focused session: one task, front-loaded context, ended at 67 turns."

---

## Output schema

Write strictly this JSON to `out/analyses/<sid>.json`:

```json
{
  "sid": "<session id>",
  "verdict": "antipattern | positive | mixed",
  "primary_label": "marathon | drip-feed | zombie | bloat | grind | drift | fanout | focused | front-loaded | time-bounded | lean",
  "secondary_labels": ["<additional labels, ordered by severity or strength>"],
  "what_happened": "<at most 2 short sentences, ~25 words total>",
  "trigger_moment": {
    "turn": 47,
    "what": "<one short clause describing the specific user or agent action>"
  },
  "would_have_helped": "<one short sentence concrete habit, second person>",
  "estimated_savings_pct": 30,
  "confidence": "high | medium | low",
  "is_model_session": false
}
```

**Hard length limits.** Reports get scanned, not read.

- `what_happened`: max 2 sentences. Lead with the structural fact (turn count + context size + one key signal). No restating the schema.
- `trigger_moment.what`: max 14 words.
- `would_have_helped`: max 18 words.

Good `what_happened` examples:
- "944 turns, 650k context never reset. 10 late-create events at turns 214-557 locked in a 65× re-read tax."
- "Clean 67-turn session, peak 80k context, no late context. Worth repeating."
- "Two unrelated tasks glued together starting turn 95. Topic 2 paid for topic 1's 400k context."

Bad `what_happened` examples (too long):
- "You ran a marathon session that spanned nearly 1,000 turns. During this time, the context kept growing and you didn't reset it. Each late injection at the various turns I listed forced the prefix cache to rebuild..." → over 40 words, restates obvious things.

Rules:
- `verdict = "positive"` means do NOT include `estimated_savings_pct` over 0. Use 0.
- `is_model_session = true` only if the session is a particularly strong positive example worth pointing other team members to.
- For mixed sessions, primary_label is the dominant pattern; put the others in secondary_labels.
- If `trigger_moment` does not apply (positive sessions), set it to `{"turn": null, "what": "none, this session was clean"}`.

## Tone

- Second person ("you", not "the user").
- Descriptive, not punitive. The user is looking at their own data and trying to learn.
- No "waste", "wasted", "burning", "guilty". Use "cost", "spend", "context", "rebuild".
- Cite specific turn numbers when possible.
- One sentence per field where the schema allows it; do not over-explain.
