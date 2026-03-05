# ai-firstify

AI-first project auditor and re-engineer based on the 9 design principles and 7 design patterns from the [TechWolf AI-First Bootcamp](https://ai-first.techwolf.ai).

## Install

```bash
# Add the TechWolf marketplace (once)
/plugin marketplace add techwolf-ai/ai-first-toolkit

# Install the plugin
/plugin install ai-firstify@techwolf-ai-first
```

## Usage

The skill triggers automatically when you ask Claude Code to:

- **Audit** a project: "review", "audit", "analyze", "assess"
- **Re-Engineer** a project: "ai-firstify", "fix", "improve", "transform"
- **Bootstrap** a new project: "start", "new project", "bootstrap", "build from scratch"

Or invoke directly:

```
/ai-firstify
```

## Modes

1. **Audit** -- Read-only analysis across 7 dimensions with a scored report
2. **Re-Engineer** -- Full audit followed by active fixes in 7 phases
3. **Bootstrap** -- Interactive new project setup with discovery questions

## Author

Jeroen Van Hautte ([TechWolf](https://techwolf.ai))
