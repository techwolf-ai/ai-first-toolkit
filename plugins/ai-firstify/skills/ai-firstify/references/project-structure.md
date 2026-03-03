# Project Structure Guide

## CLAUDE.md Template

```markdown
# CLAUDE.md

## Project
[One sentence: what this project does and who it's for]

## Tech Stack
- Backend: [Express.js / Flask / etc.]
- Frontend: [HTML+CSS / React / etc.]
- Data: [Markdown with YAML frontmatter / SQLite / etc.]

## Key Files
- [filename] -- [what it does]
- [filename] -- [what it does]

## Conventions
- [File naming convention]
- [Code style preferences]
- [Content format requirements]

## Constraints
- [What NOT to do]
- [Size limits, performance requirements]
- [Data handling rules]

## Skills
- /[skill-name] -- [what it does]

## Tone
- [Writing style for generated content]
```

### CLAUDE.md Guidelines

- **Under 200 lines** (ideally under 100)
- Focus on what the agent needs to know RIGHT NOW
- Reference external documents instead of inlining
- Update after significant changes
- Include key file paths so the agent knows where things are

---

## Minimal Project Structure (Simple Tool)

```
my-tool/
├── CLAUDE.md                # Project context
├── .gitignore               # Exclude sensitive files
├── .claude/
│   └── skills/
│       └── my-skill/
│           ├── SKILL.md     # Skill instructions
│           └── scripts/
│               └── validate.sh
└── output/                  # Generated output files
```

---

## Content Studio Structure

```
my-content-studio/
├── CLAUDE.md
├── .gitignore
├── package.json
├── server.js
├── public/
│   ├── index.html
│   └── style.css
├── content/
│   ├── post-1.md
│   └── post-2.md
└── .claude/
    └── skills/
        └── content-writer/
            ├── SKILL.md
            ├── references/
            │   └── style-guide.md
            └── scripts/
                ├── read-all.sh
                └── validate.sh
```

---

## Skill-Heavy Project Structure

```
my-workflow-project/
├── CLAUDE.md
├── .gitignore
├── data/                          # Input data
│   ├── templates/
│   └── sources/
├── output/                        # Generated output
└── .claude/
    └── skills/
        ├── research/
        │   ├── SKILL.md
        │   ├── references/
        │   │   └── research-methodology.md
        │   └── scripts/
        │       └── search-sources.sh
        ├── writing/
        │   ├── SKILL.md
        │   ├── references/
        │   │   ├── style-guide.md
        │   │   └── examples/
        │   └── scripts/
        │       └── validate.sh
        └── review/
            ├── SKILL.md
            └── references/
                └── review-criteria.md
```

---

## .gitignore Templates

### General (all projects)

```
# Dependencies
node_modules/

# Environment
.env
.env.local
.env.*.local

# Credentials
*.pem
*.key
credentials.json
service-account.json

# OS files
.DS_Store
Thumbs.db

# IDE
.vscode/
.idea/

# Build output
dist/
build/
```

### Python projects (add to general)

```
__pycache__/
*.pyc
.venv/
venv/
*.egg-info/
```

### Node.js projects (add to general)

```
node_modules/
package-lock.json
```

---

## Git Commit Discipline

### When to Commit

- After completing a feature or fix
- Before switching tasks
- Before running risky operations
- After significant refactoring
- At least once per hour during active work

### Commit Message Style

```
Add customer signal search skill
Fix validation script for empty inputs
Update CLAUDE.md with new conventions
Remove unused frontend code
```

Keep messages short (under 72 characters), action-oriented ("Add", "Fix", "Update", "Remove"), and focused on what changed.

### Git Workflow

```bash
# The basic flow
git add .
git commit -m "Add search skill with Slack integration"
git push

# Let Claude handle it
"Commit and push my changes with a meaningful message"
```
