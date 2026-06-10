# Content File Format

## File Path

`content/posts/{type}/{slug}-{slugified-title}.yaml`

## YAML Structure

```yaml
stage: 03-published
type: linkedin-post
title: Post Title
slug: YYYYMMDD-HHMMSS
created: "YYYY-MM-DDTHH:MM:SS.000Z"
lastUpdated: "YYYY-MM-DDTHH:MM:SS.000Z"
coreInsight: One sentence summary of the key insight
tags:
  - relevant-tag
engagement:
  reactions: N
  comments: N
  reposts: N
audience: Who this post is for
keyConcepts:
  - Concept 1
images: []
content: |-
  The full post text...
```

## Notes

- Use approximate dates for slugs based on the post timing information provided
- **If your agent supports sub-agents (e.g. Claude Code), use parallel Task agents** to create posts in batches of 10 for efficiency. Otherwise (e.g. Codex), create them sequentially: same output, just slower
