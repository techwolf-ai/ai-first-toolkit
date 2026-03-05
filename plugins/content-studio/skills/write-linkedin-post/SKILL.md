---
name: write-linkedin-post
description: Write or develop a LinkedIn post. Use ALWAYS for LinkedIn content - writing, drafting, developing ideas into drafts, or editing.
---

# Write LinkedIn Post

You are helping write a LinkedIn post for the author.

## Before Writing (MANDATORY)

**You MUST complete these steps before writing ANY content:**

1. Run `./scripts/print-published.sh linkedin-post` to read ALL published posts in one call
   - This is critical to avoid repeating topics or angles already covered
   - Note the core insights and data points already used
   - Identify opportunities to reference or build on previous posts
   - **Pay attention to recent patterns** (last 5-10 posts) to avoid repetitive structures, hooks, or phrases
2. Read `guidelines/linkedin.md` for style rules
3. Read `references/professional-profile.md` for background

**If developing an idea-stage post:** Check if the idea's core insight or data points overlap with published posts. If so, either:
- Find a genuinely different angle
- Explicitly build on the previous post ("In my last post I discussed X. Here's the flip side...")
- Recommend against developing the idea

## Avoid Repetitive Patterns

When reading recent posts, actively note and vary:

**Hooks:** If recent posts start with similar patterns, try a different structure
**Sentence patterns:** Vary rhythm - don't always use short punchy sentences or always use longer flowing ones
**Closing lines:** Don't repeat formulas
**Transition phrases:** Rotate between "Here's what...", "The pattern...", "This matters because...", etc.
**Structure:** If recent posts all use problem-solution-takeaway, try a different arc

The goal is a consistent voice with varied execution. Each post should feel fresh while still sounding like the author.

## Style Requirements

- Target word count per `guidelines/linkedin.md` (typically 150-250 words)
- Personal hook first (under 210 characters before "see more")
- Specific > abstract
- Conversational tone
- No hype words ("revolutionary", "game-changing")

## Hook Priority

1. Personal anecdote
2. Company experience
3. Surprising outcome
4. Counterintuitive framing

## Process

1. If given a topic, develop it into a draft
2. If given an existing idea file (search with `./scripts/search-posts.sh`), develop the content
3. Always check word count against target
4. Save to content/posts/ with type: linkedin-post, stage: 02-drafts

## Creating New Files

Get timestamp first:
```bash
date -u +"%Y%m%d-%H%M%S"  # For slug
date -u +"%Y-%m-%dT%H:%M:%S.000Z"  # For created/lastUpdated
```
