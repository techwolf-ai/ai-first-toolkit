# Success rubric

Four levels. Haiku assigns one per task based on the condensate, using these definitions and signals. The signals are hints, not hard rules, if context clearly contradicts a signal, override it.

## Levels

### delivered_clean
User accepted output on first or near-first pass.

Signals:
- Final user turn is an acceptance phrase (`perfect`, `great`, `ship it`, `looks good`, `exactly`, `nice`, `love it`, `thanks`, `done`).
- ≤ 1 correction anywhere in the transcript.
- Assistant delivers; user moves on without revision demands.

### delivered_with_friction
Completed, but only after 2+ user corrections.

Signals:
- 2–5 correction phrases (`no`, `actually`, `not quite`, `wait`, `redo`, `try again`, `you forgot`, `you missed`, `simpler`, `different approach`).
- Tool-flail pattern: same tool called ≥3× with varying args.
- User pastes an error and asks for a fix.
- Session ends in acceptance despite the friction.

### partial
Usable fragment, but user stopped before full completion.

Signals:
- Final assistant turn is a plan/outline/half-answer, not a delivered artifact.
- User's last turn is a continuation question with no acknowledgement, then the session trails off.
- No explicit acceptance and no clear abandonment.

### abandoned
User changed direction, gave up, or silently dropped the thread.

Signals:
- Explicit: `nevermind`, `let's drop this`, `actually let's not`, `scrap this`, `move on`.
- Silent drop: no acceptance, short duration, and (if cross-session evidence is available) a later same-cwd session restarts the same request. Treat cross-session re-opens as `delivered_with_friction` rather than `abandoned` when the second session succeeds, friction surfaced between sessions is still friction.

## Tie-breaking

When torn between two levels, prefer the lower-success level. A conservative call is more useful for the coaching pass than an inflated one.

## Evidence field

Always quote or paraphrase the single strongest signal into `success_evidence`. ≤ 120 chars. This is what the user sees in the drill-down, make it concrete.
