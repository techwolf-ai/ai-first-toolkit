---
name: setup-content-studio
description: Set up a new content studio for a person. Copies the plugin template, adapts it to the person's voice, themes, and content types through interactive discovery. Use when asked to create a content studio for someone new.
---

# Set Up Content Studio for a New Person

You are helping set up a thought leadership content studio for a new person, using the content-studio plugin as the template.

## Overview

This is an interactive, multi-step process:
1. Gather information about the person
2. Research them online
3. Ask clarifying questions about content preferences
4. Create and configure the new repo
5. Populate with their existing content
6. Push to remote

## Step 1: Gather Basic Information

Ask the user for:
- **Person's full name**
- **Git repo URL** for the new content studio (or ask where to create it)
- **LinkedIn profile URL** (if available)
- **Their professional context** (role, company, industry)

## Step 2: Collect Example Posts

Ask the user to provide example content. This is critical for voice/style analysis:

> "Please share 15-30 example posts from this person. You can provide them as:
> - A text dump of their LinkedIn posts (with engagement numbers if available)
> - URLs to their LinkedIn posts
> - A document with collected posts
>
> The more examples, the better I can capture their voice. Include engagement metrics (reactions, comments, reposts) if you have them - this helps identify what resonates with their audience."

**Do not proceed until you have at least 10 substantive example posts.** Shares/reposts with minimal commentary don't count.

## Step 3: Research the Person Online

Use WebSearch to find:
- Their professional background and bio (company website, conference bios)
- Education and career history
- Speaking engagements, podcasts, publications
- Areas of expertise and thought leadership topics
- Any published articles or blog posts

Combine the online research with what you learn from their example posts.

## Step 4: Analyze Their Voice and Style

From the example posts, systematically identify:

### Writing Style
- **Typical post length** (word count range of their posts)
- **Tone** (analytical? conversational? provocative? reflective? inspirational?)
- **Structure patterns** (numbered lists? flowing narrative? question-driven? data-first?)
- **Hook strategies** (how do they start posts? questions? anecdotes? data? quotes?)
- **Closing patterns** (reflection? call-to-action? question? forward-looking?)
- **Distinctive phrases or verbal tics**
- **Use of emojis, special characters, formatting**
- **Paragraph length and rhythm**

### Content Themes
- **Identify 4-7 recurring themes** that form their content backbone
- For each theme, note:
  - The core idea
  - Example angles they've used
  - How it connects to their professional role

### Engagement Patterns
- Which posts got the most engagement and why?
- What hook styles correlate with higher performance?
- What topics resonate most with their audience?

## Step 5: Ask Clarifying Questions

Based on your analysis, ask the user questions to fill gaps. Use the AskUserQuestion tool with relevant options. Key questions to consider:

### Content Types
If not clear from examples, ask:
> "What types of content should the studio support?"
> Options: LinkedIn posts only / LinkedIn + blog posts / LinkedIn + blog + opinion pieces / Other

### Languages
If not clear from examples:
> "What language(s) should the content be in?"
> Options: English only / English + Dutch / English + [other] / Multiple

### Target Length
If the examples show a consistent pattern, confirm it. If not, ask:
> "Their posts range from X to Y words. What's the ideal target range?"

### Publication Outlets
> "Besides LinkedIn, where does this person publish?"
> (Blog, newspaper columns, industry publications, etc.)

**Only ask questions where the answer isn't already clear from the example posts and research.** Don't ask about things you can confidently infer.

## Step 6: Create the New Repository

### 6a. Set Up from Plugin Template

The content-studio plugin provides the generic structure. Copy it to a new repo:

```bash
# Create new repo directory
mkdir <new-repo-directory>
cd <new-repo-directory>
git init

# Copy the content-studio app (generic, no modification needed)
cp -r <plugin-path>/content-studio .

# Copy utility scripts (generic)
cp -r <plugin-path>/scripts .

# Create content directories
mkdir -p content/posts content/images

# Copy hooks
mkdir -p .claude/hooks
cp <plugin-path>/hooks/ensure-content-studio.sh .claude/hooks/
```

### 6b. Create Personalized Files from Templates

Use the templates in the plugin's `templates/` directory as starting points:

1. **`CLAUDE.md`** — Adapt from `templates/CLAUDE.md`:
   - Replace `{{AUTHOR_NAME}}` with the person's name
   - Set content types to match what was decided
   - Update key concepts to match identified themes
   - Update skill commands available
   - Remove any content types not needed

2. **`references/professional-profile.md`** — Create from `templates/references/professional-profile.md`:
   - Current role and company
   - Education and background
   - Key achievements
   - Areas of expertise
   - Thought leadership platforms
   - Key topics
   - Personal philosophy (from their posts)

3. **`guidelines/linkedin.md`** — Adapt from `templates/guidelines/linkedin.md`:
   - Core voice & positioning (their focus area, tone, authority)
   - Key concepts (their 4-7 recurring themes with example angles)
   - Style essentials (what works for them, what to avoid)
   - Length guidelines (based on their actual post lengths)
   - Hook strategies (based on their actual high-performing hooks)

4. **Additional style guides** if needed (e.g., `guidelines/opinie.md` for Dutch opinion pieces)

### 6c. Create Skills

Create skills in `.claude/skills/` for each content type. At minimum:
- `write-linkedin-post/SKILL.md` — Always include this
- `brainstorm-linkedin/skill.md` — Always include this
- `analyze-performance/SKILL.md` — Always include this

Add if relevant:
- `write-blog-post/SKILL.md` — If blog posts are a content type
- `write-opinion/SKILL.md` — If opinion pieces are a content type
- `brainstorm-opinion/SKILL.md` — If opinion pieces cross-pollinate from LinkedIn

Each skill must reference the new person's name, their style guide, and their professional profile.

### 6d. Set Up Hooks and Settings

Create `.claude/settings.json`:
```json
{
  "hooks": {
    "SessionStart": [
      {
        "type": "command",
        "command": "bash .claude/hooks/ensure-content-studio.sh"
      }
    ]
  }
}
```

## Step 7: Populate with Published Content

Convert each example post into a YAML file at `content/posts/{type}/{slug}-{slugified-title}.yaml`.

Use approximate dates for slugs based on the post timing information provided.

Each file should include:
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

**Use parallel Task agents** to create posts in batches of 10 for efficiency.

## Step 8: Install Dependencies and Verify

```bash
cd content-studio
npm install
```

Test the scripts work:
```bash
./scripts/search-posts.sh "keyword"
./scripts/list-published.sh linkedin-post
```

## Step 9: Commit and Push

```bash
git add .
git commit -m "Set up content studio for [Person Name]

Adapted from content-studio plugin with:
- Professional profile and writing guidelines for [Name]'s voice
- [N] published LinkedIn posts with full text and engagement metrics
- Skills for [list skills]
- Content types: [list types]

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"

git push -u origin main
```

## Step 10: Summary

Present a summary to the user:
- What was created (content types, skills, post count)
- Key themes identified
- Voice characteristics captured
- How to use the content studio (start with `cd content-studio && npm run dev`)
- How to invoke Claude skills (`/write-linkedin-post`, etc.)

## Key Principles

- **Voice fidelity matters most.** The style guide and professional profile are the most important files. Spend time getting the voice right.
- **Infer before asking.** If you can confidently determine something from the example posts (length, tone, themes), don't ask - just confirm.
- **Data-driven adaptation.** Use engagement metrics to identify what works for this person specifically.
- **Less is more on content types.** Only include content types the person actually creates. Don't add blog posts if they only post on LinkedIn.
- **The content studio app is generic.** Never modify the React app - it works for all content types out of the box.
