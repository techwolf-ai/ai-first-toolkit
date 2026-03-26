# Manager Context File Templates

Templates for all files persisted during manager setup. Each template shows the expected structure -- fill in validated data from discovery phases.

## `manager-context/output-preferences.md`

```markdown
# Output Preferences

**Last updated:** [date]

## General Style
- Language: English
- Tone: Professional, concise -- bullet points over prose
- Detail level: Moderate (summaries with source links)
- Emoji: Yes (for visual scanning in triage/priorities)

## File Format
- Default: Markdown (.md)
- Exceptions: [any noted by manager, e.g. .docx for performance reviews]

## Filename Format
- Pattern: `YYYY-MM-DD-<skill>-<subject>`
- Date position: prefix
- Example: `2026-03-13-one-on-one-prep-alex.md`

## Folder Structure
- Root: `outputs/`
- Organisation: by skill type (subdirectory per skill)
- Subdirectories: meeting-prep, one-on-one-prep, triage, team-health, performance, customer-status, priorities

## Notes
- [Any custom preferences noted during setup]
```

## `manager-context/performance-framework.md`

> **Required:** Skills that need the performance framework will ask the manager to run `/setup` if this file is missing.

```markdown
# Performance Framework

**Last updated:** [date]

## Dimensions

### [Dimension 1 Name, e.g., Impact]
[Description]

| Sub-dimension | What it means |
|--------------|---------------|
| [sub-dimension] | [description] |

### [Dimension 2 Name, e.g., Growth]
[Description]

| Sub-dimension | What it means |
|--------------|---------------|
| [sub-dimension] | [description] |

## Rating Scale
| Rating | Description |
|--------|-------------|
| [rating] | [description] |

## Promotion Readiness
| Label | Meaning |
|-------|---------|
| [label] | [meaning] |

(If not tracked, note: "Not formally tracked")

## Review Cadence
| Cycle | Type | When |
|-------|------|------|
| [cycle name] | [full review / light check-in] | [period] |

## Goal Cadence
- Cycle: [quarterly / half-yearly / annual]
- Current period: [period]
```

## `manager-context/management-framework.md`

> **Required:** Skills that need the management framework will ask the manager to run `/setup` if this file is missing.

```markdown
# Management Framework

**Last updated:** [date]

## Dimensions

### [Dimension 1 Name, e.g., Results]
[Description]

- **[Competency]** -- [what it looks like]
- **[Competency]** -- [what it looks like]

### [Dimension 2 Name, e.g., People]
[Description]

- **[Competency]** -- [what it looks like]
- **[Competency]** -- [what it looks like]

## How Managers Are Evaluated
- [Separate management track / same framework as ICs / informal]

## Notes
- [Any org-specific context]
```

## `manager-context/manager-goals.md`

```markdown
# Manager's Own Context

**Last updated:** [date]

## Reports To
- Name: [name]
- Role: [role]
- Key priorities: [what they care about]

## My OKRs / Goals
- Location: [Notion page / Drive doc link]
- [Goal 1]
- [Goal 2]
- [Goal 3]

## Upcoming Milestones
- [milestone] -- [date]

## Notes
- [Any context about what's being measured, org priorities, etc.]
```

## `manager-context/triage-rules.md`

```markdown
# Triage & Priority Rules

**Last updated:** [date]

## VIP -- Always Surface
| Who | Why |
|-----|-----|
| [name] | [manager / key stakeholder / customer champion] |

## Hot Channels & Keywords
| Channel / Keyword | Why |
|-------------------|-----|
| #[channel] | [incident channel / escalation path] |
| "[keyword]" | [signals urgency] |

## Deprioritise
- [bot channels, automated notifications, etc.]

## Privacy Boundaries
- [channels or topics to skip]

## Notes
- [Any other triage preferences]
```

## `manager-context/review-calendar.md`

```markdown
# Performance & Review Calendar

**Last updated:** [date]

## Cycle Dates
| Cycle | Period | Type | Self-review Due | Manager Review Due | Calibration |
|-------|--------|------|----------------|-------------------|-------------|
| [cycle name] | [dates] | [full review / check-in] | [date] | [date] | [date] |

## Goal Cadence
- Cycle: [quarterly / half-yearly]
- Current period: [Q1 2026 / H1 2026]

## Promotion Nominations
- Next window: [date or "unknown"]

## Notes
- [Any team-specific exceptions or context]
```

## `manager-context/skill-preferences.md`

```markdown
# Skill & 1:1 Preferences

**Last updated:** [date]

## 1:1 Style
- Format: [structured / free-flow / hybrid]
- Always include: [goals check, wins, blockers, development -- whatever they said]
- Share prep with report: [yes / no]
- Notes: [any other preferences]

## Skill Rhythm
| Skill | Cadence | When |
|-------|---------|------|
| triage-messages | Daily | Morning |
| plan-priorities | Daily | After triage |
| prep-one-on-one | Per 1:1 | Day before |
| prep-meeting | As needed | Before meetings |
| check-team-health | [Weekly / Biweekly] | [day] |
| customer-status | [Weekly / As needed] | [day] |
| prep-performance | Per cycle | [weeks before deadline] |
```

## `manager-context/manager-profile.md`

```markdown
# Manager Profile

**Name:** [name]
**Role:** [role]
**Teams:** [teams]
**Last updated:** [date]

## Direct Reports
| Name | Slack | Role | 1:1 Cadence | Goals Location | Last Review |
|------|-------|------|-------------|----------------|-------------|
| [name] | @[handle] | [role] | Weekly | [Notion page / Drive doc] | [date] |

## Key Stakeholders
| Name | Relationship | Context |
|------|-------------|---------|
| [name] | [skip-level / cross-functional / etc.] | [context] |

## Communication Preferences
- [preferences discovered]

## Rhythm
- [meeting cadence, working patterns]
```

## `manager-context/team/[name].md`

One file per direct report:

```markdown
# [Full Name]

**Slack:** @[handle]
**Role:** [role]
**Reports to:** [manager]

## Goals & Development
- **Current goals location:** [Notion page link / Drive doc link]
- **Last goal update:** [date]
- **Development areas:** [from most recent review/goals]

## Context
- **Primary channels:** #[channel], #[channel]
- **Current projects:** [projects]
- **Working style notes:** [any patterns noticed]
```

## `manager-context/terminology.md`

```markdown
# Team Terminology

| Term | Meaning | Context |
|------|---------|---------|
| [term] | [meaning] | [where it's used] |
```

## `manager-context/sources.md`

```markdown
# Data Source Locations

Where to find key information for this manager's team.

## Performance & Goals
| Team Member | Goals | Reviews | 1:1 Notes |
|-------------|-------|---------|-----------|
| [name] | [Notion link] | [Notion link] | [Drive link] |

## Team Docs
- Team page: [link]
- OKRs: [link]
- Hiring pipeline: [link]

## Customer/Project Channels
| Account | Slack Channel | Project Page | Key Contact |
|---------|--------------|--------------|-------------|
| [account] | #[channel] | [Notion link] | [name] |
```

## values.md

**Persist to `manager-context/values.md`:**
```markdown
# Organizational Values

**Last updated:** [date]

## Values

| Value | Description | Signals to look for |
|-------|-------------|-------------------|
| [value name] | [brief description] | [what it looks like in Slack, docs, meetings] |

## How Values Are Used in Reviews
- [any org-specific guidance on values in performance reviews]

## Notes
- [how heavily to weigh values, any org-specific context]
```
