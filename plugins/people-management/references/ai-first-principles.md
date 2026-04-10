# AI-First Design Principles

These principles guide how every skill in this plugin is designed.

## Core Principles

### 1. You Are Responsible
The human is always accountable. AI surfaces information and proposes. It never decides or acts autonomously. Every output is a draft for human review. In management context: the manager makes the call, the tool provides leverage.

### 2. Narrow Scope
Each skill does ONE thing well. No "do everything" commands. A meeting prep skill preps meetings. A triage skill triages. Users invoke what they need, when they need it. Resist the temptation to combine skills into mega-prompts.

### 3. Build for Yourself First
Design skills for real workflows, tested by real managers. If a skill doesn't save YOU time, it won't save anyone else time either. Start with what you actually do, not what sounds impressive.

### 4. Start with a Plan
Before building, map out: what inputs are available, what output is needed, what success looks like. Every skill has a clear trigger, clear sources, and a clear output format.

### 5. Don't Build Your Own Agent
Use the platform's capabilities. The platform provides MCP connectors, skill architecture, and context management. Don't reinvent these. Compose existing tools rather than building from scratch.

### 6. Stick to the Point
Don't let the AI ramble. Skills should produce focused, actionable output. A meeting prep should be scannable in 2 minutes. A triage should categorise, not narrate. Brevity is a feature.

### 7. Don't Be Stingy on the Input
Give the AI rich context. The setup skill exists to build a deep understanding of the manager's world. Reference files embed framework knowledge. The more context the AI has, the less generic the output.

### 8. Start with a Clean Slate
Each invocation should work independently. Don't assume the AI "remembers" a previous run. Load context explicitly from files (manager-context/). This makes skills reliable and debuggable.

### 9. Speak the Right Language
Use the manager's terminology, not generic business jargon. The setup skill builds a terminology map specifically so other skills can decode and use internal language. "CS" instead of "Customer Success", "the pod" instead of "the cross-functional team."

## How These Apply to This Plugin

| Principle | How it shows up |
|-----------|----------------|
| You Are Responsible | Skills never send messages, make decisions, or take action |
| Narrow Scope | 8 distinct skills, each with one clear purpose |
| Build for Yourself | Tested with real managers first |
| Start with a Plan | Every skill has structured input → output flow |
| Don't Build Your Own Agent | Uses The platform MCP connectors and skill architecture |
| Stick to the Point | Outputs are scannable summaries with links, not essays |
| Don't Be Stingy on Input | Setup skill + reference files provide deep context |
| Start with a Clean Slate | Every skill reads manager-context/ fresh |
| Speak the Right Language | Uses team terminology via setup-built glossary |
