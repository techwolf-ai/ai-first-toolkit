---
name: priority-planner
description: Helps managers cut through noise and identify their highest-leverage actions for the day or week. Aggregates signals from calendar, triage, team context, and OKRs/goals. Presents a suggested focus list grouped by urgency, importance, and investment -- the manager reviews and adjusts. Supports effective execution and prioritisation.
---

# Priority Planner

> **Principle: "You are responsible."** The skill proposes, the manager decides. This is not a task manager -- it's a thinking partner for prioritisation.

Aggregates signals from multiple sources to surface the manager's highest-leverage actions.

## When to Use

- Start of day: "what should I focus on today?"
- Start of week: "plan my week"
- When overwhelmed: "help me prioritise"
- After a triage: "fold these into my priorities"

## Instructions

If any MCP connector is unavailable, follow the connector unavailability protocol in `../../references/operating-principles.md`.

### 1. Determine Scope

Ask or infer whether this is a daily or weekly plan:
- Daily: focus on today's calendar, current triage, immediate needs
- Weekly: broader view including upcoming deadlines, OKRs, team development

### 2. Load Goals

Before gathering signals, load the manager's goals -- these are the lens through which everything gets prioritised.

**From `manager-context/manager-goals.md`:**
- The manager's own OKRs and goals
- Their manager's key priorities
- Upcoming personal milestones and deadlines

**From Notion/Drive (if goals location is known):**
- Pull the latest version of OKRs in case they've been updated since setup

If no goals are found:
```
⚠️ I don't have your goals on file. Without them I can prioritise by urgency, but not by impact alignment.
Run /setup or tell me your current OKRs so I can connect your priorities to what matters most.
```

### 3. Gather Signals

Pull from multiple sources:

**Calendar (today or this week):**
- Meetings scheduled and their topics
- Free blocks (potential focus time)
- Deadlines tied to calendar events

**Triage results (if /triage-messages was recently run):**
- Any 🔴 "Needs Decision" items still unresolved
- 🟡 Team needs awaiting attention
- Customer items flagged

**Manager Context (from manager-context/):**
- Team members' current projects and any known blockers
- Development conversations due
- 1:1s this week and prep status
- Triage rules (VIPs, hot channels) from `triage-rules.md`

**Notion:**
- Search for OKRs, quarterly goals, team priorities docs
- Any pages tagged with deadlines or milestones

**Slack:**
- Threads where the manager promised to follow up
- Open questions directed at the manager

### 4. Categorise into Buckets

Group everything into three categories (inspired by Eisenhower):

**🔴 Urgent -- Time-Sensitive Decisions**
Things where someone is blocked or a deadline is imminent:
- Decisions only the manager can make
- Escalations that need resolution today
- Deadlines within 24-48 hours
- Framework: Execution

**🟡 Important -- High-Impact Work**
Things that move OKRs and team goals forward:
- Strategic work (planning, decision-making, alignment)
- Cross-functional alignment needed
- Customer-related actions that affect account health
- Framework: Delegation & Execution

**🟢 Invest -- Development & Strategic Thinking**
Things that compound over time but rarely feel urgent:
- 1:1 preparation and development conversations
- Team health check-ins
- Hiring pipeline attention
- Strategic thinking and planning
- Framework: People Development

### 5. Produce the Plan

Read `references/output-template.md` for the full output template structure.

### 6. Present and Iterate

```
Here's a suggested priority plan. This is a starting point -- adjust based on your judgment. Want me to:
- Move anything between categories?
- Add something I missed?
- Prep for any of these items?
```

## Important Notes

Read `../../references/operating-principles.md` for shared operating principles (data scope, DM flagging, signals vs diagnoses, connector unavailability).

Additional notes specific to this skill:
- **Never prescribe.** Use "I'd suggest", "Consider". The manager knows context the tool doesn't.
- **The Invest bucket is crucial.** Don't let it be empty. Great managers always invest time in development, even when busy.
- **Connect to frameworks.** Note which management framework dimension (from `manager-context/management-framework.md`) an action supports.
- **Don't just list everything.** The "What I'd Deprioritise" section is often more valuable than the priority list itself.
- **Time-box awareness.** If the calendar is packed, don't suggest 8 hours of focus work. Be realistic.
- **Goal alignment is the core insight.** If there's persistent drift between daily activity and goals, say so clearly.
- **Be honest about drift.** Don't sugarcoat. If 80% of time is reactive and 0% on OKRs, name it.
