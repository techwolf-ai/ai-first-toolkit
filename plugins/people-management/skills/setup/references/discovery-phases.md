# Discovery Phases — Detailed Instructions

Detailed crawl instructions, conversation prompts, and validation formats for each setup phase.

## Phase 1: Team Discovery

### 1.1 Identify the Manager

Ask:
```
Let's set up your manager context. A few quick questions:

1. What's your name and role?
2. Which team(s) do you manage?
3. How many direct reports do you have? (rough count is fine)
```

### 1.2 Crawl Team Structure

Search for the manager's team across sources:

**Slack:**
- Channels the manager is in (especially team/project prefixes)
- Frequent DM partners and channel participants
- People who @-mention or are @-mentioned by the manager frequently

**Notion:**
- Team pages, org charts, reporting structure docs
- Pages with the manager's name or team name

**Google Calendar:**
- Recurring 1:1 meetings — attendees are likely direct reports
- Team syncs, standups, regular meetings

**Gmail:**
- Frequent email correspondents within the company

For each person, gather: full name, Slack handle, role/title, how they were discovered.

### 1.3 Validate Team

Present findings:
```
I found these people who appear to be your direct reports:

1. [Name] — [role], found via [1:1 calendar + Slack #team-channel]
2. [Name] — [role], found via [Slack DMs + Notion team page]
3. [Name] — [role], found via [Slack channel only — unsure if direct report]

Are these correct? Anyone missing? Anyone who shouldn't be on this list?
```

Wait for confirmation. Adjust based on feedback.

### 1.4 Discover Terminology & Shorthand

**Slack:** Search recent messages (last 30 days) in team channels for capitalized abbreviations, quoted terms, internal codenames.

**Notion:** Search for glossary pages, onboarding docs.

Present grouped:
```
I found these internal terms:

**Confident:** [term] → [meaning]
**Needs verification:** [term] → [guess]?
**Uncertain:** [term] → ?

Please correct anything wrong and fill in the uncertain ones.
```

### 1.5 Discover Development Goals & Performance Data

For each team member, search:

**Notion:** Performance review pages, goal banks, 90-day plans, development notes.
**Google Drive:** 1:1 documents, performance notes, development plans.

Report per person:
```
✅ [Name] — Found goals in Notion, 1:1 doc in Drive, last review [date]
⚠️ [Name] — Found 1:1 doc but NO goals. Where do you track these?
❌ [Name] — Couldn't find any performance data. Where should I look?
```

If goals are missing, explicitly ask where they're documented.

### 1.6 Discover Ways of Working

**Calendar:** 1:1 cadence per report, team sync frequency, skip-level meetings, cross-functional meetings.
**Slack:** Primary channels, communication rhythm, purpose-specific channels.

Present:
```
Your rhythm looks like this:
- 1:1s: Weekly with [names], biweekly with [names]
- Team sync: [day/time] in [channel/meeting]
- Communication style: [batch responder / real-time]
- Most active channels: #[channel], #[channel]

Anything I should know about how you prefer to work?
```

### 1.7 Customer & Project Context (if applicable)

For customer-facing teams:

**Slack:** Identify project/customer channels (#proj-*, #customer-*, #account-*). Map team members to channels.
**Notion:** Project pages, customer status docs, delivery trackers.

Present:
```
Active accounts/projects:
- [Customer] — [team member] is primary, channel: #proj-[name]
- [Project] — Internal, [team member] is leading

Any accounts I'm missing?
```

---

## Phase 2: Organizational Values

Ask:
```
Does your organization have defined core values?

If yes:
1. What are they? (list the names)
2. Where are they documented? (Notion page, handbook, etc.)
3. How are they used in performance reviews or feedback?

If no:
That's fine — we can skip the values lens in skills, or you can define informal values later.
```

If documented, search Notion and Drive for the values page. Extract value names and associated behaviours.

For each value, ask:
- What does this value look like in practice for your team?
- What signals might I find in Slack, docs, or meetings?

Present:
```
Here's my understanding of your values:

1. [Value Name] — [description]. Signals: [what to look for]
2. [Value Name] — [description]. Signals: [what to look for]

Correct? Any values I should weigh more heavily in 1:1 prep or team health?
```

Persist to `manager-context/values.md`. Read `references/context-templates.md` for template.

---

## Phase 3: Output Preferences

Present defaults and let the manager adjust:
```
How should I produce and save outputs? Defaults — adjust anything:

**Style:** English, professional/concise, moderate detail, emoji for visual scanning
**File format:** Markdown (.md)
**Filename:** YYYY-MM-DD-<skill>-<subject>.md
**Folders:** outputs/ with subdirectories per skill type

Options: language, shorter/longer, .docx/.html, flat/weekly folders, different naming
```

Persist to `manager-context/output-preferences.md`. All other skills must read this before saving output.

---

## Phase 4: Manager's Own Context

```
A few questions about your own context:

1. **Who do you report to?** (name, role)
2. **What are your current OKRs or goals?** (or where documented?)
3. **What does your manager care most about right now?**
4. **Any key deadlines or milestones coming up?**
```

Search Notion and Drive for the manager's own goals if they point to a location.

Persist to `manager-context/manager-goals.md`.

---

## Phase 5: Triage Rules

```
Let's set up your triage rules:

1. **VIP people** — whose messages always bubble to the top?
2. **Hot channels or topics** — channels/keywords that always mean urgent?
3. **Deprioritise** — anything to push to the bottom?
4. **Privacy boundaries** — channels, people, or topics to skip entirely?
```

Persist to `manager-context/triage-rules.md`. The triage-messages and priority-planner skills must read and apply these rules.

---

## Phase 6: Review Calendar

```
When are your review cycles?

Common patterns:
- Winter & Summer: Full bi-annual reviews (Impact + Growth ratings)
- Spring & Fall: Lighter check-ins

For your team:
1. When is the next review cycle?
2. When are calibration sessions?
3. Any promotion nomination windows coming up?
4. Do you track goals per quarter or per half?
```

Persist to `manager-context/review-calendar.md`.

---

## Phase 7: Skill Preferences

```
A couple more things:

**1:1 style:** Structured (always cover goals, wins, blockers) or free-flow?
Topics you always want included? Share prep with the report beforehand?

**Suggested skill rhythm:**
- Daily: /triage-messages (morning), /plan-priorities (after triage)
- Day before 1:1s: /prep-one-on-one [name]
- Before meetings: /prep-meeting (as needed)
- Weekly or biweekly: /check-team-health
- Before review cycles: /prep-performance

Does this rhythm work?
```

Persist to `manager-context/skill-preferences.md`.

---

## Phase 8: Staleness Check

Flag anything stale:
```
Staleness alerts:

- [Name]'s goals were last updated 4 months ago — still current?
- The "Q4 OKRs" page hasn't been edited since November — have new OKRs been set?
- [Name] hasn't been active in #[channel] for 3 weeks — still on the project?
- Your 1:1 with [Name] was cancelled 3 times in a row — intentional?
```

Ask the manager to confirm or update each flagged item.

---

## Phase 9: Persist & Wrap Up

Save all validated context. Read `references/context-templates.md` for file templates.

Present summary:
```
Setup complete! Here's what I know:

- [N] direct reports profiled
- Goals tracked for [N/M] team members ([list gaps])
- [N] internal terms decoded
- [N] recurring meetings mapped
- [N] data source locations saved
- Your OKRs and upward context captured
- Triage rules: [N] VIPs, [N] hot channels, [N] deprioritised
- Review calendar: next cycle [date]
- Output style: [language], [format], [folder structure]
- Skill rhythm configured
- Values: [N values configured / skipped]

Missing connectors: [list any]
Data gaps to fill later: [list any]

You're ready to go! Try:
- /triage-messages to catch up on what needs attention
- /plan-priorities to plan your day
- /prep-one-on-one [name] before your next 1:1
- /prep-meeting for your next meeting
```
