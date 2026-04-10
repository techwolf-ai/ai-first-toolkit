---
name: setup
description: "Interactive onboarding that discovers team structure, terminology, development goals, performance and management frameworks, organizational values, and ways of working by crawling Slack, Notion, Google Drive, Gmail, and Calendar. Validates everything with the manager before persisting. Run this first before using any other skill. Also handles periodic context refreshes via /setup --refresh."
---

# Setup

> **Principle: "You are responsible."** This skill discovers and proposes. The manager validates and decides what's accurate.

Interactive onboarding that builds the foundation every other skill relies on. Crawls connected sources, extracts context, and validates with the manager before saving.

If any MCP connector is unavailable, follow the connector unavailability protocol in `../../references/operating-principles.md`.

## Prerequisites

Ensure these MCP connectors are available:
- **Slack**: team channels, messages, terminology
- **Notion**: performance docs, goals, team pages
- **Google Drive**: 1:1 docs, meeting notes, strategy docs
- **Gmail**: communication patterns
- **Google Calendar**: recurring meetings, team rhythms

If any connector is missing, note it and proceed with what's available. Flag gaps at the end.

## Instructions

Run phases sequentially. Each phase discovers, validates with the manager, then persists. Read `references/discovery-phases.md` for detailed instructions per phase.

### Phase 1: Team Discovery
Identify the manager (name, role, teams), crawl sources for direct reports, validate the team list, discover internal terminology, find development goals and performance data, map ways of working, and identify customer/project context if applicable.

Persist: `manager-context/manager-profile.md`, `manager-context/team/[name].md` per report, `manager-context/terminology.md`, `manager-context/sources.md`

### Phase 2: Performance & Management Frameworks
Discover how the org evaluates performance and managers. Search for existing framework docs, then walk the manager through defining their dimensions, rating scale, promotion readiness labels, review cadence, goal cadence, and management competencies. See `../../references/performance-framework.md` and `../../references/management-framework.md` for how skills use these frameworks.

Persist: `manager-context/performance-framework.md`, `manager-context/management-framework.md`

### Phase 3: Organizational Values
Ask if the org has defined values. If yes, search for documentation, extract value names and behaviours, ask what signals to look for per value. If no, skip the values lens.

Persist: `manager-context/values.md`

### Phase 4: Output Preferences
Present defaults (language, tone, file format, folder structure) and let the manager adjust.

Persist: `manager-context/output-preferences.md`

### Phase 5: Manager's Own Context
Capture upward context: OKRs, who they report to, key deadlines.

Persist: `manager-context/manager-goals.md`

### Phase 6: Triage Rules
Capture VIP people, hot channels, deprioritise list, privacy boundaries.

Persist: `manager-context/triage-rules.md`

### Phase 7: Review Calendar
Capture review cycle dates, calibration sessions, promotion windows, goal cadence.

Persist: `manager-context/review-calendar.md`

### Phase 8: Skill Preferences
Capture 1:1 style and suggest a skill rhythm (daily triage, weekly health check, etc.).

Persist: `manager-context/skill-preferences.md`

### Phase 9: Staleness Check
Flag any discovered data older than ~2 months. Ask the manager to confirm or update.

### Phase 10: Persist & Wrap Up
Save all validated context. Read `references/context-templates.md` for file templates. Present a summary of what was captured, flag gaps, and suggest first skills to try.

## Refresh Mode

When called with `--refresh`:
1. Read existing `manager-context/` files
2. Re-crawl sources for changes since last update
3. Present only what's changed (new team members, updated goals, new terminology, stale data)
4. Update files with confirmed changes
5. Don't re-ask about things already validated

## Important Notes

Read `../../references/operating-principles.md` for shared principles (data scope, DM flagging, connector unavailability).

- **Never assume, always validate.** If something looks like a team member but you're not sure, ask.
- **Flag gaps explicitly.** "I couldn't find X" is more useful than silently skipping it.
- **Stale data is worse than no data.** Always check recency and flag anything older than ~2 months.
