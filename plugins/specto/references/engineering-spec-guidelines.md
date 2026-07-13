# What a good engineering spec looks like

> **Status: stable.** Section structure, anti-patterns, and the pre-MR checklist are stable. Specific patterns get folded in as real engineering-spec review rounds produce evidence; that enrichment ships as a follow-up patch, not a new version.

## Core principles

1. **Audience: engineers and platform reviewers, not PMs.** The engineering spec is for stakeholders who decide *how*. Product decisions belong in `product-spec.md`. If a section describes user-facing behaviour, scope, or business value, it belongs in the product spec.

2. **Direct, terse, evidence-driven.** No marketing language. State the architecture, the algorithm, the test plan, the open question. Stop.

3. **One source of truth per fact.** A latency budget, a storage decision, a schema appears once; the second mention is a reference.

4. **Decisions in the spec, deliberation in MR comments.** Pick one option with a rationale. Add an `Open question for engineering:` line if you need sign-off, but do not litigate alternatives in the spec body.

5. **Cross-reference platform conventions wherever a parallel exists.** Your platform's service standards, telemetry conventions, server config, deployment topology. Naming alignment removes a class of review comments before they happen. The **nearest `AGENTS.md`/`CLAUDE.md`** to the code a decision touches is binding: a storage, endpoint, data-model, or config-placement decision conforms to it, or a §6 design decision names the convention, the divergence, and the rationale. The convention chain is cumulative (repo-wide rules at the root, subtree rules deeper); the closest file wins on conflict.

6. **Templates create gravity. Default to skeletal; expand only when in scope.** Every named section is a slot the writer feels obliged to fill. Sub-sections are required only when the spec's classification flags (Q1/Q2/Q3, AI feature, Development Stage) say the topic is in scope. Out-of-scope sections answer `*Not applicable — <flag> = <value>*` in one line and stop.

7. **Conciseness is a quality signal.** Placeholders are one sentence, not a three-bullet template. Reviewer agents flag verbose prose as a first-class finding, not a style nit.

8. **Engineering context ≠ product context.** Product-spec context describes user-facing behaviour; engineering specs need code-level signal — models, dataclasses, services, flows, dependencies. When `compiled/` is product-spec-derived only, the writer hunts the relevant dependent repos for the missing signal before drafting §2. Architectural decisions cannot be drawn from product-spec context alone.

9. **Specify the harness, not the implementation, when many solutions are valid.** A design decision the spec genuinely *fixes* — a convention, an NFR, a cross-system contract that makes one shape load-bearing — gets the concrete mechanism (DDL, endpoint contract, algorithm). A decision with **multiple valid implementations** gets the acceptance criteria, constraints, and invariants any solution must satisfy, marked with the literal lead-in `*Implementer's choice — must satisfy:*` followed by the criteria list. The under-determined specifics are then `implement-ticket`'s to decide, and the criteria are what `plan-to-tickets` carries onto tickets and `dod` verifies — the harness is what's checked, not a prescribed implementation. Each criterion must be *verifiable* (a test or a check can decide it), not a vibe. Over-specifying picks a solution prematurely, lengthens the spec, and removes freedom the implementation agent can use.

10. **Design to the stated scope, not a hypothetical future one.** An abstraction layer with one caller, a config knob nothing asks for, or capacity headroom past what §1 NFRs require is scope creep in engineering form: complexity paid for a need that doesn't exist yet, and the first maintenance cost. Every design element in §2 traces to a §1 NFR or the linked product spec's Must/Should scope. A real future need is real enough to name as an `Open question for engineering:` in §6 with its rationale, not to build silently under "flexibility."

## Applicability matrix

Required-when rules key off *condition flags* from two sources. **Intrinsic flags** are always available from the spec and epic: AI feature, schema changes, new infra, Development Stage. **Compliance-profile flags** exist only when a compliance profile is configured (`.specto/config.yml compliance:`); its questions add flags (for example `security`, `availability`, `data`) and rigor requirements. Both are populated from the linked epic by `epic-fields.sh` into `.specto-meta.yml`.

| Section | Required when | Default when not required |
|---|---|---|
| §1.2 Availability and SLOs | Development Stage = Production | One-line: link to the service's existing SLA page, or `*Not applicable — pre-production stage.*` |
| §1.3 Cost envelope | new infra introduced, OR compliance flag "availability" | `*Not applicable — no new infra.*` |
| §3.2 AI test plan | AI feature = Yes | `*Not an AI feature.*` |
| §3.3 Load testing | AI feature = Yes, OR compliance flag "availability" | `*Not applicable.*` |
| §4.3 Data migration reversibility | §2.3 storage model has schema changes | `*Not applicable — no schema changes.*` |
| §5 Other affected systems | the change touches systems outside the spec's primary one (pipelines, exports, downstream consumers) | `*Not applicable — change is contained to the primary system.*` |
| §2.3 data-model diagram (`erDiagram`) | §2.3 storage model has ≥2 related entities | omit (a single standalone table needs no diagram) |
| §2.5 state diagram (`stateDiagram-v2`) | a status/state enum is added or changed | omit (no state to diagram) |

When a compliance profile is configured, its questions add flags and rigor requirements on top of the intrinsic rules above; see `references/compliance-profile.example.yml`.

§1.1 latency targets, §2.1 architecture, §3.1 unit/integration coverage, §3.4 canary/rollout, §4.1/§4.2 rollback, §6 design decisions are **always required**. §2.6 endpoint contracts is required when the spec adds or changes endpoints. Diagram conventions (which mermaid form, the dark-mode palette, validate-before-write) live in `references/visual-conventions.md`.

## Length caps

- Placeholder text in the template is **one sentence** (not three bullets, not "what fails first / what the user sees / what on-call does").
- Filled section bodies are typically **1-3 short paragraphs or a single table**. Anything longer should split into a sub-section or move to a referenced doc.

## Style rules

- Same mechanical rules as product-spec-guidelines.md: no em-dashes, no `:product:`/`:engineering:` emoji codes, inline guardrails over sprawling prose, blockquotes for cross-section pointers.
- Cap code-identifier density in prose: don't chain 3+ backticked identifiers into one sentence (reads like a commit message) — split across sentences or move the sequence into a table/code fence.
- One canonical term per concept, matching product-spec.md's wording for any shared mechanism.
- One parenthetical per sentence.
- One register per document — §6 design-decision prose and §1-§3 narrative sections read in the same terse voice; no conversational Q&A asides mid-document.

## Section structure (placeholder, to be confirmed against real eng-spec rounds)

```text
Header metadata table
- Epic link
- Product spec link
- Version / scope
- AI feature (YES/NO + 1 line, with link to AI test plan)

Engineering Stakeholders
> Pointer to product-spec.md
- Engineering team table
- Platform team
- Security reviewer (if your compliance profile requires one)

# Engineering Specifications

## 1. Non-functional requirements
1.1. Latency, throughput, scale targets
1.2. Availability and SLOs
1.3. Cost envelope (compute, storage, embedding budget)

## 2. Technical approach
2.1. Architecture diagram (mermaid or link to Figma)
2.2. Algorithm details
2.3. Storage model and schema changes
2.4. Compute placement (sync vs async, where embeddings live)
2.5. Failure modes and degradation behaviour
2.6. Endpoint contracts (request/response/error schemas + caps)
     — required when the spec adds or changes endpoints; one sub-section per
     new endpoint mirroring the same path/query/body/response/error/caps shape,
     plus an `Existing endpoint changes` subsection when the spec modifies
     pre-existing endpoints.

## 3. Test plan
3.1. Unit and integration coverage
3.2. AI test plan (if AI feature)
3.3. Load testing approach and pass criteria
3.4. Canary and rollout plan

## 4. Rollback plan
4.1. Failure indicators (metrics, alerts)
4.2. Rollback procedure (steps + estimated time)
4.3. Data migration reversibility

## 5. Other affected systems (opt-in)
One sub-section per affected system (pipelines, exports, downstream consumers).
Use the read-only-observer framing: state explicitly where the spec's primary
system writes back vs reads only. Table per system: step / surface | action | why.

## 6. Design decisions for engineering approval
One sub-section per choice that diverges from existing patterns and needs platform/EM sign-off:
   - Proposed (V1):  one line
   - Rationale:      2-3 lines
   - Open question for engineering:  yes/no
   - Decision:       filled after sign-off, with approver name
```

## What does NOT belong in the engineering spec

| Section that's tempting to add | Why not | Where it goes |
|---|---|---|
| Problem framing / business value | Product content | product-spec.md §1 |
| User stories | Product content | product-spec.md §2 |
| Adoption KRs, latency-as-product-metric | Product content | product-spec.md §1.4 |
| Implementation step-by-step ticket breakdown | Plan content | `.specto/plan.md` (transient) |

## Anti-patterns to avoid

| Anti-pattern | Why it's bad | Fix |
|---|---|---|
| AI-flavoured prose | Em-dashes, hedge-scaffolding phrases used as pseudo-headers ("Grounding:", "it's worth noting that"), nested parentheticals — reviewers tune out; the spec doesn't say what changes. | Plain English, short sentences. State the architecture, then stop. |
| Prose duplicating diagrams | Reader has to verify two sources agree. | Drop the prose; the diagram is canonical. Caption it instead. |
| Empty open questions | A spec with `Open question: yes` and no specific question wastes the reviewer's time. | Pick one, or write the actual question (single sentence ending in `?`). |
| Product creep | Section 1 reads like a PRD. | Move user-facing content to `product-spec.md`. The eng-spec is for *how*, not *what*. |
| Missing rollback plan | One incident in and you're scrambling to figure it out under pressure. | Every spec ships with §4 populated, even if "not applicable, no data migration". State why. |
| Architecture diagram absent | "Just read the code" doesn't scale to platform reviewers. | Mermaid or Figma link. One diagram beats five paragraphs. |
| AI test plan missing on AI feature | Regression detection is impossible without it. | If `AI feature: YES`, §3.2 must be filled — eval set, accuracy threshold, regression gate. |
| Latency budget hand-waving | "Should be fast" is not a target. | §1.1 names a concrete number per endpoint or pipeline stage. |
| Non-functional requirements buried | Reviewers can't find them; capacity planning misses signals. | §1 is specifically for NFRs; don't scatter latency/cost/SLO mentions across §2 and §3. |
| Storage schema in prose | Schema changes get ambiguous; migrations get risky. | §2.3 is explicit either way — never vague prose. Schema the design *fixes* (a real, load-bearing decision): a literal table or DDL block, index decisions explicit. Under-determined storage: the `*Implementer's choice — must satisfy:*` marker + the constraints and invariants any schema must meet (cardinality, uniqueness, retention, the query patterns it must support). |
| Concrete DDL/code for an under-determined decision | Picks one solution prematurely, makes the spec longer and harder to review, and removes freedom from `implement-ticket` — detail masquerading as decision. | State the acceptance criteria / constraints / invariants under the `*Implementer's choice — must satisfy:*` marker (principle 9). Reserve concrete DDL/code for decisions the design genuinely fixes. |
| Contradicting a nearer `AGENTS.md` convention | A decision (new column/table, new endpoint, config in a new place) reinvents a mechanism the nearest `AGENTS.md`/`CLAUDE.md` already prescribes, caught only in MR review (e.g. an MR adds a per-customer boolean column where the service's `AGENTS.md` prescribes extending the existing `feature_flags` JSON). | Conform to the nearest convention, or add a §6 design decision naming the convention, the divergence, and the rationale. The §6 note is the escape valve; its absence for a divergent decision is the defect. |
| Multi-step flow described in prose | Steps drift between author intent and implementer reading; agents (and humans) disagree on ordering, who calls whom, and what's sync vs async. Same problem when decision or priority logic is written as an inline "(1)...(2)...(3)..." sentence instead of a list. | §2.1 includes a mermaid `sequenceDiagram` whenever the flow has ≥3 actors (services, queues, callers) OR ≥4 steps. Prose summarises the diagram; the diagram is canonical. Decision/priority logic gets a short numbered list or small diagram, not an inline enumerated sentence. |
| One omnibus diagram covering all callers / actors | Reader can't isolate any one flow; the diagram drifts as actors are added; LLM-drafted variants merge everything into a single tangle. | When the architecture spans multiple distinct callers, split into one structural diagram for the shared backend plus per-caller `sequenceDiagram`s. The structural diagram shows components; each sequence diagram shows one caller's flow. |
| Storage relations described in prose | When ≥2 entities relate (FKs, ownership, cardinality), prose hides the shape reviewers must validate. | Add a mermaid `erDiagram` in §2.3 (`references/visual-conventions.md`); the table captions it. Skip only for a single standalone table. |
| State transitions described in prose | A status/state enum's transitions drift between author intent and implementer reading. | Add a mermaid `stateDiagram-v2` in §2.5 when a status/state enum is added or changed. |
| Verbose prose in placeholders | Three-bullet placeholders produce three-bullet boilerplate even when one line would do. | Trim to a single sentence. The `eng-review` agent flags verbosity as a finding. |
| Filling out-of-scope sections | A non-AI feature with three paragraphs of "AI test plan: not applicable, but here's how we'd think about it..." | Use the one-line `*Not applicable — <flag> = <value>*` form. The applicability matrix decides; the writer doesn't get creative. |
| Downstream system impact missing | Pipeline / exports / consumer changes get discovered post-merge as bugs because the spec never enumerated them. | When the change touches systems outside the spec's primary one, populate §5 Other affected systems with one sub-section per affected system and a step/surface/action/why table. Use the read-only-observer pattern: who writes back vs who reads only. |
| Speculative abstraction / unrequested flexibility | An interface with one implementation, config knobs nothing calls for, or scale headroom past §1.1's numbers is complexity paid for a need that doesn't exist yet, and the first thing to cost maintenance time. | Design to what §1 NFRs and the product spec's Must/Should scope require (principle 10). A real future need becomes a named §6 open question, not silent generality. |
| Drafting architectural decisions from product-spec context alone | Product context describes user-facing behaviour; without code-level signal (models, services, flows in dependent repos) the engineering spec rephrases the product spec instead of designing the implementation. | Before drafting §2, identify code-level gaps and hunt the relevant dependent repos with `Grep`/`Glob`/`Bash`. Compiled product-spec context is a starting point, not a substitute. |
| Identifier-chain sentences | A single sentence names 4+ backticked identifiers, reading like a commit diff. | Cap at one identifier per sentence outside tables/code fences; move the sequence into a table or code block. |
| Terminology drift vs. product-spec | Engineering spec names a mechanism differently than the linked product-spec. | Reconcile wording; one canonical term across both docs. |
| Register drift mid-document | A terse decision-record section followed by a casual conversational aside. | Hold one voice for the whole document. |

## Quick checklist before opening the MR

- [ ] Header metadata complete: Epic link, Product spec link, Version / scope, AI feature, and the classification rows when a compliance profile is configured.
- [ ] Linked product-spec.md exists, is in `merged` or `approved` status, and has `## Delivery Stakeholders` populated.
- [ ] §1 NFRs: §1.1 latency has concrete numbers per endpoint; §1.2 SLO and §1.3 cost envelope filled or marked `*Not applicable — <flag>*` per the applicability matrix.
- [ ] §2 architecture has a structural diagram (mermaid in-line or Figma link). When the change involves ≥3 actors or ≥4 steps, §2.1 also includes a mermaid `sequenceDiagram` showing the interaction flow. Storage decisions are explicit (§2.3), with a mermaid `erDiagram` when ≥2 entities relate; §2.5 has a `stateDiagram-v2` when a status/state enum is added or changed. §2.6 endpoint contracts populated when the spec adds or changes endpoints.
- [ ] §3 test plan: §3.1 unit/integration covered (one sentence + link); §3.2 AI test plan filled or marked not-an-AI-feature; §3.3 load testing filled or marked `*Not applicable*` per the matrix; §3.4 canary/rollout always filled.
- [ ] §4 rollback plan: failure indicators, rollback procedure, §4.3 reversibility filled or marked `*Not applicable — no schema changes.*` per the matrix.
- [ ] §5 Other affected systems populated when the change touches systems outside the spec's primary one (pipelines, exports, consumers), or marked `*Not applicable — change is contained to the primary system.*` per the matrix.
- [ ] §6 design decisions follow `Proposed → Rationale → Open question → Decision` pattern. No bare "TODO".
- [ ] Every `*Implementer's choice — must satisfy:*` section states **verifiable** criteria (a test or a `dod` check can decide each one), not vibes — and concrete DDL/code appears only for decisions the design genuinely fixes.
- [ ] No abstraction, config knob, or capacity headroom in §2 that doesn't trace to a §1 NFR or the product spec's Must/Should scope (principle 10). A real future need is a named §6 open question, not silent generality.
- [ ] Each compliance flag answered *Yes* is reflected in stakeholders + rollback rigor per your profile's rigor list (typically: a security flag implies a security reviewer + audit trail; an availability flag a platform reviewer + canary; a data flag a data-platform reviewer + reversibility plan).
- [ ] Zero em-dashes (`—`); zero `:product:`/`:engineering:` emoji codes in headers.
- [ ] No content that belongs in `product-spec.md` (no user stories, no business rationale, no adoption KRs).
- [ ] No sentence chains 3+ backticked identifiers outside a table/code fence
- [ ] Terminology matches product-spec.md for any shared mechanism name
- [ ] One voice held throughout — no casual asides breaking the decision-record tone
