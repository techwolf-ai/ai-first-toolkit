---
name: customer-status
description: Synthesised view of account health and activity for managers overseeing customer-facing teams (Sales, CS, Professional Services, Presales). Scans project channels, email threads, and Notion pages to surface status, risks, and upcoming milestones -- without requiring the manager to trawl through individual channels. Supports proactive account management.
---

# Customer Status Overview

> **Principle: "Narrow scope, high impact."** One synthesised view across all accounts, so you can spot what needs attention without channel-hopping.

Produces a dashboard-style overview of active customer accounts and internal projects for the manager's team.

## When to Use

- Weekly check-in on account health
- Before leadership meetings where customer status is discussed
- When the manager says "how are our accounts?", "customer status", "any customer risks?"
- Can be filtered: "customer status for [account]", "customer status for [team member]'s accounts"

## Instructions

If any MCP connector is unavailable, follow the connector unavailability protocol in `../../references/operating-principles.md`.

### 1. Load Context

Read from `manager-context/`:
- `sources.md` -- customer/project channels, account mappings
- `manager-profile.md` -- team members and their account assignments
- `team/` -- individual team member profiles and project assignments

If no manager-context exists:
```
⚠️ No manager context found. Run /setup first so I know which accounts and channels to monitor.
I can still search broadly, but results will be less targeted.
```

### 2. Identify Active Accounts

From manager-context, get the list of active accounts/projects and their:
- Slack channels
- Key contacts (team member and customer-side)
- Notion project pages
- Current delivery phase (if documented)

If filtering by account or team member, narrow the scope.

### 3. Scan Per Account

For each active account, gather:

**Slack (last 7 days):**
- Recent messages in the project/customer channel
- Volume of activity (high/normal/low compared to usual)
- Any messages with escalation signals: "blocked", "risk", "delayed", "urgent", "escalate", "concerned"
- Any positive signals: "shipped", "live", "approved", "happy", "great feedback"
- Most recent message timestamp (to detect silent accounts)

**Gmail (last 14 days):**
- Email threads related to this customer
- Any emails with escalation or risk language
- Communication frequency

**Notion:**
- Project/customer status page (if documented in sources.md)
- Last updated date
- Any documented risks or decisions

**Google Drive:**
- Recent shared documents (SOWs, proposals, reports)

### 4. Assess Health Signal

For each account, determine a health signal based on evidence:

- **🟢 Healthy:** Regular activity, positive signals, no escalations, milestones on track
- **🟡 Attention:** Some risk signals, decreased activity, upcoming deadline, stale documentation
- **🔴 At Risk:** Escalation language, blocked progress, customer complaints, silence for >5 days on active project

**Important:** These are signals, not diagnoses. Always show the evidence that led to the assessment.

### 5. Produce the Overview

Read `references/output-template.md` for the full output template structure.

### 6. Sub-Agent Review

Spawn a sub-agent to review the customer status overview with fresh eyes. The reviewer should:
- Check that **health signal assessments are evidence-based** -- every red/yellow rating should cite specific signals, not just absence of activity.
- Verify that **silence is not over-interpreted** -- a quiet channel on a stable account is not the same as a quiet channel on an active delivery.
- Check for **team member workload signals** -- if one person owns many flagged accounts, note it.
- Flag any accounts where the evidence is thin enough that the health signal might be misleading.

Incorporate the reviewer's feedback before presenting the final overview.

### 7. Present and Offer Follow-Up

```
Here's your customer status overview. Want me to:
- Dig deeper into any specific account?
- Prep for a conversation with [team member] about [account]?
- Check email threads for a specific customer?
```

## Important Notes

Read `../../references/operating-principles.md` for shared operating principles (data scope, DM flagging, signals vs diagnoses, connector unavailability).

Additional notes specific to this skill:
- **Don't alarm unnecessarily.** Silence on a channel might mean things are running smoothly. Combine multiple signals before flagging red.
- **Recency matters.** Flag any account where project docs haven't been updated in >2 weeks on active projects.
- **Respect customer confidentiality.** Summarise, don't reproduce customer communications verbatim. When surfacing DM content, flag it as `(from DM)`.
- **Team member context.** If a team member owns multiple accounts, note that -- they might be spread thin.
