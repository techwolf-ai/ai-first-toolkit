# Content Studio Plugin

A complete content studio for managing thought leadership content (LinkedIn posts, blog posts, opinion pieces) with a visual editor, Claude Code skills, and utility scripts.

## What's Included

- **Content Studio** - Next.js visual editor with Kanban dashboard, markdown editing, git integration, and auto-save
- **7 Claude Code Skills** - Writing, brainstorming, performance analysis, and setup automation
- **Utility Scripts** - Search, list, and print published content from the terminal
- **Templates** - Ready-to-customize guidelines, professional profile, and CLAUDE.md for any author

## Skills

| Skill | Purpose |
|-------|---------|
| `/content-studio:setup-content-studio` | Set up a new content studio for a person (interactive) |
| `/content-studio:write-linkedin-post` | Write or develop LinkedIn posts |
| `/content-studio:write-blog-post` | Write or develop blog posts (800-1200 words) |
| `/content-studio:write-opinion` | Write Dutch opinion pieces |
| `/content-studio:brainstorm-linkedin` | Generate LinkedIn ideas from source material |
| `/content-studio:brainstorm-opinion` | Generate opinion ideas from recent LinkedIn posts |
| `/content-studio:analyze-performance` | Analyze engagement patterns across published posts |

## Getting Started

### 1. Install the Plugin

```bash
# In Claude Code
/plugin install content-studio@techwolf-ai-first
```

### 2. Set Up for a Person

Run the setup skill to create a personalized content studio:

```bash
/content-studio:setup-content-studio
```

This interactive process will:
1. Gather information about the author
2. Analyze their writing voice from example posts
3. Create a configured repo with guidelines, profile, and skills
4. Populate with their existing content

### 3. Start Writing

Once set up, use the writing skills:

```bash
/content-studio:write-linkedin-post
/content-studio:brainstorm-linkedin
```

## Content Studio UI

The Content Studio is a Next.js app that provides:

- **Kanban Dashboard** - Visual overview of all content across stages (Ideas, Drafts, Published)
- **Markdown Editor** - Write and preview content with real-time updates
- **Metadata Panel** - Manage stage, type, tags, and audience
- **Git Integration** - Commit and push directly from the UI
- **Auto-save** - Changes saved every 30 seconds

Start it with:
```bash
cd content-studio
npm install  # first time only
npm run dev
```

## Content Workflow

```
Ideas (01-ideas)  -->  Drafts (02-drafts)  -->  Published (03-published)
```

All content is stored as YAML files in `content/posts/{type}/`, making it fully version-controlled and scriptable.

## Customization

The `templates/` directory contains starter files for personalizing the studio:

| Template | Purpose |
|----------|---------|
| `templates/CLAUDE.md` | System documentation with `{{AUTHOR_NAME}}` placeholders |
| `templates/guidelines/linkedin.md` | LinkedIn style guide template with theme placeholders |
| `templates/guidelines/opinie.md` | Dutch opinion piece style guide template |
| `templates/references/professional-profile.md` | Author profile skeleton |

## Scripts

| Script | Usage |
|--------|-------|
| `scripts/print-published.sh [type]` | Print all published posts with full content |
| `scripts/list-published.sh [type]` | List published post file paths |
| `scripts/search-posts.sh "<term>"` | Search posts by keyword |
| `scripts/list-by-type.sh <type>` | List all posts of a type |

## License

[MIT](../../LICENSE)
