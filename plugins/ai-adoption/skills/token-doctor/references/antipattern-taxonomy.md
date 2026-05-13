# Token-doctor taxonomy

Seven cost-shaping patterns. Each one has a **token signature** (something we can detect from the inventory) and a **positive counterpart** (the pattern that the same person could be running instead). Diagnosis output should always cite both sides where the data supports it.

The point of this file is consistency: every subagent and every recommendation uses the same names, the same definitions, and the same neutral tone.

---

## 1. Marathon

**Signature**
- `turn_count >= 300` (p95 of the org distribution; 4.4% of sessions cross this).
- Cumulative `cache_read` per turn keeps growing because context is never reset.

**Why it's expensive**
Every turn re-pays ~10% of the entire context. At 500k context × 300 turns, that is 15B re-billed tokens. The model is doing real work on each turn but the cost grows quadratically with session length.

**Positive counterpart: Focused session**
- 20-100 turns, single task, ends cleanly with `/clear` or a session exit.
- `cache_read` per turn is bounded because the context never balloons past what the task actually needs.

**Diagnosis cue**
A marathon is bad when the turn-by-turn `cache_read` keeps climbing AND the work covers multiple unrelated topics. A 600-turn session that stays on one cohesive refactor is appropriate, not antipattern.

---

## 2. Drip-feed (late context)

**Signature**
- One or more `cache_create > 20k tokens` events at `turn_index >= 5`.
- Often paired with a sudden jump in `cache_read` from that turn forward.

**Why it's expensive**
Each late-arriving file forces the prefix cache to rebuild and every subsequent turn pays the bigger re-read bill. Late context tokens are billed at full input rate ($3/M for Sonnet), not the 10% cache-read rate.

**Positive counterpart: Front-loaded context**
- All relevant files dropped into turn 1 or 2 via `@file` references.
- After turn 5, `cache_create` events are small or zero. The cache warms once and stays warm.

**Diagnosis cue**
Count the number of `>20k cache_create at turn >= 5` events. Zero is excellent. 1-2 might be unavoidable (mid-session pivot). 3+ is a habit.

---

## 3. Zombie session

**Signature**
- `duration_min >= 240` (wall-clock 4h+) AND the session resumed multiple times AND turn count is non-trivial (>30).
- Often coupled with stale context: cache_read of last turn is comparable to earliest turns even if topic has drifted.

**Why it's expensive**
The user steps away, comes back, asks a new question, but the session is still carrying yesterday's 400k context as overhead. Every new turn pays the full context tax for context that is no longer load-bearing.

**Positive counterpart: Time-bounded session**
- Most conversations end within a single working block (<2 hours).
- New tasks the next day start with a new session.

**Diagnosis cue**
Wall-clock alone is not the signal. A 6-hour focused refactor with related turns is fine. A 6-hour session that touches three different files for three different reasons is a zombie.

---

## 4. Context bloat

**Signature**
- `peak_cache_read >= 400_000` tokens (peak single-turn context).
- Especially when this occurs in 50-200 turn sessions, well below the marathon threshold.

**Why it's expensive**
The model is operating near the 1M context ceiling, paying the cache-read tax on hundreds of thousands of tokens each turn. The session feels normal but every turn costs $0.30-0.60 just to re-read the context.

**Positive counterpart: Lean context**
- Peak context stays under 100k for typical sessions.
- The user is asking targeted questions about a small slice of code, not letting the model `Read` the whole tree.

**Diagnosis cue**
Look at the trajectory of `cache_read` over turns. Steady climb past 200k without a `/clear` is bloat. Spike followed by a reset is healthy editing pattern.

---

## 5. Repeated re-reads (cache-grind)

**Signature**
- `cache_read / cache_create` ratio >= 50x at the session level, or >= 45x averaged across the user's sessions.
- Org healthy baseline is around 10-15x. Org average is 30x.

**Why it's expensive**
A high ratio means the user is making many small turns over a large unchanging context. Each turn the model writes ~1k of output but pays for re-reading 500k of context. Tokens per useful action are skewed.

**Positive counterpart: Context churn that matches activity**
- Read 50k of new code → produce 5k of edits → ratio of around 10x.
- Or: tight back-and-forth with small context (chat-mode) → ratio of 5-15x.

**Diagnosis cue**
This pattern hides inside long sessions and looks like "thinking out loud" or "the agent keeps asking clarifying questions." Reduce by tightening the initial prompt so the model doesn't need to re-confirm.

---

## 6. Off-task drift

**Signature**
- One session spans 3+ unrelated topics in its user-prompts.
- Often shows as `cache_create > 20k` mid-session (a new file pulled in for the new topic) coupled with the same `session.id`.

**Why it's expensive**
Each topic-switch keeps the cumulative context of the prior topic alive. By topic 3, the session is paying for context from topics 1 and 2 with no benefit.

**Positive counterpart: Clean task boundaries**
- A new task = a `/clear` or a fresh session.
- Each session has a coherent, single topic in its first and last user prompt.

**Diagnosis cue**
Compare the first 3 user prompts to the last 3. If they look like different conversations, that is drift. This is a behavioural signal; subagents can flag it.

---

## 7. Heavy tool fan-out

**Signature**
- Many `tool_use` calls per turn (especially `Read`) without any `Edit` or output.
- Cache_create explodes because each `Read` pulls a new file into context.

**Why it's expensive**
The agent is reading widely without committing to a plan. Tokens go in, nothing comes out. Often the user could have pointed at the right file directly.

**Positive counterpart: Directed reads**
- The user names the relevant file or function in the first prompt.
- The agent reads 1-3 files, makes the edit, done.

**Diagnosis cue**
Ratio of `Read` calls to `Edit/Write` calls in a session. If > 10:1 with no clear research intent, it is fan-out.

---

## Pattern colour-coding for the explorer

| Pattern | Token signature in one phrase | Output colour |
|---|---|---|
| Marathon | Conversations beyond turn 300 | warm orange |
| Drip-feed | Late `cache_create > 20k` events | yellow |
| Zombie | 4h+ wall clock, multi-resume | red-pink |
| Context bloat | Peak cache_read > 400k | purple |
| Cache-grind | r/c ratio > 45x | warm |
| Off-task drift | Multi-topic single session | purple |
| Heavy fan-out | Read:edit > 10:1 | aqua-muted |
| **Focused session** | 20-100 turns, single task | aqua |
| **Front-loaded** | No late-create events | aqua |
| **Time-bounded** | < 2h wall clock | aqua |
| **Lean context** | Peak < 100k | aqua |

Aqua is reserved for positive patterns. The skill should never call out a positive pattern in a punitive colour.
