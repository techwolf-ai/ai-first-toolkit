# Performance Framework

How this plugin uses your org's performance framework. The actual framework is configured during `/setup` and stored in `manager-context/performance-framework.md`.

## What Setup Configures

During `/setup` Phase 2, the plugin discovers or helps you define:

- **Framework dimensions** -- what your org evaluates (e.g., "What + How", "Impact + Growth", "Results + Behaviours", or something else entirely)
- **Sub-dimensions** -- the specific areas within each dimension
- **Rating scale** -- how performance is rated (descriptive labels, numbered scale, etc.)
- **Promotion readiness labels** -- how your org tracks promotion readiness (if applicable)
- **Review cadence** -- when reviews happen and what type
- **Goal cadence** -- how often goals are set and reviewed

If your org doesn't have a formal framework, setup provides sensible defaults you can use or adjust.

## How Skills Use the Framework

| Skill | What it loads | How it uses it |
|-------|--------------|----------------|
| Performance Cycle | Full framework (dimensions, ratings, cadence) | Organises evidence by dimension, checks coverage |
| 1:1 Prep | Dimensions and sub-dimensions | Maps development goals to framework, suggests questions |
| Team Health | Dimensions (high-level) | Checks team patterns across framework areas |
| Priority Planner | Dimensions (high-level) | Notes which framework area an action supports |

## Evidence Gathering Guidelines

When preparing reviews, skills look for evidence across:
1. **Goal tracking systems** -- Notion pages, OKR docs
2. **Project deliverables** -- shipped features, completed milestones, docs produced
3. **Peer recognition** -- Slack shoutouts, feedback from collaborators
4. **Customer/stakeholder feedback** -- visible in project channels, email threads
5. **Development activities** -- courses, workshops, mentoring, scope expansion

**What digital signals CAN show:** Goal completion, project delivery, peer recognition, scope changes, activity patterns.

**What digital signals CANNOT show:** Quality of thinking, relationship building, leadership presence, judgment calls, cultural contribution. These require the manager's direct observation.

## Evidence Patterns by Dimension Type

Skills use these heuristics to know what to search for, regardless of what your org calls its dimensions:

- **Results/delivery dimensions:** goal completion, shipped work, quality feedback, business outcomes
- **Growth/development dimensions:** learning activities, new skills applied, scope expansion, behavioural changes
- **Collaboration/leadership dimensions:** cross-team activity, mentoring, influence in discussions
- **Behavioural/values dimensions:** see `values-guide.md`
