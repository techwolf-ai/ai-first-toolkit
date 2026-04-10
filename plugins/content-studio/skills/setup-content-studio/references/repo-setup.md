# Repository Setup Instructions

## 6a. Set Up from Plugin Template

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

## 6b. Create Personalized Files from Templates

Use the templates in the plugin's `templates/` directory as starting points:

1. **`CLAUDE.md`**: Adapt from `templates/CLAUDE.md`:
   - Replace `{{AUTHOR_NAME}}` with the person's name
   - Set content types to match what was decided
   - Update key concepts to match identified themes
   - Update skill commands available
   - Remove any content types not needed

2. **`references/professional-profile.md`**: Create from `templates/references/professional-profile.md`:
   - Current role and company
   - Education and background
   - Key achievements
   - Areas of expertise
   - Thought leadership platforms
   - Key topics
   - Personal philosophy (from their posts)

3. **`guidelines/linkedin.md`**: Adapt from `templates/guidelines/linkedin.md`:
   - Core voice & positioning (their focus area, tone, authority)
   - Key concepts (their 4-7 recurring themes with example angles)
   - Style essentials (what works for them, what to avoid)
   - Length guidelines (based on their actual post lengths)
   - Hook strategies (based on their actual high-performing hooks)

4. **`guidelines/opinion.md`** if opinion pieces are a content type: adapt from `templates/guidelines/opinie.md`:
   - Replace `{{OPINION_LANGUAGE}}` with the chosen language (e.g., "Dutch (Nederlands)", "English", "French")
   - Adapt language-specific examples and vocabulary to match

## 6c. Create Skills

Create skills in `.claude/skills/` for each content type. At minimum:
- `write-linkedin-post/SKILL.md`: Always include this
- `brainstorm-linkedin/SKILL.md`: Always include this
- `analyze-performance/SKILL.md`: Always include this

Add if relevant:
- `write-blog-post/SKILL.md`: If blog posts are a content type
- `write-opinion/SKILL.md`: If opinion pieces are a content type
- `brainstorm-opinion/SKILL.md`: If opinion pieces cross-pollinate from LinkedIn

Each skill must reference the new person's name, their style guide, and their professional profile.

## 6d. Set Up Hooks and Settings

Create `.claude/settings.json`:
```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/ensure-content-studio.sh"
          }
        ]
      }
    ]
  }
}
```
