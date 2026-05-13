# Task description style

Tasks must read like rows in a standard job-to-task CSV: a concise, role-level sentence that describes a reusable activity, not a specific instance. Haiku subagents and the main agent both use this file as the authority on how to phrase a task.

## Shape

```
<verb> <object> [using/with <tech or context>] to <purpose>
```

- **Verb-first**, imperative, present tense. Never first-person.
- **One clause**, ~10–15 words. Never two coordinated verbs, split "design and implement" into two tasks.
- **Outcome** included when observable from the transcript. Skip when unclear (don't invent).
- **Technology** only when load-bearing: the task would mean something different without it.

## Generalise from the instance

The point of a task name is that it describes a *reusable activity*, not a single session. Strip anything that ties it to one specific instance:

- **People names, company names, project names, dates, specific counts**, always remove. They belong to the instance, not the task. `Prepare for meeting with Jane` → `Prepare for customer meeting`. `Top 47 hires of 2024` → `Rank candidate pool for hiring decisions`.
- **Internal or proprietary product names** (your company's own tools, datasets, models, plugins), replace with a generic descriptor. A proprietary embedding model → `embedding model`. An internal market-intelligence CLI → `internal analytics CLI` or `workforce-data CLI`, depending on what's load-bearing. A custom team plugin → `team-management plugin`.
- **Third-party product names when incidental**, if the task isn't specifically about that product, use a category. A task about pulling customer data from two CRM vendors → `Pull data from CRM systems`. A task about searching across a chat tool and a mail tool → `Search chat and mail sources`.
- **Third-party product/technology names when they are the subject**, keep. `Write a Python web scraper using Playwright` is fine because the task is specifically about Python and Playwright. `Tune a PyTorch training loop for distributed GPUs` keeps PyTorch.

The test: could a different company or person perform this task with different tools? If yes, generalise. If the tool is the task, keep it.

## Good examples (copy this shape)

```
Design microservices architecture using Python and TypeScript to support scalable operations
Implement RESTful and GraphQL APIs to enable platform functionality
Write production-quality code for deployment on Kubernetes clusters
Resolve production incidents within established SLA targets
Debug timezone-related issues in workflow scheduling systems to ensure accuracy
Review pull requests to maintain code quality standards
Prepare briefing documents for executive meetings using calendar and email context
Draft social media posts expressing thought leadership on industry trends
Analyze candidate profiles from applicant-tracking data to inform hiring decisions
Build internal automation tools to accelerate team productivity
Finetune an embedding model through iterative training experiments
Write Python data pipelines to extract and transform analytics events
```

## Bad examples (and why)

| Bad | Why |
|---|---|
| `Worked on the Acme integration` | Past tense, project-named, no verb-object-purpose shape |
| `Help me prepare for the meeting with Alex` | First-person, named, not reusable |
| `Build a Chrome extension that classifies tasks and stores them in SQLite and shows a dashboard and syncs with the cloud` | Multiple coordinated asks, split into 3 tasks |
| `Fix bug` | No object, no purpose, too generic to cluster |
| `Use WidgetPro to embed the vacancy strings from the 2024-Q3 dataset` | Date-named, proprietary product, not reusable; also a technique description, not a task |
| `Stuff with AI assistant` | Meaningless |
| `Build the Foo relationship tracker for our top 100 partners` | Proprietary name + specific count |

## Splitting rule

If a session contains more than one genuinely different task, emit up to 3 task entries with separate `session_refs` pointing at the same session. The splitting threshold is *reusability*: would an outside reader see these as distinct role-level activities? Then split.

## Category field

Pick exactly one from: `engineering`, `research`, `writing`, `ops`, `analysis`, `planning`, `communication`. If none fit well, pick the closest and accept the imprecision, do not invent new categories.
