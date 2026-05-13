# Recommendation sentence frames

Templates the main agent uses when synthesizing per-project recommendations. Keep the voice consistent across the report.

## When the report describes a pattern

| Pattern | Frame |
|---|---|
| Marathon | "Your sessions in `<cwd>` regularly cross 300 turns. Around half that time is on one task, the other half drifts into adjacent work that could have started fresh." |
| Drip-feed | "About `<N>` of your sessions in `<cwd>` had files arrive after turn 5. Each one forced the prefix cache to rebuild and made every later turn more expensive." |
| Zombie | "You kept `<N>` sessions in `<cwd>` alive across multiple days. The longest one ran `<X>` hours of wall clock across `<Y>` resume events." |
| Context bloat | "Your peak context in `<cwd>` sits near `<Xk>` tokens for routine work. That is `<X×>` higher than the same task takes in other projects." |
| Cache-grind | "In `<cwd>` you read `<X>×` more cached context than you wrote new context. That ratio means many small turns over a large frozen context." |
| Drift | "`<N>` of your `<cwd>` sessions touched three or more unrelated topics in a single conversation." |
| Fan-out | "When you open a session in `<cwd>`, the agent typically reads `<X>` files before making the first edit." |

## When the report celebrates a pattern

| Pattern | Frame |
|---|---|
| Focused | "Your `<cwd>` work runs in tight 30-80 turn sessions. Median cost per session is `<$X>`, well below your average." |
| Front-loaded | "You drop files into the first prompt in nearly all `<cwd>` sessions. Late-context events: `<N>`." |
| Time-bounded | "Your `<cwd>` sessions almost always end within a working block. No session crossed `<X>` hours in the window." |
| Lean | "Peak context in `<cwd>` stays around `<Xk>`. You point the agent at the exact file rather than letting it read the tree." |

## Habit suggestions (action lines)

Action lines should be specific to a trigger moment if there is one. Templates:

- "Next time you switch topics like at turn `<N>` of `<sid>`, run `/clear` first. New task, new conversation."
- "The `<Xk>` file you pasted at turn `<N>` could have been `@<path>`. The prefix cache would stay warm for the rest of the session."
- "When the agent starts reading files you did not name (like the `<N>` reads in `<sid>`), interrupt and point at the one file you actually need."
- "If a `<cwd>` task starts feeling like yesterday's session, open a fresh one. Resume across days is the most expensive pattern in your data."

## What to avoid

- Do not use words like "waste", "wasted", "burning tokens", "abuse", "guilty", "bad habit".
- Do not compare the user to colleagues by name unless the user is in the top-5 and the comparison helps. Even then, frame as "people in your cohort" rather than calling out individuals.
- Do not estimate dollar savings to more than two significant figures. `~$120` is fine; `$117.45` reads as fake precision.
- Do not recommend a habit the user already practices well in another project. Cite the good example and say "you already do this in `<good cwd>`, the same approach works here".
