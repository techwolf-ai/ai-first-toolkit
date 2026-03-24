# People Manager Plugin

AI-augmented management tooling. See `README.md` for philosophy and details.

## Skills

| Command | What it does |
|---------|--------------|
| `/setup` | Interactive onboarding -- run this first |
| `/meeting-prep` | Pre-meeting briefing from all sources |
| `/one-on-one-prep` | Deep 1:1 preparation (org's performance framework) |
| `/triage-messages` | Batch message triage by urgency |
| `/customer-status` | Account health overview |
| `/priority-planner` | Highest-leverage actions for the day/week |
| `/team-health` | Periodic team dynamics check |
| `/performance-cycle` | Evidence gathering for review cycles |

## Key References

- `references/operating-principles.md` -- shared principles all skills follow
- `references/performance-framework.md` -- default performance dimensions (customised during setup)
- `references/management-framework.md` -- default management dimensions (customised during setup)
- `references/values-guide.md` -- how org values are used across skills

## Runtime Data

- `manager-context/` -- persisted team context (created by `/setup`, gitignored)
- `outputs/` -- skill outputs (gitignored)
