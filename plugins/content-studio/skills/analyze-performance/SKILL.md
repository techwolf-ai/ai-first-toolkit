---
name: analyze-performance
description: Analyze engagement patterns across published posts to identify what works. Use when asked to review performance, find successful patterns, or optimize future content.
---

# Analyze Content Performance

Identify patterns in high-performing posts to inform future content strategy.

## Process

1. Run `./scripts/print-published.sh linkedin-post` to read all published LinkedIn posts
2. Extract posts that have engagement data (engagement.reactions, engagement.views, etc.)
3. Analyze patterns across high-performing vs low-performing posts

## Analysis Dimensions

### Hook Analysis
- What hook styles correlate with higher engagement?
- Personal anecdote vs company experience vs surprising data vs news hook?
- First 210 characters (LinkedIn cutoff) - what patterns work?

### Content Characteristics
- Word count vs engagement correlation
- Use of concrete examples vs abstract concepts
- Presence of frameworks or mental models
- Use of lists/structure vs flowing narrative

### Topic Analysis
- Which tags correlate with higher engagement?
- Which themes resonate most?
- Timing patterns (if publishedDate available)

### Structural Patterns
- Opening style (question, statement, story)
- Closing style (call-to-action, reflection, question)
- Paragraph length and density

## Performance Tiers

Categorize posts by reaction count:
- **High performers**: 100+ reactions
- **Medium performers**: 30-99 reactions
- **Lower performers**: <30 reactions

## Output Format

Provide:
1. **Summary statistics** - Total posts analyzed, average engagement by tier
2. **Top performers** - List highest-engagement posts with their key characteristics
3. **Pattern insights** - What distinguishes high vs lower performers?
4. **Recommendations** - Actionable suggestions for future content

## Example Analysis Output

```
## Performance Summary
- Posts analyzed: 12 (with engagement data)
- High performers (100+): 3 posts
- Medium performers (30-99): 5 posts
- Lower performers (<30): 4 posts

## Top Performers
1. "Title" - 245 reactions
   - Hook: Personal anecdote
   - Topic: AI productivity
   - Word count: 180

## Key Patterns
- Personal anecdotes in the first sentence correlate with 2x higher engagement
- Posts with concrete examples outperform abstract posts by 40%
- Optimal word count appears to be 150-200 words

## Recommendations
1. Lead with personal or company-specific openings
2. Include at least one specific example or data point
3. Keep total length under 220 words
```

## Notes

- Only analyze posts with engagement data (skip posts without metrics)
- Correlation is not causation - note patterns but don't overclaim
- Consider recency bias - newer posts may still be accumulating engagement
