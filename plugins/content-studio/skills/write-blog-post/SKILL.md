---
name: write-blog-post
description: Write or develop a blog post. Use for blog content - writing, drafting, developing ideas into drafts, or editing. Longer-form than LinkedIn (800-1200 words) with section structure.
---

# Write Blog Post

You are helping write a blog post for the author.

## Before Writing (MANDATORY)

**You MUST complete these steps before writing ANY content:**

1. Run `./scripts/print-published.sh linkedin-post` to read ALL published LinkedIn posts
   - Blog posts share the same voice as LinkedIn posts, so these are your primary style reference
   - Note core insights and data points already used
   - Identify opportunities to reference or build on previous posts
2. Run `./scripts/print-published.sh blog-post` to read ALL published blog posts
   - Avoid repeating topics, angles, or arguments already covered
   - Note the structure and depth of existing blog posts
3. Read `guidelines/linkedin.md` for style rules (same voice applies to blog posts)
4. Read `references/professional-profile.md` for background

**If developing an idea-stage post:** Check if the idea's core insight overlaps with published posts (LinkedIn or blog). If so, either:
- Find a genuinely different angle
- Explicitly build on the previous piece
- Recommend against developing the idea

## Avoid Repetitive Patterns

When reading recent posts, actively note and vary:

**Openings:** Vary between demand signal, personal anecdote, company experience, surprising data
**Section flow:** Don't always follow the same arc (problem-solution-data-close)
**Closing lines:** Find fresh ways to land the argument
**Examples:** Rotate between company-specific, industry, and broader examples
**Rhetorical devices:** If recent pieces use lists heavily, try flowing narrative, and vice versa

The goal is a consistent voice with varied execution.

## Style Requirements

- **800-1200 words** (use `wc -w` to verify)
- **English language**
- **Section headings** (## level) to break up the piece into 5-7 sections
- **First person** throughout
- **Conversational tone** - read it aloud, does it sound like something you'd say?
- **Specific > abstract** - lead with concrete examples, generalize later
- **No hype words** ("revolutionary", "game-changing", "transformative")
- **Strong opening** - first 2-3 sentences must hook the reader with something concrete

## Structure

Blog posts are longer than LinkedIn posts and need more structure. A typical blog post has:

1. **Hook** (80-100 words) - Concrete opening that pulls the reader in
2. **3-5 body sections** (150-200 words each) - Each with a clear heading and one main point
3. **Close** (50-75 words) - Echo the opening or land the core argument

Each section should earn its place. If a section doesn't add something the reader couldn't get from the LinkedIn post on the same topic, cut it.

## Relationship to LinkedIn Posts

Blog posts often expand on ideas first introduced in LinkedIn posts. When this happens:
- Reference the LinkedIn post briefly, don't re-explain it
- Go deeper on the angle the LinkedIn post couldn't cover in 200 words
- Add the meta-story, the data, or the "why" behind the insight
- Blog posts should reward readers who already saw the LinkedIn post AND stand alone for those who didn't

## Process

1. If given a topic, develop it into a full draft
2. If given an existing idea file (search with `./scripts/search-posts.sh`), develop the content
3. Always check word count against 800-1200 target
4. Save to content/posts/blog-post/ with type: blog-post, stage: 02-drafts

## Creating New Files

Get timestamp first:
```bash
date -u +"%Y%m%d-%H%M%S"  # For slug
date -u +"%Y-%m-%dT%H:%M:%S.000Z"  # For created/lastUpdated
```

File path: `content/posts/blog-post/{slug}-{slugified-title}.yaml`
