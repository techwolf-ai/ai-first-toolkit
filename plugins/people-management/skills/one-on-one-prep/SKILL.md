---
name: one-on-one-prep
description: "Deep-dive preparation for 1:1 meetings with direct reports. Surfaces recent work, wins, friction, wellbeing signals, and development goal progress — anchored in the org's performance framework, organizational values, and management best practices. Produces a prep sheet with suggested conversation topics, not a script."
---

# 1:1 Prep

> **Great 1:1s live at the intersection of performance and care.** Development keeps growth alive. Wellbeing makes sure the person behind the work is seen. Both matter every time.

Deep-dive preparation for 1:1 meetings with a specific direct report, anchored in the org's performance framework (from `manager-context/performance-framework.md`) and organizational values.

## When to Use

- Before any 1:1 meeting with a direct report
- When the manager says "prep my 1:1 with [name]", "what should I discuss with [name]"
- Can be invoked with just a name — the skill finds the relevant context

## Instructions

If any MCP connector is unavailable, follow the connector unavailability protocol in `../../references/operating-principles.md`.

### 1. Identify the Team Member

If a name is provided, match it against `manager-context/team/` profiles.

If no name is specified, check the calendar for the next upcoming 1:1 meeting and identify the attendee.

If ambiguous:
```
Which team member? Your upcoming 1:1s are:
- [Name] — [day] at [time]
- [Name] — [day] at [time]
```

Load the team member's profile from `manager-context/team/[name].md` for:
- Their role, current projects, communication style
- Goals location (Notion page, Drive doc)
- Last review date and development areas
- Last 1:1 date and open items

If no profile exists:
```
⚠️ No profile found for [name]. Run /setup to build team context, or I'll work with what I can find from sources directly.
```

### 2. Surface Recent Work & Wins

**Slack (last 7-14 days):**
- Messages posted by this person in team/project channels
- Threads they've been active in
- Any shoutouts or recognition they received (search for their name + positive signals like "great", "shipped", "amazing", "thanks")
- Features shipped, PRs merged, deliverables completed (visible in public channels)

**Google Drive:**
- Documents they've recently created or edited
- Especially docs related to their projects or deliverables

**Notion:**
- Pages they've authored or updated recently
- Project status updates they've contributed to

Compile into a "recent activity" summary.

### 3. Detect Friction or Concerns

Look for signals (NOT diagnoses — signals for the manager to explore):

**Slack:**
- Repeated blockers or unanswered questions
- Messages where they expressed frustration or confusion
- Decreased activity compared to usual patterns (if baseline is known)
- Long threads where they're asking for help without clear resolution

**Calendar:**
- Cancelled or rescheduled 1:1s
- Unusually heavy or light meeting load

**Important:** Frame these as *conversation starters*, not assessments:
```
💡 Potential topics to explore (signals, not conclusions):
- [Name] asked about [topic] in #channel 3 times this week without a clear resolution — might be a blocker worth discussing
- [Name]'s activity in #project-channel has been lower than usual — could be fine, but worth checking in
```

### 4. Values & Wellbeing Check

Scan for signals related to the organization's values (from `manager-context/values.md`) — these give the manager conversation threads beyond just goals and deliverables.

If no values are configured, focus on these universal management dimensions:

**Wellbeing & Energy:**
- Late-night or weekend Slack activity (potential overwork)
- Calendar density (back-to-back days, no focus time)
- Tone in recent messages — enthusiasm vs. fatigue (soft signal only)
- Have they taken time off recently?

**Team Connection & Collaboration:**
- Are they collaborating across the team, or working in isolation?
- Engagement in team channels (social, celebrations)
- Have they helped or unblocked teammates recently?

**Communication & Transparency:**
- Are they sharing context, asking for feedback, raising issues openly?
- Any threads where they seemed hesitant to speak up?

**Resourcefulness & Problem-Solving:**
- Evidence of creative problem-solving, unblocking themselves, learning new things

**Ownership & Initiative:**
- Volunteering for stretch work, proposing ideas, taking initiative
- Driving things to completion vs. waiting for direction

If organizational values are configured, map these dimensions to the specific values and use value names in the output.

Compile into a brief values snapshot (not a scorecard — conversation prompts):

```
Values Snapshot:
- [Value/Dimension 1]: [observation or "no signal"]
- [Value/Dimension 2]: [observation or "no signal"]
...
```

_Only include values/dimensions where there's a meaningful signal — don't force all of them every time._

### 5. Check Development Goals

Using the goals location from the team member's profile:

**Notion:**
- Pull their current goals and development areas
- Check when goals were last updated
- Look for any self-assessment or progress notes

**Google Drive:**
- Pull the 1:1 document for this person
- Check the most recent entries for open action items and commitments

**Reference the org's performance framework dimensions** (from `manager-context/performance-framework.md`). Use the org's dimension names and sub-dimensions when checking goal progress. If this file doesn't exist, ask the manager to run `/setup` first.

See the "Evidence Gathering Guidelines" section in `../../references/performance-framework.md` for what to look for per dimension type:
- **Results/delivery dimensions:** goal completion, shipped work, quality feedback, business outcomes
- **Growth/development dimensions:** learning activities, new skills applied, scope expansion, behavioural changes
- **Collaboration/leadership dimensions:** cross-team activity, mentoring, influence in discussions

```
📋 Development Goal Status:
- Goal 1: "[goal text]" — [status: on track / needs attention / no update since [date]]
- Goal 2: "[goal text]" — [status]
- Development area: "[area]" — [any evidence of progress or attention]

⏰ Last goal update: [date] — [flag if >6 weeks old]
```

### 6. Pull Previous 1:1 Notes

Search for the last 1:1 document/notes:

**Google Drive:** Search "[name] 1:1", "one on one [name]"

Extract:
- Open action items (for both manager and team member)
- Topics that were "parked" for follow-up
- Development commitments made

```
📝 From last 1:1 ([date]):
Open items:
- [ ] [Manager] to [action] — [status: done/pending/unknown]
- [ ] [Team member] to [action] — [status: done/pending/unknown]
Parked topics: [if any]
```

### 7. Produce the Prep Sheet

Read `references/output-template.md` for the full output template structure.

### 8. Sub-Agent Review

Spawn a sub-agent to review the prep sheet with fresh eyes. The reviewer should:
- Check that **wellbeing signals are framed as conversation starters**, not assessments or diagnoses.
- Check that the **values snapshot** only includes values with meaningful signals -- not forcing all values every time.
- Verify that **wins lead the document** and the tone is constructive, not surveillance-like.
- Flag any phrasing that crosses from observation ("posted after 22:00 three times") into interpretation ("seems burned out").
- Check that evidence gaps are noted where data is thin, rather than padded with weak signals.

Incorporate the reviewer's feedback before presenting the final prep sheet.

### 9. Present and Offer Follow-Up

```
Here's your prep for your 1:1 with [name]. Anything you'd like me to dig deeper on?
```

## Important Notes

Read `../../references/operating-principles.md` for shared operating principles (data scope, DM flagging, signals vs diagnoses, connector unavailability).

Additional notes specific to this skill:
- **Wins first.** Always lead with recognition opportunities — this sets the tone.
- **Goals are the backbone.** If goals are missing or stale, flag it prominently. Great 1:1s keep development goals alive.
- **Framework + values alignment.** Suggested questions should map to the org's performance framework dimensions or organizational values. Don't force all values every time — only surface values where there's a real signal.
- **Values are conversation threads, not checklists.** The values snapshot helps managers notice things beyond deliverables. A 1:1 that only covers goals misses the human. A 1:1 that only covers feelings misses the growth. Both.
- **Don't script the conversation.** Provide prompts and context, not a talk track.
