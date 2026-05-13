# Friction signals

Detector inputs used during condensate extraction (`inventory.py`) and referenced by Haiku during per-cluster analysis. These are hints; Haiku makes the final call using them plus context.

## User correction phrases (case-insensitive, word-boundary)

```
no
not quite
that's wrong
that is wrong
actually
wait
stop
don't
no I meant
let me rephrase
that's not what I
redo
try again
different approach
simpler
shorter
longer
also
and also
one more thing
you forgot
you missed
missing
you didn't
this isn't
that's not right
hold on
nevermind
scrap
```

When any of these appears as a standalone word (not embedded in a larger sentence that negates the correction meaning), increment `user_correction_count` for that session and include the containing turn in the condensate.

## Positive / acceptance phrases

```
perfect
great
thanks
thank you
ship it
looks good
exactly
nice
love it
done
good job
nailed it
✅
👍
```

Used to detect session success.

## Behavioural markers (no explicit phrase needed)

- **Tool flailing:** same tool name called ≥3× within a window of 10 consecutive assistant turns, with different args. Count as one friction event; include the last two such calls in the condensate.
- **Error paste:** a user turn containing triple-backticks AND any of `Traceback`, `Error:`, `Exception`, `stderr`, `FAIL`, `panic:` → friction event. Include the user turn in the condensate.
- **Restart burst:** user issues ≥2 restart-flavoured phrases (`let's start over`, `start from scratch`, `reset`) → friction event.
- **Long silence then pivot:** timestamp gap ≥ 30 min between consecutive turns, followed by a user turn that does not reference the previous assistant output → plausible context loss; flag.

## What NOT to count as friction

- Multi-turn exploration where the user is learning and asking clarifying questions about a topic (not corrections of output). Signals: user turns are questions, not corrections; no correction phrases present.
- Pair-programming style back-and-forth where short user turns contain requirements additions, not corrections. Signals: short turns framed as new requirements (`also add`, `now let's`, `next`) without negation.

The point is to measure when the assistant failed to match intent, not when the user evolved the intent.
