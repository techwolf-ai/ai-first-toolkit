# Triggering eval cases

Does each skill's `description` fire on the right prompt and **not** on a
neighbouring skill's? Run these through the `skill-creator` skill's eval /
benchmark mode (it reports triggering accuracy with variance across N samples).
This dimension tests descriptions only — no sandbox, no behaviour.

Focus is the collision-prone sets where the wrong skill firing is costly.

## implement-ticket vs implement-milestone vs run-epic

| Prompt | Should fire | Must NOT fire |
| ------ | ----------- | ------------- |
| "implement APP-1234" | implement-ticket | implement-milestone, run-epic |
| "build out ticket APP-9" | implement-ticket | implement-milestone, run-epic |
| "implement milestone M1" | implement-milestone | implement-ticket, run-epic |
| "do the whole M2 milestone" | implement-milestone | implement-ticket, run-epic |
| "run the whole epic APP-1000" | run-epic | implement-ticket, implement-milestone |
| "work through the epic's milestones in order" | run-epic | implement-ticket, implement-milestone |

## new-spec vs reconcile-spec

| Prompt | Should fire | Must NOT fire |
| ------ | ----------- | ------------- |
| "let's spec out the new matching feature" | new-spec | reconcile-spec |
| "start a product spec for X" | new-spec | reconcile-spec |
| "the spec is stale, update it to what shipped" | reconcile-spec | new-spec |
| "reconcile the spec with the merged code" | reconcile-spec | new-spec |

## review-mr vs review-spec

| Prompt | Should fire | Must NOT fire |
| ------ | ----------- | ------------- |
| "review this code MR against the spec" | review-mr | review-spec |
| "review my product spec" | review-spec | review-mr |
| "lint the engineering spec" | review-spec | review-mr |

## verify-milestone vs dod-check

| Prompt | Should fire | Must NOT fire |
| ------ | ----------- | ------------- |
| "verify milestone M1 is done" | verify-milestone | dod-check |
| "check DoD on this branch" | dod-check | verify-milestone |
