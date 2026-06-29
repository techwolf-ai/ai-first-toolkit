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

**Do not proceed until you have at least 10 substantive example posts.** Shares/reposts with minimal commentary don't count. Unless the person does not have at least 10 posts.

## Step 3: Research the Person Online

Use WebSearch to find:
- Their professional background and bio (company website, conference bios)
- Education and career history
- Speaking engagements, podcasts, publications
- Areas of expertise and thought leadership topics
- Any published articles or blog posts

Combine the online research with what you learn from their example posts.

## Step 4: Analyze Their Voice and Style

Read **references/voice-analysis.md** for the full analysis framework covering writing style, content themes, and engagement patterns.

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

If opinion pieces are a content type, also ask which language the opinion pieces should be written in (it may differ from LinkedIn post language). Use this to set `{{OPINION_LANGUAGE}}` in `guidelines/opinion.md`.

### Target Length
If the examples show a consistent pattern, confirm it. If not, ask:
> "Their posts range from X to Y words. What's the ideal target range?"

### Publication Outlets
> "Besides LinkedIn, where does this person publish?"
> (Blog, newspaper columns, industry publications, etc.)

**Only ask questions where the answer isn't already clear from the example posts and research.** Don't ask about things you can confidently infer.

## Step 6: Create the New Repository

Read **references/repo-setup.md** for the full repository setup procedure, including template copying, file personalization, skill creation, and hook configuration.

## Step 7: Populate with Published Content

Convert each example post into a YAML file. Read **references/content-format.md** for the file path convention and YAML structure.

**If your agent supports sub-agents (e.g. Claude Code), use parallel Task agents** to create posts in batches of 10 for efficiency. Otherwise (e.g. Codex), create the posts sequentially: the output is identical, it just takes longer.

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
- Content types: [list types]"

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
