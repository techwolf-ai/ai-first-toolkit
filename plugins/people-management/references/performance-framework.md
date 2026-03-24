# Performance Framework

How your organization evaluates performance. Discovered during `/setup` and stored in `manager-context/performance-framework.md`.

If no org-specific framework is configured, skills fall back to two universal dimensions that most performance systems share.

## Default Dimensions

### Impact
How effectively someone delivers results and creates value.

| Sub-dimension | What it means |
|--------------|---------------|
| **Goal Achievement** | Did they achieve their goals? Were commitments met? |
| **Quality of Outcomes** | Was the work excellent? Did it meet high standards? |
| **Business & Team Impact** | Did it matter? Did the work move the needle? |

### Growth
How someone is developing as a professional.

| Sub-dimension | What it means |
|--------------|---------------|
| **Skill Development** | Building new technical or professional capabilities? |
| **Behavioral Growth** | Growing in how they work with others, communicate, lead? |
| **Scope Expansion** | Taking on bigger, broader, or different challenges? |

These defaults work for most organizations. During setup, the manager can replace or extend them with their org's actual framework dimensions.

## Org-Specific Configuration

During `/setup`, the plugin discovers:

- **Framework dimensions** -- what your org evaluates (may differ from the defaults above)
- **Rating scale** -- how performance is rated (e.g., 5-point scale, letter grades, descriptive labels)
- **Promotion readiness labels** -- how your org tracks promotion readiness (if applicable)
- **Review cadence** -- when reviews happen and what type (full review vs. light check-in)
- **Goal cadence** -- how often goals are set and reviewed

This is stored in `manager-context/performance-framework.md` and loaded by skills that need it (performance-cycle, one-on-one-prep, team-health).

## Evidence Gathering Guidelines

When preparing reviews, look for evidence across:
1. **Goal tracking systems** -- Notion pages, OKR docs
2. **Project deliverables** -- shipped features, completed milestones, docs produced
3. **Peer recognition** -- Slack shoutouts, feedback from collaborators
4. **Customer/stakeholder feedback** -- visible in project channels, email threads
5. **Development activities** -- courses, workshops, mentoring, scope expansion

**What digital signals CAN show:** Goal completion, project delivery, peer recognition, scope changes, activity patterns.

**What digital signals CANNOT show:** Quality of thinking, relationship building, leadership presence, judgment calls, cultural contribution. These require the manager's direct observation.
