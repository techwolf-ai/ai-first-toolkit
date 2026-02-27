---
name: write-opinion
description: Write or develop a Dutch opinion piece (opiniestuk). Use when asked to write opinion articles, Dutch newspaper pieces, or similar long-form opinion content.
---

# Write Opinion Piece

You are helping write a Dutch opinion piece (opiniestuk) for the author.

## Before Writing

1. Run `./scripts/print-published.sh opinion` to read all published opinions in one call
   - Note topics, arguments, and examples already used
   - **Pay attention to recent patterns** to avoid repetitive structures, openings, or phrases
2. Read `guidelines/opinie.md` for style rules
3. Read `references/professional-profile.md` for background

## Avoid Repetitive Patterns

When reading recent pieces, actively note and vary:

**Openings:** If recent pieces start with scene-setting in a specific location, try a different concrete opening (an action, a quote, a surprising fact)
**Sentence rhythm:** Vary between punchy short sentences and longer flowing ones
**Closing formulas:** Don't repeat the same forward-looking structure - find fresh ways to land the argument
**Examples:** Rotate between local and international examples; between industry, government, and everyday life
**Rhetorical devices:** If recent pieces use lists or parallel structure heavily, try a different approach

The goal is a consistent voice with varied execution. Each piece should feel fresh while still sounding like the author.

## Style Requirements

- Target ~3500 characters (use `wc -m` to verify)
- Dutch language (Nederlands)
- Open with concrete scene-setting (time, place, action)
- Strong verbs (scheert, stuwen, loodst, slaagt)
- Short punchy paragraphs (2-4 sentences)
- Double dashes (--) for emphasis
- Forward-looking, grounded close

## Process

1. Develop the angle and core argument
2. Write in Dutch following the style guide
3. Check character count against ~3500 target with `wc -m`
4. Save to content/posts/ with type: opinion, stage: 02-drafts

## Creating New Files

Get timestamp first:
```bash
date -u +"%Y%m%d-%H%M%S"  # For slug
date -u +"%Y-%m-%dT%H:%M:%S.000Z"  # For created/lastUpdated
```
