# Discovery Phases: Detailed Instructions

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
- Recurring 1:1 meetings (attendees are likely direct reports)
- Team syncs, standups, regular meetings

**Gmail:**
- Frequent email correspondents within the company

For each person, gather: full name, Slack handle, role/title, how they were discovered.

### 1.3 Validate Team

Present findings. If connectors were available, show how each person was discovered. If connectors were unavailable, ask the manager to provide the team list directly.

For each team member, also ask for their **Slack handle**, which is needed for searching messages and mapping activity later.

```
I found these people who appear to be your direct reports:

1. [Name], @[slack-handle], [role], found via [1:1 calendar + Slack #team-channel]
2. [Name], @[slack-handle], [role], found via [Slack DMs + Notion team page]
3. [Name], @[slack-handle], [role], found via [Slack channel only, unsure if direct report]

Are these correct? Anyone missing? Anyone who shouldn't be on this list?
For anyone I'm missing a Slack handle, what is it?
```

If connectors were unavailable, use this format instead:
```
Since I couldn't crawl your tools, I'll need you to provide your team list:

For each direct report, please share:
- Full name
- Slack handle (e.g., @alex-rivera)
- Role/title
- What they're currently working on

Also, what's your own Slack handle?
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
✅ [Name]: Found goals in Notion, 1:1 doc in Drive, last review [date]
⚠️ [Name]: Found 1:1 doc but NO goals. Where do you track these?
❌ [Name]: Couldn't find any performance data. Where should I look?
```

If goals are missing, explicitly ask where they're documented.

**If connectors are unavailable**, ask the manager directly:
```
I couldn't search your tools, so I need a few things to make the skills useful:

1. **Where do you keep 1:1 notes?** (Google Docs, Notion, somewhere else?)
2. **Where are goals tracked?** (Notion OKR page, spreadsheet, goal-setting tool?)
3. **Where are performance reviews stored?** (Notion, Google Drive folder, HR tool?)
4. **For each team member, do you know their current development areas or goals?**
   - [Name]: [goals / development focus / "will gather in 1:1"]

Even rough answers help. I'll fill in the details when connectors become available.
```

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

### 1.7 Channels & Project Context

Map team members to their primary Slack channels. This is used by triage, team health, and 1:1 prep to know where to look for each person's activity.

**If connectors are available:**

**Slack:** Identify project/customer channels (#proj-*, #customer-*, #account-*, #team-*). Map team members to channels based on membership and activity.

**If connectors are unavailable**, ask:
```
Which Slack channels is each team member most active in?

| Team member | Primary channels |
|-------------|-----------------|
| [Name] | #[channel], #[channel] |

Also, are there any project or customer channels I should monitor?
```

For customer-facing teams, also discover:

**Notion:** Project pages, customer status docs, delivery trackers.

Present:
```
Active accounts/projects:
- [Customer]: [team member] is primary, channel: #proj-[name]
- [Project]: Internal, [team member] is leading

Any accounts I'm missing?
```

---

## Phase 2: Performance & Management Frameworks

Discover how the org evaluates individual performance and management effectiveness. This is critical. The performance framework shapes how 1:1 prep, team health, and performance cycle skills organise their output.

### 2.1 Crawl for Existing Framework Docs

Before asking the manager, search for existing documentation:

**Notion:** Search for pages matching: "performance framework", "performance review", "review process", "career framework", "career ladder", "leveling", "competency", "rating", "promotion", "management competencies", "people manager expectations".

**Google Drive:** Search for docs matching: "performance review template", "review guide", "career framework", "leveling guide", "management expectations".

**Slack:** Search for recent messages mentioning: "review cycle", "calibration", "promotion", "performance review", as these often link to framework docs.

For each document found, extract:
- Framework dimension names and descriptions
- Rating scale labels and descriptions
- Promotion readiness labels (if any)
- Review cadence and timeline
- Management-specific competencies or expectations

### 2.2 Present Findings & Fill Gaps

If framework docs were found, present what was extracted:
```
I found your org's performance framework! Here's what I extracted:

**Performance dimensions:**
1. [Dimension name]: [description, sub-dimensions]
2. [Dimension name]: [description, sub-dimensions]

**Rating scale:** [extracted labels]
**Promotion tracking:** [extracted labels / not found]
**Review cadence:** [extracted timeline]

Is this accurate? Anything missing or outdated?
```

If NO framework docs were found, walk through building it:
```
I couldn't find a documented performance framework. Let's set one up. I'll ask a few questions and you can tell me what your org uses. If you're unsure on anything, I have sensible defaults.

**1. How does your org evaluate performance?**
Most orgs use 2-3 dimensions. Common patterns:
- **Results + Growth:** what someone delivered AND how they're developing
- **What + How:** outcomes AND behaviours/values
- **Single dimension:** just overall performance rating

What dimensions does your org use? (If unsure, I'll use "Impact" and "Growth" as defaults, you can change these anytime.)
```

Wait for the manager's answer. Then continue:

```
**2. Rating scale:** how are people rated in reviews?
Common patterns:
- Descriptive labels (e.g., "Exceeds Expectations / Meets / Below")
- Numbered scale (e.g., 1-5)
- Custom labels (e.g., "Outstanding / Strong / Developing")
- No formal ratings

What does your org use?
```

```
**3. Promotion readiness:** does your org track this separately?
Common patterns:
- Labels like "Ready Now / Ready Soon / Not Yet"
- Integrated into the rating (e.g., top rating = promotion-ready)
- Not formally tracked

What does your org use? (Fine to skip if not applicable.)
```

```
**4. Review cadence:** when do formal reviews happen?
- Annual (once a year)
- Bi-annual (twice a year, e.g., summer + winter)
- Quarterly
- Something else?

And are there lighter check-ins between full reviews?
```

```
**5. Goal cadence:** how often are goals set and reviewed?
- Quarterly (OKRs or similar)
- Half-yearly
- Annually
- Continuous / no fixed cadence
```

For each answer, confirm understanding and note any sub-dimensions or nuances the manager mentions.

### 2.3 Management Framework

If management-specific docs were found in 2.1, present them. Otherwise:

```
**6. Management expectations:** does your org have a formal model for what makes a good manager?

Common patterns:
- **Two-dimensional:** driving results AND developing people
- **Competency model:** specific skills like delegation, communication, hiring, coaching
- **No formal model:** that's fine, we'll use sensible defaults (Results + People)

What does your org expect from managers? Are managers evaluated separately or on the same framework as ICs?
```

If the manager describes specific competencies, capture each one with a brief description.

### 2.4 Validate & Persist

Present the complete framework for confirmation:
```
Here's your complete framework configuration:

**Performance Framework:**
- Dimensions: [list with sub-dimensions]
- Rating scale: [labels]
- Promotion tracking: [labels / not tracked]
- Review cadence: [cadence with dates if known]
- Goal cadence: [cadence]

**Management Framework:**
- Dimensions: [list with competencies]
- How managers are evaluated: [separate track / same as ICs / informal]

These will shape how 1:1 prep, team health, and performance cycle skills organise their output. Anything to adjust?
```

Wait for confirmation. Then persist to `manager-context/performance-framework.md` and `manager-context/management-framework.md`. Read `references/context-templates.md` for file templates.

---

## Phase 3: Organizational Values

Values tell skills *how* results should be delivered. They provide conversation threads beyond goals and deliverables, especially valuable in 1:1 prep, team health, and performance reviews.

### 3.1 Crawl for Values Documentation

Search for existing values documentation before asking:

**Notion:** Search for pages matching: "values", "core values", "company values", "culture", "handbook", "how we work", "principles".

**Google Drive:** Search for docs matching: "values", "culture deck", "handbook", "ways of working".

**Slack:** Search for pinned messages or channels like #values, #culture, #handbook that may link to values docs.

### 3.2 Present Findings or Ask

If values docs were found, extract value names, descriptions, and any associated behaviours:
```
I found your org's values! Here's what I extracted:

1. **[Value Name]:** [description from doc]
2. **[Value Name]:** [description from doc]
3. **[Value Name]:** [description from doc]

Is this the current list? Any that are missing or outdated?
```

If NO values docs were found:
```
I couldn't find documented company values. Does your organization have defined core values?

If yes:
1. What are they? (just list the names, I'll help flesh them out)
2. Where are they documented? (Notion page, handbook, website, etc.)

If no, that's fine. We can skip the values lens in skills, or you can define informal team values. You can always add values later by running /setup --refresh.
```

### 3.3 Define Signals Per Value

For each value, help the manager define what to look for. This is the key step. Generic value names are useless without signals.

For each value, ask:
```
Let's make "[Value Name]" actionable for the skills. For each question, give me examples or say "skip" if unsure:

1. **What does this value look like in Slack?**
   (e.g., for a "Collaboration" value: helping others in channels, cross-team threads, sharing context proactively)

2. **What does it look like in work output?**
   (e.g., for a "Quality" value: iteration on docs, peer feedback, attention to detail)

3. **How is it used in performance reviews?**
   (e.g., "we ask for examples of each value" or "it's part of the 'How' rating")

4. **What's hard to see digitally?**
   (e.g., empathy in person, trust-building, tone of voice, these I'll flag for your own observation)
```

If the manager has many values (5+), offer to batch:
```
You have [N] values. Want me to go through each one, or would you rather give me a quick summary of what signals matter most and I'll fill in the rest?
```

### 3.4 Validate & Persist

Present the complete values configuration:
```
Here's your values configuration:

| Value | Description | Signals to look for | Hard to see digitally |
|-------|-------------|--------------------|-----------------------|
| [name] | [description] | [signals] | [what needs manager's own observation] |

These will be used as a lens in 1:1 prep, team health, and performance reviews.
Any values I should weigh more heavily? Any to skip in certain skills?
```

Persist to `manager-context/values.md`. Read `references/context-templates.md` for the template. See `../../references/values-guide.md` for how skills use values.

---

## Phase 4: Output Preferences

Present defaults and let the manager adjust:
```
How should I produce and save outputs? Defaults (adjust anything):

**Style:** English, professional/concise, moderate detail, emoji for visual scanning
**File format:** Markdown (.md)
**Filename:** YYYY-MM-DD-<skill>-<subject>.md
**Folders:** outputs/ with subdirectories per skill type

Options: language, shorter/longer, .docx/.html, flat/weekly folders, different naming
```

Persist to `manager-context/output-preferences.md`. All other skills must read this before saving output.

---

## Phase 5: Manager's Own Context

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

## Phase 6: Triage Rules

```
Let's set up your triage rules:

1. **VIP people:** whose messages always bubble to the top?
2. **Hot channels or topics:** channels/keywords that always mean urgent?
3. **Deprioritise:** anything to push to the bottom?
4. **Privacy boundaries:** channels, people, or topics to skip entirely?
```

Persist to `manager-context/triage-rules.md`. The triage-messages and priority-planner skills must read and apply these rules.

---

## Phase 7: Review Calendar

```
When are your review cycles?

Common patterns:
- Bi-annual: full reviews twice a year with lighter check-ins in between
- Annual: one big review per year
- Quarterly: lighter but more frequent

For your team:
1. When is the next review cycle?
2. When are calibration sessions?
3. Any promotion nomination windows coming up?
4. Do you track goals per quarter or per half?
```

Persist to `manager-context/review-calendar.md`.

---

## Phase 8: Skill Preferences

```
A couple more things:

**1:1 style:** Structured (always cover goals, wins, blockers) or free-flow?
Topics you always want included? Share prep with the report beforehand?

**Suggested skill rhythm:**
- Daily: /triage-messages (morning), /priority-planner (after triage)
- Day before 1:1s: /one-on-one-prep [name]
- Before meetings: /meeting-prep (as needed)
- Weekly or biweekly: /team-health
- Before review cycles: /performance-cycle

Does this rhythm work?
```

Persist to `manager-context/skill-preferences.md`.

---

## Phase 9: Staleness Check

Flag anything stale:
```
Staleness alerts:

- [Name]'s goals were last updated 4 months ago. Still current?
- The "Q4 OKRs" page hasn't been edited since November. Have new OKRs been set?
- [Name] hasn't been active in #[channel] for 3 weeks. Still on the project?
- Your 1:1 with [Name] was cancelled 3 times in a row. Intentional?
```

Ask the manager to confirm or update each flagged item.

---

## Phase 10: Persist & Wrap Up

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
- /priority-planner to plan your day
- /one-on-one-prep [name] before your next 1:1
- /meeting-prep for your next meeting
```
