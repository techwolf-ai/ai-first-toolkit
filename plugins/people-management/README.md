# People Manager

AI-augmented management tooling for people managers.

## Philosophy

**Augment, never automate.** This plugin surfaces context so managers can make better decisions. It never acts on their behalf. Every output is a draft for human review. Management is about human judgment, trust, and relationships. AI provides leverage on information-gathering so managers spend more energy on the human side.

## Skills

| Skill | What it does |
|-------|--------------|
| **Setup** | Interactive onboarding (10 phases): discovers team, frameworks, terminology, goals, values, ways of working. Configures output preferences, triage rules, review calendar, and skill rhythm. Run this first. |
| **Meeting Prep** | Gathers all relevant context before any meeting: attendees, topics, previous notes, action items |
| **Triage Messages** | Batch-processes Slack and email, categorises by urgency using your custom triage rules (VIPs, hot channels) |
| **1:1 Prep** | Deep-dive preparation for 1:1s with direct reports, anchored in your org's performance framework |
| **Customer Status** | Synthesised view of account health and activity for customer-facing teams |
| **Priority Planner** | Identifies highest-leverage actions for the day/week with goal alignment reflection. Maps activities against OKRs, surfaces drift |
| **Team Health** | Periodic check through two lenses: development (growth, goals, performance) and wellbeing (energy, connection, celebration) |
| **Performance Cycle** | Evidence gathering for review cycles, organised along your org's performance framework dimensions |

## Setup Flow

1. Install the plugin
2. Connect required MCP sources
3. Run `/setup` to begin interactive onboarding

Setup covers 10 phases:
1. **Team discovery**: team structure, terminology, goals, ways of working, customers
2. **Performance & management frameworks**: your org's performance dimensions, rating scale, management competencies
3. **Organizational values**: your org's core values and what signals to look for
4. **Output preferences**: language, tone, file format, folder structure, naming
5. **Manager's own context**: your OKRs, who you report to, upward priorities
6. **Triage rules**: VIP people, hot channels, deprioritise list, privacy boundaries
7. **Review calendar**: cycle dates, calibration, promotion windows
8. **Skill preferences**: 1:1 style, suggested rhythm for all skills
9. **Staleness check**: flags stale data for validation
10. **Persist & wrap up**: saves all context, summary, suggested first skills

## Required Connectors

- **Slack**: message search, channel reading, user profiles
- **Notion**: performance docs, goals, OKRs, team pages
- **Google Drive**: meeting notes, 1:1 docs, strategy docs
- **Gmail**: email context and triage
- **Google Calendar**: upcoming meetings, attendee lists

## Grounded In

- **Your organization's frameworks**: performance and management frameworks configured during setup, with sensible defaults if your org doesn't have formal ones
- **Your organization's values**: configured during setup, used as a lens across 1:1 prep, team health, and performance reviews
- **AI-first design principles**: narrow scope, human-in-the-loop, progressive disclosure
