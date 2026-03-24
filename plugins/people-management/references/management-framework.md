# Management Framework

How your organization evaluates and develops managers. Discovered during `/setup` and stored in `manager-context/management-framework.md`.

If no org-specific framework is configured, skills fall back to two universal management dimensions.

## Default Dimensions

### Results
How the manager drives outcomes through their team.

- **Delegation** -- sets clear expectations, delegates appropriately, protects focus time
- **Execution** -- removes blockers, drives accountability, manages dependencies
- **Communication** -- keeps stakeholders informed, creates clarity, manages upward

### People
How the manager grows and retains their team.

- **Development & Engagement** -- invests in growth, creates psychological safety, builds belonging
- **Performance Management** -- gives timely feedback, has honest conversations, manages underperformance
- **Hiring** -- maintains a strong bar, builds diverse teams, invests in onboarding

These defaults work for most organizations. During setup, the manager can replace or extend them with their org's actual management competencies.

## Org-Specific Configuration

During `/setup`, the plugin discovers:
- **Management competency model** -- what your org expects from managers
- **How managers are evaluated** -- separate track, same framework as ICs, or informal
- **Level expectations** -- if management levels exist with different expectations

This is stored in `manager-context/management-framework.md` and loaded by skills that reference management dimensions.

## How Skills Map to Management Dimensions

Skills naturally support different management areas. When an org-specific framework is configured, this mapping is updated to use the org's dimension names.

| Skill | Default mapping |
|-------|----------------|
| Triage Messages | Results -- Communication |
| Meeting Prep | Results -- Execution |
| Priority Planner | Results -- Execution + People |
| 1:1 Prep | People -- Development |
| Team Health | People -- Development & Engagement |
| Performance Cycle | People -- Performance Management |
| Customer Status | Results -- Execution |
