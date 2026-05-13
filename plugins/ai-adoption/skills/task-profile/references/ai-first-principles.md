# AI-first principles (for coaching panel)

Used by the main agent during Phase D to populate the personal coaching panel in the explorer. Pick 3–5 principles where the user has a clear, evidenced gap. Cite specific session paths. Tone: meeting you where you are, never scolding.

## Source

Two families of principles, bundled together here so this file is self-sufficient:
- **Project-level**, how to structure a repo / workspace so an AI assistant can work it effectively.
- **Prompting-level**, habits around how the user phrases requests that correlate with lower iteration counts.

## Principles

### 1. Give enough context up-front
**Definition:** The opening turn should contain goal, constraints, paths/files in scope, and desired output shape. "Fix the scraper" beats nothing, but "fix the scraper at src/scrape.py, it fails on sites with JS rendering, want a headless-fallback, keep the public signature" is what unlocks a one-shot outcome.

**Detection signals:**
- Opening user turn < 200 chars AND ≥ 3 clarifying follow-ups in the first 5 assistant turns.
- Early assistant turn asks a question like "could you share the file" / "what's the expected format" / "which library are you using".

**Reframe template:** "Your openings tend to be ~X chars and need ~Y follow-ups. On sessions where the opener gave goal + paths + shape, you got there in one pass. Keeping a 4-line opener template would save those follow-ups."

**Before/after:**
- Before: `help me fix the api`
- After: `fix the retry loop in src/api/client.py, it retries on 4xx which is wrong. keep the function signature. add a test. output: diff only`

### 2. One atomic ask per prompt
**Definition:** Prompts asking for three different things get a muddled answer that half-addresses each.

**Detection signals:**
- Opener contains ≥ 3 coordinated asks (e.g. `build X and also add Y and then write Z`).
- Session has multiple separate acceptance phrases for different pieces, hinting the work was fragmented.

**Reframe template:** "Bundled asks run ~N iterations vs ~M for single-ask openers. Splitting into sequential single asks is usually faster end-to-end."

### 3. Point at paths, don't paste content
**Definition:** Claude Code and Cowork both read files on demand. Pasting a 500-line file into the prompt burns input tokens and drops structure; pointing at the path + using `Read` is faster and cheaper.

**Detection signals:**
- Opening user turn contains large code blocks (> 50 lines) for files that exist in the session's `cwd`.
- Token spend anomaly: `input_tokens` on the first assistant turn is ≫ median for the user.

**Reframe template:** "~X% of your openers paste code; on those you spend ~Y× more input tokens and get a similar outcome."

### 4. Use skills for repeated workflows
**Definition:** If you've written the same kind of prompt 3+ times, extract it as a skill. Skills give Claude the prescriptive recipe directly; the user stops re-explaining.

**Detection signals:**
- Multiple sessions across different cwds with near-identical opening turns.
- User frequently walks Claude through the same process by hand.

**Reframe template:** "You've issued variants of '<pattern>' in N sessions. A `<proposed-skill>` skill would compress all of them to a one-line invocation, see the skill proposals panel."

### 5. Plan, then act (for anything non-trivial)
**Definition:** For risky or multi-step work, have Claude propose a plan first and iterate on the plan, cheaper than iterating on half-done code.

**Detection signals:**
- Sessions where a large assistant implementation turn is followed by a user correction that redirects the whole approach ("actually let's do it differently").
- Repeated rewrites of the same file within one session.

**Reframe template:** "On sessions where you accepted a plan before implementation, avg iterations = X. On sessions that skipped planning, avg = Y. Plan-mode (`shift-tab` in Claude Code) for the riskier stuff saves the redo."

### 6. Terminal-first, de-UI
**Definition:** Don't ask for a web dashboard when a table in the terminal or an HTML file on disk does the same job with a tenth of the code.

**Detection signals:**
- Project-level sessions building dashboards / Streamlit / React UIs for a workflow the user runs once or twice a week.
- High friction on those sessions (styling, auth, deployment questions that aren't core to the task).

**Reframe template:** "Your UI-heavy sessions run ~X iterations vs ~Y for equivalent CLI/HTML-file outcomes. When the audience is just you, a static HTML or a `rich`-formatted CLI is usually enough."

### 7. Skills-first over embedded agents
**Definition:** When the workflow can be captured as a skill invoked from Claude Code / Cowork, don't build a deployed chatbot / embedded agent. Skills run in the user's own session with full tool access and no deployment overhead.

**Detection signals:**
- Sessions discussing deployment of a user-facing LLM app (Streamlit chat, Discord bot, web form) for internal use.
- "Claude can just do this natively with a skill" is the higher-leverage path that was skipped.

**Reframe template:** "You've scoped deployed-agent projects N times. Each one ended with a skill-shaped outcome anyway. Starting with `skill-creator` next time skips the deploy/iterate cycle."

## Coaching card shape in the explorer

```
Principle: <name>
Your pattern: <one-line summary with a number>
Good example: <session path>, <why it worked>
Where it slipped: <session path>, <what was missing> (what would've helped: <concrete advice>)
Suggested adjustment: <one practical habit change>
```

Always ≥ 1 good-example session cited (so the user sees this is achievable for them) and ≥ 1 friction-example session cited (so the advice is grounded). If a principle has no good example yet, say so honestly: `No session yet where you applied this, try it on the next one.`
