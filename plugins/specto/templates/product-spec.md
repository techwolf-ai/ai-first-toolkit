| | |
|---|---|
| **Epic link** | [<TICKET>](https://<tracker-site>/browse/<TICKET>) |
| **Change classification** | <Standard \| Non-standard (Q1 / Q2 / Q3)>; populated from the linked epic by `new-spec` when a compliance profile is configured — delete this row otherwise |
| **Development Stage** | <Discovery \| Validation \| Production>; from the linked epic |
| **Epic Type / Delivery cycle** | <Epic Type, e.g. Strategy> / <YYYY QN, e.g. 2026 Q2>; from the linked epic |
| **AI feature** *(Does this introduce a new AI feature or significantly change an existing AI feature?)* | <YES, short rationale + AI test plan reference / NO> |
| **Product opportunity** | [<OPP-XXX>](https://<tracker-site>/browse/<OPP-XXX>) |
| **Version / scope** | V1 |

## Delivery Stakeholders

> This file is the **product specification**. The engineering specification lives in [engineering-spec.md](engineering-spec.md) and has its own stakeholder table for engineering, platform, and security reviewers.

| Representing / SME  | Representative                | ✓ / ✗ |
| ------------------- | ----------------------------- | ----- |
| Product manager     | @<pm-handle>                  |       |
| Engineering manager | @<em-handle>                  |       |
| Engineering team    | @<eng-handle-1>               |       |
| Engineering team    | @<eng-handle-2>               |       |
| Platform team       | @<platform-handle>            |       |
| PS                  | @<ps-handle-or-blank>         |       |

---

# Product Specifications

> **V1 scope:** <one-line scope statement.>

## 1. What value does this bring?

### 1.1. Problem

*<2-3 paragraphs. Today, customers cannot do X. This matters because Y. Bullet the concrete use cases below.>*

- *<concrete use case 1>*
- *<concrete use case 2>*

### 1.2. Solution

*<1-2 paragraphs. What changes for the customer. High-level, not implementation.>*

*When the solution is a multi-step user flow (≥3 steps the customer takes or sees), add a mermaid `flowchart` of that journey (see `references/visual-conventions.md`). Keep it customer-visible steps, not implementation. Skip it for a single-action feature.*

### 1.3. Objectives

*Conditions under which we'd call this roadmap item "done and worth having shipped." These are not OKR rows; they are the roadmap-item-level outcomes that contribute to the OKRs.*

| # | Objective | Customer / segment | OKR |
| - | --------- | ------------------ | --- |
| 1 | *<objective>* | *<segment>* | *<KR id>* |

### 1.4. Key results / metrics

*≤5 metrics. Each metric must be directly controllable by this feature. Drop "north star" outcomes that depend on more than this feature can move alone.*

| Metric | Threshold | Why this matters |
| ------ | --------- | ---------------- |
| *<adoption: distinct tenants calling endpoint within 30 days of launch>* | *<≥ proposed value>* | *<rationale>* |
| *<latency: p99 for primary endpoint>* | *<≤ ms>* | *<rationale>* |
| *<accuracy: correlation with human-labelled ground truth>* | *<≥ value>* | *<rationale>* |

## 2. User stories

*Each row follows: "As [role], I want [action], so that [outcome]." Skip empty buckets; do not carry empty tables.*

**Must haves**

| User story | In scope |
| ---------- | -------- |
| *<As ..., I want ..., so that ...>* | ✓ |

**Should haves** *(omit this section if empty)*

| User story | In scope |
| ---------- | -------- |
| *<...>* | ✓ |

**Won't haves** *(every row needs a Reason)*

| User story | Reason |
| ---------- | ------ |
| *<feature deferred>* | *<technical / scope / prior art reason>* |

## 3. Functional requirements

### 3.1. Inputs

*What data flows in. Sources only, not column-by-column DB schema.*

| Input | Source | Notes |
| ----- | ------ | ----- |
| *<input>* | *<source system>* | *<governance, freshness, format>* |

### 3.2. Endpoints

*Endpoint names and one-line customer-visible behaviour each. Path/query/body/response/error tables and caps live in [engineering-spec.md §2.6](engineering-spec.md) — do NOT duplicate them here.*

| Endpoint | Customer-visible behaviour | Priority |
| -------- | -------------------------- | -------- |
| `<METHOD> /<path>` | *<one sentence: what the caller gets and why>* | Must-have |
| `<METHOD> /<path>` | *<one sentence>* | Should-have *(omit row if none)* |

### 3.3. Exports

*Export names and one-line description each. Schema, caps, and prior-art equivalents live in [engineering-spec.md §2.6](engineering-spec.md).*

| Export | Description (source, cadence, caller use case) |
| ------ | ---------------------------------------------- |
| *<Export name>* | *<one sentence>* |

## 4. Design decisions for product approval

*Choices that need product sign-off before engineering locks the implementation. One sub-section per choice that diverges from existing patterns.*

### 4.1. *<Decision title>*

- **Proposed (V1):** *<one line>*
- **Rationale:** *<2-3 lines>*
- **Alternatives considered (optional):** *(useful when the choice was non-obvious — drop the row entirely if the trade-off is uncontroversial)*

  | Option | Pros | Cons | Why rejected |
  | ------ | ---- | ---- | ------------ |
  | *<Alt A>* | *<one line>* | *<one line>* | *<one line>* |

- **Open question for product:** *<yes/no, what specifically is being asked>*
- **Decision (V1):** *<filled after sign-off, with approver name>*

## 5. Rollout & Adoption

*How this feature lands with real users. §5 is what makes the spec accountable for adoption, not just for shipping.*

### 5.1. Customer demand

*<Which customers asked for this. Concrete examples preferred over generic statements. "Customer A: asked for X in Slack thread Y on YYYY-MM-DD" beats "customers want this".>*

| Customer | What they asked for | Source (link) |
| -------- | ------------------- | ------------- |
| *<Customer A>* | *<one-line ask>* | *<link to Slack thread, ticket, call notes>* |

### 5.2. Pilot stakeholders

*<Which customer(s) we're piloting with. Internal partner(s) (solutions / support) and engineering partners on both sides. Empty here means the rollout hasn't been planned yet.>*

| Side | Role | Name |
| ---- | ---- | ---- |
| Vendor side | Internal partner (solutions / support) | @<handle> |
| Customer | Champion | *<name + title>* |

**Pilot success criteria:** *<what would make us roll out vs. iterate; e.g. "≥2 of 3 piloted tenants report material adoption signal within 2 weeks".>*

### 5.3. Rollout cadence

*<Pilot → general availability path. Gating signals between phases. Lock to one or two concrete §1.4 metrics with threshold values.>*

| Phase | Scope | Gate to next phase |
| ----- | ----- | ------------------ |
| Pilot | *<which tenants / endpoints>* | *<concrete §1.4 metric ≥ value>* |
| GA    | *<all tenants>* | *<post-launch monitoring window + threshold>* |

*When the rollout has ≥2 phases, add a mermaid `timeline` of the phases (see `references/visual-conventions.md`). The timeline captions the table; the table stays canonical for the gates.*

### 5.4. Adoption goals

*<One-line statement of what "adopted" means for V1. Should restate one §1.4 metric with a deadline.>*

*Example: "≥ 6 distinct tenants calling the primary endpoint within 30 days of GA. Source-of-truth: §1.4 row 1."*
