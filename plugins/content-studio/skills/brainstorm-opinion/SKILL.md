---
name: brainstorm-opinion
description: Generate opinion piece ideas from recent LinkedIn posts (last 30 days). Use when asked to find opinion topics, brainstorm article ideas, or cross-pollinate content between LinkedIn and opinion pieces.
---

# Brainstorm Opinion from Recent Posts

Generate opinion piece ideas based on LinkedIn posts from the last month.

## Process

1. Run `./scripts/print-published.sh linkedin-post` to read all published LinkedIn posts
2. Identify recent posts (check created/lastUpdated dates) with themes that have broader appeal
3. For promising topics, consider:
   - What angle would work for a newspaper audience?
   - What's the broader societal implication?
   - What contrarian or nuanced take could be developed?
   - How can this be expanded to ~3500 characters?

## Evaluation Criteria

Good candidates for opinion pieces:
- Topics with societal impact beyond tech professionals
- Ideas that can be grounded in local context
- Themes where personal experience adds credibility
- Subjects with room for a stronger point of view

## Output

Create 1-3 idea files in content/posts/ with:
- stage: 01-ideas
- type: opinion
- Reference to inspiring LinkedIn post in content field
- Core insight adapted for newspaper audience

## Creating New Files

Get timestamp first:
```bash
date -u +"%Y%m%d-%H%M%S"  # For slug
date -u +"%Y-%m-%dT%H:%M:%S.000Z"  # For created/lastUpdated
```
