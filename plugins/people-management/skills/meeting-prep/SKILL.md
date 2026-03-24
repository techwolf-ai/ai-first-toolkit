---
name: meeting-prep
description: Comprehensive pre-meeting briefing that gathers all relevant context from Slack, email, Google Docs, Notion, and calendar. Produces a structured prep document so the manager walks into every meeting fully prepared. Supports thorough meeting preparation.
---

# Meeting Prep

> **Principle: "Narrow scope, high impact."** One meeting, one thorough brief. No guessing — only sourced context.

Gathers context from all connected sources for a specific upcoming meeting and produces a structured briefing.

## When to Use

- Before any meeting (1:1s have their own skill — use `/prep-one-on-one` instead)
- When the manager says "prep me for [meeting]", "what do I need to know for [meeting]"
- Can be invoked for the next upcoming meeting or a specific one by name/time

## Instructions

If any MCP connector is unavailable, follow the connector unavailability protocol in `../../references/operating-principles.md`.

### 1. Identify the Meeting

If not specified, check Google Calendar for the next upcoming meeting.

If specified by name or time, search calendar for the matching event.

Extract from the calendar event:
- **Title**
- **Time and duration**
- **Attendees** (names and emails)
- **Location/link**
- **Description/agenda** (if present)
- **Attached documents** (if any)

If no matching meeting is found:
```
I couldn't find a meeting matching "[query]" on your calendar.
Could you clarify which meeting you mean? Your upcoming meetings are:
- [list next 5 meetings with times]
```

### 2. Load Manager Context

Read from `manager-context/` (created by /setup):
- `manager-profile.md` for team members and stakeholders
- `terminology.md` for decoding any internal terms
- `sources.md` for known data locations

If manager-context doesn't exist, note this:
```
⚠️ No manager context found. Run /setup first for richer meeting prep.
Proceeding with what I can find from sources directly.
```

### 3. Gather Attendee Context

For each attendee, search across sources:

**Slack:**
- Recent messages from/by this person (last 7 days)
- Threads they've been active in that relate to meeting topics
- Any messages that mention the meeting topic

**Gmail:**
- Recent email threads with this person (last 14 days)
- Especially any threads that include multiple meeting attendees

**Google Drive:**
- Shared documents with this person
- Docs recently edited by them that relate to meeting topics

**Notion:**
- Pages authored or edited by them recently
- Any decision logs or project pages relevant to the meeting

**From manager-context** (if available):
- Their role, team, and relationship to the manager
- Any known context from previous interactions

### 4. Gather Topic Context

Based on the meeting title, description, and agenda:

**Identify key topics** from the meeting title and description.

For each topic, search:
- **Slack** for recent discussions (last 14 days)
- **Notion** for related pages, decisions, project status
- **Google Drive** for related documents (pre-reads, previous meeting notes)
- **Gmail** for related threads

### 5. Find Previous Meeting Notes

Search for prior instances of this meeting:
- **Google Drive:** Search for docs matching the meeting name + "notes", "minutes", "recap"
- **Notion:** Search for pages matching the meeting name

If found, extract:
- Action items from the last meeting
- Decisions made
- Open questions carried forward

### 6. Produce the Briefing

Structure the output as follows:

```markdown
# Meeting Prep: [Meeting Title]
📅 [Day, Date] at [Time] ([Duration])
👥 [Number] attendees

## Attendees
| Who | Role | Recent Context |
|-----|------|----------------|
| [Name] | [Role/team] | [1-line summary of what they've been working on or last interaction] |

## Agenda & Context
### [Topic 1 from agenda]
[2-3 sentence summary of current state, sourced from Slack/Notion/Drive]
- 🔗 [Link to relevant doc/thread]

### [Topic 2]
[Summary with sources]

## Open Items from Last Meeting
- [ ] [Action item] — assigned to [name], status: [done/pending/unknown]
- [ ] [Action item] — assigned to [name], status: [done/pending/unknown]

## Suggested Talking Points
Based on what I've found, you might want to:
- [Point based on a gap, conflict, or unresolved thread]
- [Point based on a decision that needs to be made]
- [Point based on something that's changed since last meeting]

## Source Links
- [Doc title](link)
- [Slack thread](link)
- [Notion page](link)
```

### 7. Present to Manager

Share the briefing and offer follow-up:
```
Here's your prep for [meeting]. Anything you'd like me to dig deeper on?
```

## Important Notes

Read `../../references/operating-principles.md` for shared operating principles (data scope, DM flagging, signals vs diagnoses, connector unavailability).

Additional notes specific to this skill:
- **Don't draft talking points as scripts.** Frame as prompts: "You might want to discuss..." not "Say this..."
- **If context is thin**, say so: "I found limited context for this meeting."
- **1:1 meetings:** Redirect to `/prep-one-on-one` which has deeper team-member-specific logic.
