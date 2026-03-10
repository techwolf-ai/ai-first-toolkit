---
name: content-studio
description: Entry point for the TechWolf content-studio plugin. Use to understand the workflow, pick the right content skill, or start setup for a new author/repository.
---

# Content Studio

Use this skill as the plugin-level entry point for the TechWolf content-studio workflow in Codex.

## Start Here

- If the user wants a new content studio for a person, use `setup-content-studio` first.
- If the repository is already configured, route to the most specific skill:
  - `write-linkedin-post`
  - `write-blog-post`
  - `write-opinion`
  - `brainstorm-linkedin`
  - `brainstorm-opinion`
  - `analyze-performance`

## Workflow

1. Confirm whether the current repository is already a configured content studio.
2. If not, use `setup-content-studio` to create or adapt one from the template.
3. Before writing or brainstorming, read the existing published content and author guidance required by the target skill.
4. Use the repository scripts for search/list/print operations when the selected skill expects them.

## Repository Expectations

- Most content skills assume they are being run inside a configured content studio repository.
- Those skills rely on repo-local files such as `guidelines/`, `references/`, `content/posts/`, and `scripts/`.
- If those files are missing, stop and either run `setup-content-studio` or explain what is missing.
