---
name: performance-cycle
description: "Evidence gathering for performance review cycles. Gathers goal completion evidence, peer feedback, development progress, scope changes, and values alignment — organised along the org's performance framework dimensions, with organizational values as the 'how' lens. Surfaces evidence gaps. Never suggests ratings — only organises evidence for the manager's judgment."
---

# Performance Cycle Assistant

> **Principle: "You are responsible."** This skill gathers and organises evidence. Rating decisions and development assessments are the manager's alone.

Helps managers prepare evidence-based assessments for performance review cycles. The org's performance framework dimensions measure *what* was achieved and *how the person developed*. Organizational values measure *how they showed up* while doing it.

## When to Use

- During full review cycles (per the org's review cadence)
- During lighter check-ins between full reviews
- When the manager says "help me prep [name]'s review", "gather evidence for [name]'s performance"
- Can be run for one team member or all reports in batch

## Context: Performance Framework

Load the org's performance framework from `manager-context/performance-framework.md` (created during `/setup`). This defines:
- Framework dimensions and sub-dimensions
- Rating scale
- Promotion readiness labels (if tracked)
- Review cadence

If `manager-context/performance-framework.md` doesn't exist, ask the manager to run `/setup` first.

## Instructions

If any MCP connector is unavailable, follow the connector unavailability protocol in `../../references/operating-principles.md`.

### 1. Identify Scope

Determine who to prepare for:
- Single team member: "prep [name]'s review"
- Whole team: "prep all reviews" (runs sequentially for each report)

Determine the review period:
- Default: last 6 months (for bi-annual review) or last 3 months (for check-in)
- Can be customised: "since [date]"

### 2. Load Context

For the target team member, read from `manager-context/team/[name].md`:
- Their goals (locations in Notion/Drive)
- Their development areas from last review
- Their role and level (from Job Architecture)
- Their projects and responsibilities

Also load:
- `manager-context/performance-framework.md` — for org-specific framework dimensions and rating descriptors (falls back to `../../references/performance-framework.md` defaults)
- `manager-context/management-framework.md` — for org-specific management dimensions (falls back to `../../references/management-framework.md` defaults)
- `../../references/values-guide.md` — for values definitions and signal guidance
- `manager-context/values.md` — for the organization's specific values

### 3. Gather Evidence Along Each Dimension

For each dimension and sub-dimension in the org's performance framework (from `manager-context/performance-framework.md`), gather evidence from connected sources.

For each sub-dimension:
- **Notion:** Pull goals, project pages, status updates, metrics relevant to this dimension
- **Slack:** Search for messages showing activity, feedback, recognition, or friction related to this dimension
- **Google Drive:** Look for deliverables, reports, documents tied to this dimension
- **Calendar:** Check for activities that signal growth or scope changes (new meetings, new stakeholders)
- Compile: what evidence was found, with links

**Common evidence patterns by dimension type:**
- **Results/delivery dimensions:** goal completion, shipped work, quality feedback, business outcomes
- **Growth/development dimensions:** learning activities, new skills applied, scope expansion, behavioural changes
- **Collaboration/leadership dimensions:** cross-team activity, mentoring, influence in discussions

For dimensions that are hardest to assess digitally (e.g., behavioural growth, leadership presence), explicitly flag that the manager's direct observations carry more weight.

### 4. Gather Values Evidence

Values are the "how" — how this person delivered their results and showed up for the team. Search for evidence across the organization's values (from `manager-context/values.md`). See `../../references/values-guide.md` for guidance on finding value signals.

For each value defined in `manager-context/values.md`, search for evidence using the signal guidance stored there. Common evidence sources by value type:

**Collaboration / teamwork values:**
- Slack: cross-team collaboration, helping unblock others, participating in team decisions
- DMs (with manager): conversations about team dynamics, commitment to group decisions

**Ambition / ownership values:**
- Slack/Notion: volunteering for stretch work, proposing ideas, driving outcomes
- Evidence of taking things to completion without being pushed

**Innovation / resourcefulness values:**
- Slack: creative problem-solving, finding workarounds, learning from obstacles
- Evidence of unblocking themselves or the team under constraints

**Transparency / communication values:**
- Slack: sharing context proactively, raising issues early, giving and receiving feedback
- DMs (with manager): being open about challenges, asking for help

**Care / wellbeing values:**
- Slack: celebrating others, recognising teammates, showing empathy
- Calendar: sustainable work patterns or concerning overwork patterns

For each value, compile evidence as observations (not judgments):
- **Strong signal:** Multiple visible examples
- **Some signal:** 1-2 examples
- **Gap:** No evidence found (note: absence of evidence ≠ absence of the behaviour)

### 5. Check Peer Recognition

Search Slack for recognition this person received during the review period:
- Direct shoutouts from teammates
- Recognition in team channels
- Reactions on their messages (high-reaction messages = valued contributions)

### 6. Identify Evidence Gaps

For each dimension, assess evidence strength:
- **Strong evidence:** Multiple sources corroborate
- **Some evidence:** 1-2 data points
- **Gap:** No evidence found — manager needs to gather this manually

### 7. Produce the Evidence Summary

Read `references/output-template.md` for the full output template structure (individual and batch mode).

### 8. For Batch Mode (All Reports)

If preparing for the whole team, produce individual evidence summaries for each team member plus a team-level comparison view. See the batch mode template in `references/output-template.md`.

### 9. Present

```
Here's the evidence I gathered for [name]'s review. I've flagged gaps where you'll want to add your own observations.

Remember: this is evidence gathering only. Rating decisions and promotion assessments are yours to make based on the full picture — including things I can't see.
```

### 10. Sub-Agent Review

Spawn a sub-agent to review the evidence summary with fresh eyes. The reviewer should:
- Check for **recency bias** — is most evidence from the last few weeks, or spread across the review period?
- Check for **dimension imbalance** — are some dimensions well-evidenced while others are thin? Flag under-covered areas.
- Check for **interpretive language** — flag any phrasing that crosses from evidence ("shipped X on time") into interpretation ("demonstrated strong execution").
- Verify evidence gaps are honestly flagged, not papered over with weak data.
- Check that values evidence is presented as "examples I found", not "the full picture."

Incorporate the reviewer's feedback before presenting the final summary to the manager.

## Important Notes

Read `../../references/operating-principles.md` for shared operating principles (data scope, DM flagging, signals vs diagnoses, connector unavailability).

Additional notes specific to this skill:
- **NEVER suggest a rating.** Not even hints. The manager decides ratings. Period.
- **NEVER compare team members to each other.** Evidence is per-person. Calibration is the manager's job.
- **Evidence, not interpretation.** "Shipped feature X on time" is evidence. "Demonstrated strong execution" is interpretation. Stick to evidence.
- **Flag gaps honestly.** "I found no evidence for behavioral growth" is more useful than padding with weak data.
- **Recency bias warning.** Note if most evidence is from the last month vs. spread across the review period.
- **Values evidence is hardest to gather digitally.** Many values are lived in person, not in Slack. The manager's direct observations are more authoritative.
- **This supplements, not replaces.** The manager has 6 months of direct observation.
