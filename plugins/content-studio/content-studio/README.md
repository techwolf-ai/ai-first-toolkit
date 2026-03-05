# Content Studio

**Visual content editor with real-time file watching and Git integration**

Built with [Next.js](https://nextjs.org), TypeScript, and Tailwind CSS.

## Quick Start

```bash
# Install dependencies (first time only)
npm install

# Start development server
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) to see the dashboard.

## What is This?

Content Studio is a visual interface for the Thought Leadership content workflow. It provides:

- **Kanban Dashboard** - See all content across Ideas → Drafts → Published stages
- **Markdown Editor** - Simple editor with preview mode and auto-save
- **Metadata Panel** - Visual forms for all frontmatter fields
- **Suggestions UI** - Google Docs-style interface for Claude's suggestions
- **Git Integration** - Commit, push, and view history from the UI
- **Real-time Updates** - Automatically refreshes when Claude Code edits files

## Features

### Dashboard
- Visual board showing content in 3 stages
- Filter by type, tags, status
- Git status indicator
- Quick navigation to editor

### Editor
- 3-column layout: Metadata | Editor | Suggestions
- Markdown editing with preview
- Auto-save every 30 seconds
- Real-time file watching (sees Claude's changes instantly)

### Suggestions (Google Docs Style)
- Sidebar with all suggestions from Claude
- Accept/reject each suggestion individually
- Diff preview of changes
- Priority-based sorting
- Tracks suggestion history

### Git Panel
- View current branch and changes
- Commit with message
- Push to remote
- View recent commit history

## Integration with Claude Code

Content Studio works alongside Claude Code slash commands:

1. **Write in UI** → Auto-saved to filesystem
2. **Run `/review-draft`** in Claude Code → Creates suggestions
3. **See suggestions in UI** → Accept/reject with visual interface
4. **Run `/apply-suggestions`** → Claude applies accepted changes
5. **Commit** via UI or command line

## Architecture

```
content-studio/
├── app/
│   ├── page.tsx                      # Dashboard
│   ├── editor/[stage]/[slug]/        # Editor pages
│   └── api/                          # API routes
│       ├── content/                  # Content CRUD
│       ├── git/                      # Git operations
│       └── watch/                    # File watching (future)
├── components/
│   ├── Dashboard/                    # Kanban components
│   ├── Editor/                       # Editor components
│   ├── Git/                          # Git UI
│   └── Suggestions/                  # Suggestion review UI
├── lib/
│   ├── content.ts                    # File operations
│   ├── git.ts                        # Git operations
│   └── fileWatcher.ts                # Real-time watching
└── types/
    └── content.ts                    # TypeScript interfaces
```

## Development

**Tech Stack:**
- Next.js 15 (App Router)
- TypeScript
- Tailwind CSS
- gray-matter (frontmatter parsing)
- simple-git (git operations)
- chokidar (file watching)

**Type Checking:**
```bash
npm run build  # Checks types and builds
```

## Troubleshooting

**Port already in use:**
```bash
lsof -ti:3000 | xargs kill -9
npm run dev
```

**Changes not showing:**
- File watcher takes ~1 second to detect changes
- Refresh browser if needed

**Suggestions not appearing:**
- Check `.suggestions.json` exists next to `.md` file
- Verify JSON is valid
- Refresh editor page

See main `CLAUDE.md` in the root directory for complete workflow documentation.
