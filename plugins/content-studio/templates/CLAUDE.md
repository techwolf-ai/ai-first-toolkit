# Thought Leadership & Opinion Content System

**Content workflow system with React UI for thought leadership and opinion pieces**

## Overview

This repository manages content for {{AUTHOR_NAME}}:
{{CONTENT_TYPES}}

All use the same Content Studio and workflow:
- **Structured content workflow** (Ideas -> Drafts -> Published)
- **React-based Content Studio** (visual editor with real-time updates)
- **Git version control** (built into the UI)

---

## Content Types

<!-- Uncomment and configure the content types that apply -->

### LinkedIn Posts (`type: linkedin-post`)
- **Language:** English
- **Target:** 150-250 words
- **Style guide:** `guidelines/linkedin.md`

<!-- ### Blog Posts (`type: blog-post`)
- **Language:** English
- **Target:** 800-1200 words
- **Style guide:** `guidelines/linkedin.md` (same voice and style) -->

<!-- ### Opinion Pieces (`type: opinion`)
- **Language:** {{OPINION_LANGUAGE}}
- **Target:** ~3500 characters
- **Style guide:** `guidelines/opinion.md` -->

---

## Writing Skills (Claude Code)

Use these skills for context-aware writing assistance:

| Command | Purpose |
|---------|---------|
| `/write-linkedin-post` | Write/develop LinkedIn content |
| `/brainstorm-linkedin` | Generate LinkedIn ideas from source material |
| `/analyze-performance` | Analyze engagement patterns to find what works |

<!-- Add if applicable:
| `/write-blog-post` | Write/develop blog post (800-1200 words) |
| `/write-opinion` | Write/develop Dutch opinion piece |
| `/brainstorm-opinion` | Generate opinion ideas from recent posts |
-->

Skills are defined in `.claude/skills/` and automatically load the relevant style guides and references.

---

## Quick Start

### 1. Start Content Studio

```bash
cd content-studio
npm install  # First time only
npm run dev
```

Open http://localhost:3000

### 2. Create a New Idea

**Via Content Studio UI:**
1. Click "+ New Idea"
2. Fill in title, type, and core insight
3. Save

**Via Claude:**
Ask Claude to create a new idea. It will create a `.yaml` file in `content/posts/{type}/` with `stage: 01-ideas`.

**IMPORTANT:** When creating files, Claude must first get the current timestamp:
```bash
date -u +"%Y%m%d-%H%M%S"  # For filename slug (e.g., 20260112-114523)
date -u +"%Y-%m-%dT%H:%M:%S.000Z"  # For created/lastUpdated fields
```

**File path format:** `content/posts/{type}/{slug}-{slugified-title}.yaml`

### 3. Write and Edit

1. Open the idea in Content Studio
2. Edit the core insight and content
3. Change stage in metadata when ready to move forward
4. Auto-saves every 30 seconds

### 4. Publish

When ready, change the stage to "Published" in the metadata panel.

---

## Folder Structure

```
{{REPO_NAME}}/
├── content/
│   ├── posts/                     # Content organized by type
│   │   ├── linkedin-post/         # LinkedIn posts
│   │   │   └── {slug}-{title}.yaml
│   │   └── ...                    # Other content types
│   └── images/                    # Uploaded images per post
│
├── content-studio/                # React app (Next.js)
│   ├── app/                       # Pages & API routes
│   ├── components/                # React components
│   ├── lib/                       # Utilities
│   └── types/                     # TypeScript types
│
├── .claude/
│   └── skills/                    # Claude Code skills
│
├── guidelines/                    # Style guides by content type
│   └── linkedin.md                # LinkedIn post style guide
│
├── references/                    # Background docs
│   └── professional-profile.md
│
├── scripts/                       # Utility scripts
│   ├── list-published.sh
│   ├── print-published.sh
│   ├── search-posts.sh
│   └── list-by-type.sh
│
└── CLAUDE.md                      # This file
```

---

## Content Studio Features

**Dashboard (Kanban View)**
- See all content across stages (Ideas, Drafts, Published)
- Color-coded by type
- Git status indicator

**Editor**
- Core insight field at top
- Markdown editor with live preview
- Metadata panel for stage, type, tags
- Auto-save every 30 seconds
- Image upload support

**Git Integration**
- View current status and changes
- Commit with message
- Push to remote
- View recent commits

---

## Workflow Stages

All content lives in `content/posts/` as `.yaml` files. The `stage` field determines the workflow stage:

### Ideas (`stage: 01-ideas`)
Capture concepts with context. Add initial thoughts, core insight, and tags.

### Drafts (`stage: 02-drafts`)
Write and iterate. Use the markdown editor, get feedback, refine.

### Published (`stage: 03-published`)
Archive published content with publication details.

---

## File Format

### File Naming

Files are stored by type with descriptive filenames:
- **Location:** `content/posts/{type}/{slug}-{slugified-title}.yaml`
- **Example:** `content/posts/linkedin-post/20260112-120000-ai-productivity-tips.yaml`

The `slug` (timestamp like `20260112-120000`) is the unique identifier that never changes. The filename automatically updates when the title changes.

### YAML Structure

```yaml
stage: 01-ideas
type: linkedin-post
title: Your Title
slug: 20260112-120000
created: "2026-01-12T12:00:00.000Z"
lastUpdated: "2026-01-12T12:00:00.000Z"
coreInsight: The key takeaway in one sentence
tags:
  - topic
audience: Who this is for
keyConcepts:
  - Key concept
images: []
content: |-
  Your markdown content here...

  Multiple paragraphs work with the |- syntax.
```

### Editor URLs

The Content Studio uses type-based URLs for stability:
- **URL format:** `/editor/{type}/{slug}`
- **Example:** `/editor/linkedin-post/20260112-120000`

---

## Writing Guidelines

See `guidelines/linkedin.md` for the full style guide. Key concepts:

<!-- Replace with the author's actual recurring themes -->
1. **Theme 1** - Description
2. **Theme 2** - Description
3. **Theme 3** - Description

---

## Finding Posts (For Claude)

**IMPORTANT:** When a user references a post by topic, title, or keyword, Claude MUST use the search script to find the correct file.

### Search Commands

```bash
# Search all posts
./scripts/search-posts.sh "topic"

# Search with type filter
./scripts/search-posts.sh "AI" --type linkedin-post

# List by type (any stage)
./scripts/list-by-type.sh linkedin-post

# List published (optionally by type)
./scripts/list-published.sh
./scripts/list-published.sh linkedin-post
```

**Always search before assuming which file to edit.**

---

## Content Writing Workflow (For Claude)

**IMPORTANT: Before writing or rewriting any content, Claude MUST:**

1. **Read all published pieces** - run `./scripts/print-published.sh [type]` to get all posts with full content in one call
2. **Read `guidelines/linkedin.md`** for style rules and hook strategies
3. **Read `references/professional-profile.md`** to understand the author's background

This ensures:
- Consistent voice and tone across all pieces
- Understanding of topics already covered (avoid repetition)
- Familiarity with successful hooks and structures
- Alignment with the author's expertise and perspective

---

## Available Scripts

| Script | Purpose |
|--------|---------|
| `./scripts/print-published.sh [type]` | Print all published posts with full content (up to 100, most recent first) |
| `./scripts/list-published.sh [type]` | List published post file paths only |
| `./scripts/search-posts.sh "<term>" [--type <type>]` | Search posts by keyword with optional type filter |
| `./scripts/list-by-type.sh <type>` | List all posts of a specific type |
