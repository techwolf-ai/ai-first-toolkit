# People Manager

AI-augmented management tooling for people managers.

## Philosophy

**Augment, never automate.** This plugin surfaces context so managers can make better decisions — it never acts on their behalf. Every output is a draft for human review. Management is about human judgment, trust, and relationships. AI provides leverage on information-gathering so managers spend more energy on the human side.

## Skills

| Skill | What it does |
|-------|--------------|
| **Setup** | Interactive onboarding (9 phases): discovers team, terminology, goals, values, ways of working. Configures output preferences, triage rules, review calendar, and skill rhythm. Run this first. |
| **Meeting Prep** | Gathers all relevant context before any meeting — attendees, topics, previous notes, action items |
| **Triage Messages** | Batch-processes Slack and email, categorises by urgency using your custom triage rules (VIPs, hot channels) |
| **1:1 Prep** | Deep-dive preparation for 1:1s with direct reports, anchored in the performance framework (Impact + Growth) |
| **Customer Status** | Synthesised view of account health and activity for customer-facing teams |
| **Priority Planner** | Identifies highest-leverage actions for the day/week with goal alignment reflection — maps activities against OKRs, surfaces drift |
| **Team Health** | Periodic check through two lenses: development (growth, goals, performance) and wellbeing (energy, connection, celebration) |
| **Performance Cycle** | Evidence gathering for bi-annual review cycles, organised along Impact and Growth dimensions |

## Setup Flow

1. Install the plugin
2. Connect required MCP sources
3. Run `/setup` to begin interactive onboarding

Setup covers 9 phases:
1. **Team discovery** — team structure, terminology, goals, ways of working, customers
2. **Organizational values** — your org's core values and what signals to look for
3. **Output preferences** — language, tone, file format, folder structure, naming
4. **Manager's own context** — your OKRs, who you report to, upward priorities
5. **Triage rules** — VIP people, hot channels, deprioritise list, privacy boundaries
6. **Review calendar** — cycle dates, calibration, promotion windows
7. **Skill preferences** — 1:1 style, suggested rhythm for all skills
8. **Staleness check** — flags stale data for validation
9. **Persist & wrap up** — saves all context, summary, suggested first skills

## Required Connectors

- **Slack** — message search, channel reading, user profiles
- **Notion** — performance docs, goals, OKRs, team pages
- **Google Drive** — meeting notes, 1:1 docs, strategy docs
- **Gmail** — email context and triage
- **Google Calendar** — upcoming meetings, attendee lists

## Grounded In

- **Your organization's values** — configured during setup, used as a lens across 1:1 prep, team health, and performance reviews
- **Management framework** (Deliver Excellence + Develop People)
- **Performance framework** (Impact + Growth, ratings, promotion readiness)
- **AI-first design principles**
