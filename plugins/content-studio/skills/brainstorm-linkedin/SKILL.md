---
name: brainstorm-linkedin
description: Generate LinkedIn post ideas from external sources (files, URLs, research). Use when the user provides source material (PDFs, URLs, articles) to brainstorm topics. NOT for writing or developing drafts - use write-linkedin-post instead.
---

# Brainstorm LinkedIn Posts from Source Material

Generate LinkedIn post ideas based on external context provided by the user.

## Process

1. **Read ALL published posts** (MANDATORY - to avoid topic/angle overlap):
   ```bash
   ./scripts/print-published.sh linkedin-post
   ```
   This prints all published posts with full content in one call. Note:
   - Core insights already covered
   - Data points already used
   - Angles already explored

   **Do not suggest ideas that repeat existing coverage.**

2. **Read the style guide**:
   - `guidelines/linkedin.md`
   - `references/professional-profile.md`

3. **Process the provided context** (user will provide one or more of):
   - Files (PDFs, documents, research papers)
   - URLs (articles, blog posts, announcements)
   - Raw text or ideas

4. **Identify 2-4 promising angles** by considering:
   - What's the unique insight for a professional audience?
   - How does this connect to the author's expertise?
   - What's the hook that works in the first 210 characters?
   - Is there a personal angle or company connection?

5. **Present ideas** with for each:
   - Proposed title
   - Core insight (1 sentence)
   - Hook approach (personal anecdote, company experience, surprising outcome, or news)
   - Why it fits the author's voice

6. **Ask user to choose**:
   - Which idea(s) to develop
   - Whether to create as idea (01-ideas) or draft (02-drafts)

## Evaluation Criteria

Strong LinkedIn post ideas have:
- A concrete hook in the first 210 characters
- A clear insight that provides value
- Connection to the author's expertise areas
- Room for a personal or company angle
- Appropriate scope for the target word count

## Creating Files

After user selection, get timestamp:
```bash
date -u +"%Y%m%d-%H%M%S"  # For slug
date -u +"%Y-%m-%dT%H:%M:%S.000Z"  # For created/lastUpdated
```

Create file at: `content/posts/linkedin-post/{slug}-{slugified-title}.yaml`
