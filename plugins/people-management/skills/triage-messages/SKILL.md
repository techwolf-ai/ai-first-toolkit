---
name: triage-messages
description: Batch-processes Slack messages and emails to surface what needs the manager's attention, categorised by urgency and type. Designed for batch-responder managers who do Slack sweeps rather than staying in reactive mode. Supports effective communication and responsiveness. Never drafts replies — only surfaces and prioritises.
---

# Triage Messages

> **Principle: "You are responsible."** This skill surfaces and categorises. The manager decides what to act on and how.

Scans unread Slack messages and recent emails, categorises them by urgency and type, and presents a prioritised overview.

## When to Use

- Morning routine — catch up on what happened overnight
- After a block of focus time or meetings
- When the manager says "what did I miss?", "catch me up", "triage my messages"
- Can be scoped to a time window: "triage since yesterday", "triage last 2 hours"

## Instructions

If any MCP connector is unavailable, follow the connector unavailability protocol in `../../references/operating-principles.md`.

### 1. Determine Time Window

Default: since the manager's last likely check-in (use calendar to estimate — if they were in back-to-back meetings for 3 hours, scan those 3 hours).

If specified: use the provided time window.

If unclear, ask:
```
What time period should I triage? Options:
- Since this morning
- Last [N] hours
- Since yesterday
- Custom range
```

### 2. Load Manager Context

Read from `manager-context/` (if available):
- `manager-profile.md` — to know who the direct reports are (their messages get higher priority)
- `terminology.md` — to decode internal shorthand in messages
- `team/` — to understand team members' projects and responsibilities
- `sources.md` — to know which customer/project channels to monitor

### 3. Scan Slack

Search for messages in the time window:

**Priority channels** (scan first):
- Channels where the manager was @-mentioned
- DMs to the manager
- Team channels (from manager-context)
- Customer/project channels (from manager-context)

**Broader channels** (scan for relevance):
- Company-wide channels
- Cross-functional channels the manager is in

For each message/thread, capture:
- Who sent it
- Channel
- Content summary (1 line)
- Whether the manager was mentioned or it's in a direct thread
- Link to the message

### 4. Scan Email

Search Gmail for messages in the time window:

- Unread emails
- Emails where the manager is in To: (not just CC:)
- Emails from direct reports or known stakeholders
- Emails with urgent/action keywords

For each email, capture:
- Sender
- Subject
- Brief summary
- Whether it requires action or is FYI

### 5. Categorise

Sort everything into these buckets:

**🔴 Needs Your Decision**
- Blockers waiting on the manager
- Approval requests
- Escalations
- Time-sensitive decisions
- Criteria: someone is explicitly waiting for the manager's input

**🟡 Team Member Needs**
- Questions from direct reports
- Requests for help or guidance
- Friction signals (repeated blockers, frustration)
- Criteria: a team member needs support but isn't fully blocked

**🔵 FYI / Context**
- Status updates
- Announcements
- Cross-functional threads where the manager should be aware
- Criteria: useful to know, no action needed right now

**🟢 Customer-Related** (if applicable)
- Messages in customer/project channels
- Customer-related emails
- Delivery updates, escalations, timeline changes

### 6. Present the Triage

```markdown
# Message Triage — [Date], [Time Window]

## 🔴 Needs Your Decision ([count])
| Priority | From | Channel/Subject | Summary | Link |
|----------|------|-----------------|---------|------|
| 1 | [name] | #[channel] | [1-line summary — what they need from you] | [link] |

## 🟡 Team Member Needs ([count])
| From | Channel/Subject | Summary | Link |
|------|-----------------|---------|------|
| [name] | #[channel] | [1-line summary] | [link] |

## 🟢 Customer-Related ([count])
| Account | From | Summary | Link |
|---------|------|---------|------|
| [customer] | [name] | [1-line summary] | [link] |

## 🔵 FYI / Context ([count])
| From | Channel/Subject | Summary | Link |
|------|-----------------|---------|------|
| [name] | #[channel] | [1-line summary] | [link] |

---
📊 Total: [N] items ([X] decisions, [Y] team needs, [Z] customer, [W] FYI)
```

### 7. Offer Follow-Up

```
That's your triage for [time window]. Want me to:
- Dig deeper on any specific item?
- Prep context for responding to something?
- Run /plan-priorities to fold these into your day?
```

## Important Notes

Read `../../references/operating-principles.md` for shared operating principles (data scope, DM flagging, signals vs diagnoses, connector unavailability).

Additional notes specific to this skill:
- **Never draft replies.** The manager writes their own messages. This skill only surfaces and categorises.
- **Don't over-categorise as urgent.** Reserve the red category for genuine blockers. Most things are FYI.
- **Link everything.** Every item should link directly to the source message/email.
- **Decode shorthand.** Use terminology.md to translate internal terms so the triage is immediately clear.
- **If volume is high** (50+ messages), summarise the FYI bucket rather than listing every item.
