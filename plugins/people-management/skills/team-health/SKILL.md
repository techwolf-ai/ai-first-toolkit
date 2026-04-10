---
name: team-health
description: "Periodic check on team dynamics, engagement signals, and development trajectory for all direct reports. Surfaces patterns across the team: who might need more challenge, who might need more support, who hasn't had a 1:1 recently. Uses two universal lenses: performance & growth, and wellbeing & connection. Outputs are prompts for reflection, not diagnoses."
---

# Team Health Check

> **Two lenses, always.** "Development" asks: is this person growing and performing? "Wellbeing" asks: is this person thriving, connected, and energised? Great managers hold both.

A periodic overview of team dynamics, engagement signals, wellbeing, and development trajectory across all direct reports.

## When to Use

- Weekly or biweekly team health review
- Before calibration or planning meetings
- When the manager says "how's my team doing?", "team health check", "anyone I should check in with?"
- When preparing for skip-level conversations

## Instructions

If any MCP connector is unavailable, follow the connector unavailability protocol in `../../references/operating-principles.md`.

### 1. Load Team Context

Read from `manager-context/`:
- `manager-profile.md`: full list of direct reports
- `team/`: individual profiles with goals, projects, last review dates
- `sources.md`: channels and data locations per team member

If context is missing, note it and work with available sources.

### 2. Scan Per Team Member

For each direct report, gather data from the last 14 days (or since last health check):

**Activity & Engagement (Slack):**
- Message volume in team/project channels (relative to their baseline if known)
- Types of messages: asking questions, answering questions, sharing updates, celebrating, flagging issues
- Channels they're active in
- Any public wins or recognition received
- Any public frustration or repeated blockers

**1:1 Cadence (Calendar):**
- When was their last 1:1 with the manager?
- Were recent 1:1s kept or cancelled?
- Are they overdue for a 1:1?

**Development Goals (Notion/Drive):**
- Last time their goals were updated
- Any progress notes or self-assessments
- Are there development areas with no recent activity?

**Workload Signals (Calendar + Slack):**
- Meeting load (heavy/normal/light for their role)
- Are they in channels/meetings outside their usual scope? (scope expansion, could be good or concerning)

**Wellbeing & Connection Signals (Slack + Calendar):**
- Energy & wellbeing: late-night messages, weekend activity, signs of overwork
- Connection: are they participating in non-work channels (#random, social threads, team celebrations)?
- Celebration: have they been recognised or praised recently? Have they celebrated others?
- Tone: are their messages upbeat, neutral, or showing signs of frustration/fatigue? (use as a soft signal only, never diagnose)
- Fun & enjoyment: any signs of passion, enthusiasm, or joy in their work (shipping excitement, sharing wins, volunteering for things)?

### 3. Synthesise Per Person

For each team member, produce a brief profile covering both lenses:

```
### [Name]: [Role]

**🎯 Development & Performance:**
**Activity:** [Normal / Increased / Decreased], [1-line evidence]
**Recent wins:** [list any, or "None surfaced"]
**Goals:** [last updated date], [current / stale]
**Development focus:** [area from goals], [evidence of progress / no visible progress]
**Growth signals:** [scope expansion, new skills, leadership behaviours, or "None"]

**🫂 Wellbeing & Connection:**
**Energy:** [Balanced / High output / Signs of overwork], [evidence, e.g., "messages after 22:00 on 3 nights"]
**Connection:** [Active in social channels / Quiet / Only work-related activity]
**Celebrated/been celebrated:** [yes, details / not recently]
**Tone:** [Positive / Neutral / Worth checking in], [soft signal only]

**Last 1:1:** [date], [on track / overdue]
**Signals to explore:** [friction, blockers, wellbeing patterns, or "None"]
```

### 4. Surface Team-Level Patterns

Look across the team for patterns in both dimensions:

**🎯 Development & Performance patterns:**
- **Recognition gap:** Anyone who hasn't received public recognition in >2 weeks?
- **1:1 gap:** Anyone overdue for a 1:1?
- **Goal staleness:** Anyone whose development goals haven't been updated in >6 weeks?
- **Growth signals:** Anyone taking on new scope or showing leadership behaviours?
- **Performance signals:** Anyone showing decreased engagement across multiple indicators?

**🫂 Wellbeing & Connection patterns:**
- **Energy imbalance:** Anyone consistently working late, weekends, or showing signs of overwork?
- **Isolation risk:** Anyone who's gone quiet in social channels or stopped engaging beyond work tasks?
- **Celebration deficit:** Is the team celebrating wins? Are specific people consistently uncelebrated?
- **Fun factor:** Is there joy and energy in team channels, or has everything become purely transactional?
- **Workload imbalance:** Anyone significantly more or less loaded than peers?

### 5. Produce the Health Check

Read `references/output-template.md` for the full output template structure.

### 6. Present

```
Here's your team health check. These are signals for your reflection. You know your people better than any tool.

Want me to prep a 1:1 for anyone specific?
```

### 7. Sub-Agent Review

Spawn a sub-agent to review the health check with fresh eyes. The reviewer should:
- Check that **both lenses** (Development & Performance and Wellbeing & Connection) are meaningfully covered. Neither should be thin or skipped.
- Check for **baseline awareness**: are signals calibrated against known baselines, or is normal behaviour being flagged?
- Verify that language stays in "signal" territory, never crossing into diagnosis ("seems disengaged", "is struggling").
- Check that **celebration and recognition** are given adequate weight, not just problem-flagging.
- Flag any team member who appears to have very thin data. The manager should know where the blind spots are.

Incorporate the reviewer's feedback before presenting the final health check to the manager.

## Important Notes

Read `../../references/operating-principles.md` for shared operating principles (data scope, DM flagging, signals vs diagnoses, connector unavailability).

Additional notes specific to this skill:
- **Celebrate first.** Lead with wins, recognition, and positive energy. Wellbeing & Connection starts with seeing the good.
- **Both lenses, every time.** Don't skip Wellbeing & Connection when the team is performing well. High performance without care leads to burnout. Don't skip Development & Performance when someone is struggling. Care without growth isn't enough.
- **Goals are the anchor for growth.** The most actionable Development & Performance insight is usually about development goals: are they current? Is there visible progress?
- **Connection is the anchor for care.** The most actionable Wellbeing & Connection insight is usually about belonging: does this person feel seen, celebrated, and connected?
- **Don't run too frequently.** Weekly or biweekly is ideal. Daily health checks would over-index on noise.
