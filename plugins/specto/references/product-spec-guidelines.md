# What a good product spec looks like

Distilled from real spec-review rounds: recurring reviewer findings, promoted into rules.

## Core principles

1. **Audience: PM + EM, not engineers.** The product spec is for stakeholders who decide *what* and *why*. Engineering decisions go in `engineering-spec.md`. If a section describes implementation, storage, or algorithms, it belongs in the engineering spec.

2. **Direct, terse, evidence-driven.** No marketing language, no rhetorical filler. State the decision, the rationale, the open question. Stop.

3. **One source of truth per fact.** If a value (endpoint URL, schema column, decision) appears twice, the second mention should be a reference, not a duplicate.

4. **Decisions in the spec, deliberation in MR comments.** Pick one option with a rationale. Add an `Open question for product:` line if you need sign-off, but don't litigate alternatives in the spec body.

5. **Cross-reference your platform's precedent feature wherever a parallel exists.** When your product already ships an analogous surface (matching, exports, suggestions, governance), mirror its naming and shapes; alignment removes a class of review comments before they happen.

## Style rules

- **No "in scope for this version" filler in Won't-haves.** Every Won't-have row needs a real reason (technical, scope, prior art).
- **Inline guidance over sprawling prose.** Where the spec template provides slots ("Key results / metrics"), add a one-line guardrail to the section header (e.g. "≤5 metrics, each directly controllable") so future writers stay disciplined.
- **Use blockquotes (`>`) for callouts that bridge sections.** E.g. the `engineering-spec.md` pointer at the top of stakeholders, or scope-version statements.
- **One canonical term per concept.** If product-spec.md and engineering-spec.md name the same mechanism, use the identical term in both — a name that drifts (e.g. "fine-tune" in one, "not fine-tuning" in the other) reads as a contradiction, not a paraphrase.
- **One parenthetical per sentence.** A second aside gets its own sentence.
- **One register per document.** Pick a tone (terse/decision-record) and hold it — don't drift into conversational asides mid-document.
- **Don't bold every noun phrase in a list.** Bold the one term per bullet a skimming reader needs; if everything is bold, nothing is emphasized.

## Section structure

```
Header metadata table
- Epic link
- Product opportunity ticket (optional)
- Version / scope (V1, V2, ...)
- AI feature (YES/NO + 1 line)

Delivery Stakeholders
> Pointer to engineering-spec.md
- Single product-stakeholder table (PM, EM, Eng team, plus platform/support roles your org uses).
  Engineering / platform / security reviewers approve the eng-spec separately.

# Product Specifications

## 1. Value
1.1. Problem        — paragraphs + bulleted use cases
1.2. Solution       — high-level: what changes for the customer
1.3. Objectives     — table: # | Objective | Customer | OKR
1.4. KRs / metrics  — ≤5 metrics, each directly controllable
                       (drop north-star outcomes the feature can't move)

## 2. User stories
Must / Should / Could / Won't
- Won't-haves require a Reason column
- Skip empty buckets (don't carry an empty Could-haves table)

## 3. Functional requirements
3.1. Inputs         — table: Input | Source | Notes
                       (no "Required" column; everything's required)
3.2. Endpoints      — list of endpoint *names* + one-line customer-visible
                       behaviour each (e.g. "GET /contacts/{id}/duplicates:
                       returns the top-N likely duplicate contacts for a record"). Path
                       params, query params, request/response shapes, error
                       responses, and caps are NOT in the product spec — they
                       live in engineering-spec.md §2.6 (Endpoint contracts).
3.3. Exports        — list of export *names* + one-line description (source,
                       cadence, caller use case). Schema, caps, and the
                       precedent-feature equivalent are in engineering-spec.md §2.6.

## 4. Design decisions for product approval
One sub-section per choice that diverges from existing patterns and needs PM/EM sign-off:
   - Proposed (V1):  one line
   - Rationale:      2-3 lines
   - Open question for product:  yes/no
   - Decision:       filled after sign-off, with approver name

## 5. Rollout & Adoption
5.1. Customer demand    — which customers asked for this; concrete examples
                           (Customer A: ..., Customer B: ...). Distinguish
                           "asked for X" from "would benefit from X".
5.2. Pilot stakeholders — which customer(s) you're piloting with; internal
                           partner(s) (solutions / support); success criteria for
                           the pilot (what would make us roll out vs. iterate).
5.3. Rollout cadence    — pilot → general availability path; gating signals
                           between phases (KR thresholds, SLO health, customer
                           sign-off).
5.4. Adoption goals     — link back to §1.4 metrics; one-line statement of
                           what "adopted" means for V1 (e.g. "≥ 6 distinct
                           tenants calling the endpoint within 30 days of GA").
```

## What does NOT belong in the product spec

| Section that's tempting to add | Why not | Where it goes |
|---|---|---|
| Implementation steps / phasing | Engineering content | engineering-spec.md §2 |
| Algorithm details | Engineering content | engineering-spec.md §2 |
| Storage / database schema | Engineering content | engineering-spec.md §2 |
| Performance & scalability NFRs | Engineering content | engineering-spec.md §1 |
| Endpoint request/response shapes, params, error codes, caps | Engineering content (a recurring review finding) | engineering-spec.md §2.6 |
| Export schemas + caps | Engineering content | engineering-spec.md §2.6 |
| Test plan | Engineering content | engineering-spec.md §3 |
| Rollback plan | Engineering content | engineering-spec.md §4 |
| §1.5 Users (if it would be a 4-bullet list) | Doesn't add value | Drop or fold into §1.1 |
| "X is implemented as a wrapper over Y" type notes | Engineering detail | engineering-spec.md |

## Per-section guidance

### Header metadata

Always fill all four (Epic, Product opportunity, Version, AI feature). Don't ship with `(TBD)`, either fill or drop the row.

### Stakeholders

- **Opt-in, not mandatory.** The Delivery Stakeholders table and §1.3 Objectives (OKRs) are worth the weight on a real initiative but overkill for a small change. Fill them when the work ties to a KR or needs named approvers; drop them (don't leave `<placeholder>` rows) when it doesn't. The lint does not require either section.
- The product-spec stakeholder table covers approvers of *this* spec only: PM, EM, Eng team, plus platform/support roles your org uses.
- Engineering / platform / security reviewers of the *engineering* spec live in `engineering-spec.md`'s own stakeholder table; do not duplicate them here.
- Engineering spec is a separate file (`engineering-spec.md`); state this explicitly in a callout.

### §1.4 Key results / metrics

- ≤5 metrics. Each metric must be directly controllable by this feature.
- Drop "north star" outcomes (e.g. "X customers signed off") that depend on more than this feature can move alone.
- Adoption + latency + accuracy is usually enough. Anything else needs a strong case.

### §2 User stories

- Each row's user story follows: *"As [role], I want [action], so that [outcome]."*
- Won't-haves are not optional. Every spec ships with explicit out-of-scope items, each with a Reason.
- Empty MoSCoW buckets get dropped, not left as empty tables.

### §3 Functional requirements

- §3.1 is **what data flows in** (sources). Not column-by-column DB schema.
- §3.2 is **endpoint names + customer-visible behaviour**. One line per endpoint, e.g. "`GET /contacts/{id}/duplicates`: returns the top-N likely duplicate contacts for a record, with optional filters." Path params, query params, request/response shapes, error responses, and caps live in engineering-spec.md §2.6 — do NOT duplicate them here.
- §3.3 is **export names + one-line description** (source, cadence, caller use case). Schema, caps, and the precedent-feature equivalent live in engineering-spec.md §2.6.
- The "precedent-feature equivalent" column belongs on the engineering-spec contract tables (§2.6), not on the product-spec endpoint list.

### §4 Design decisions

- Surface choices that diverge from existing patterns, not those that follow them.
- Each decision: Proposed → Rationale → Open question → Decision (filled after sign-off, with approver).
- The "Decision" row is the contract: once filled, future readers see the locked answer, not an open debate.
- Engineering decisions go in engineering-spec.md §5 with the same pattern; do not pull them into product-spec §4.

### §5 Rollout & Adoption

- §5 makes the spec accountable for *whether the feature lands with users*, not just whether it ships.
- §5.1 names real customers — "Customer A asked for X in Slack thread Y on date Z" — not generic "customers want this".
- §5.2 is a project commitment: at least one named pilot stakeholder per side (one internal partner + one customer-side champion). Empty here = the rollout hasn't been planned.
- §5.3 is the gating signal between pilot and GA. Pick one or two concrete metrics from §1.4 and a threshold value. When the rollout has ≥2 phases, add a mermaid `timeline` (see `references/visual-conventions.md`); the phase/gate table stays canonical, the timeline captions it.
- §5.4 closes the loop with §1.4: the adoption goal is an instantiation of one §1.4 metric with a deadline.

Diagram conventions (which mermaid form, the dark-mode palette, validate-before-write) live in `references/visual-conventions.md`. §1.2 may carry a customer-journey `flowchart` when the solution is a multi-step user flow; keep it to customer-visible steps, never implementation (that belongs in `engineering-spec.md`).

## Anti-patterns to avoid

| Anti-pattern | What it looks like | Fix |
|---|---|---|
| **AI-flavoured prose** | Em-dashes everywhere, "this elegant solution leverages...", "robust", hedge-scaffolding phrases used as pseudo-headers ("Grounding:", "it's worth noting that"), nested parentheticals | Strip. Use plain English, short sentences. |
| **Prose duplicating tables** | A paragraph that summarises what the table below already says | Drop the paragraph, let the table speak. |
| **Empty open questions** | "Open question: do we ship this?" with no actual decision needed | Either pick one, or specify the actual question. |
| **Engineering creep** | A `§4 Technical approach` in the product spec | Move to engineering-spec.md. The product spec ends at §3 Functional requirements + §4 Design decisions. |
| **Stale "scope" callouts** | A V1 banner that says nothing the Won't-haves table doesn't already convey | Either tighten to a one-liner with V2 split, or drop. |
| **Missing reasons in Won't-haves** | Bullets without a Reason column | Always include the Reason. It's why the row exists. |
| **`category=foo` style query-param overloads** | `?category=tasks` to disambiguate two operations | Prefer dedicated paths or distinct endpoint names. The reader shouldn't need to read the query string to know what the endpoint does. |
| **Single-spec-sheet for multiple deliverables** | One spec covering V1, V2, and a different but related feature | Split into separate sequential spec sheets, link forward. |
| **Terminology drift** | Same mechanism named differently in product-spec vs. engineering-spec | Pick one term, use it identically in both docs. |
| **Code/identifier leakage** | An MR number, class name, or file path dropped into product-spec prose | Name the concept only; put the identifier in engineering-spec.md or decision-record.md. |
| **No diagram for a multi-part system** | §1.2 Solution describes 3+ interacting pieces as bulleted prose, no picture | Add a simplified diagram — full architecture detail stays in engineering-spec.md, but the shape belongs in both. |
| **Multi-step user flow buried in prose** | Three paragraphs walking through what the customer clicks, in order | A mermaid `flowchart` of the journey in §1.2 (`visual-conventions.md`); prose captions it. Customer-visible steps only. |
| **Implementation detail in a §1.2 diagram** | A journey diagram showing services, tables, or internal calls | Strip to customer-visible steps; the system flow belongs in `engineering-spec.md` §2.1. |

## When to mirror an existing API surface explicitly

If your feature touches matching, suggestions, exports, governance, or any concept your platform already exposes:

1. **Find the closest existing endpoint or export.** Link to it.
2. **Mirror the URL shape.** `/<owner>/{id}/<other>/{id}/<verb>` for single-pair, `/<owner>/{id}/matching_<plural>` for top-N.
3. **Mirror the request shape.** Reuse the existing filter schema, plus the same `<score_threshold>`, `limit`, `offset`, `include` parameters.
4. **Mirror the response shape.** Use the same field names where the concept maps (`<entity>_id`, `target_<entity>_id`, `score`, `status`).
5. **Document any divergence inline.** State explicitly which dimensions differ from the precedent (e.g. "no caller-supplied `weights` in V1") and why.

## Quick checklist before opening the MR

- [ ] All four metadata rows filled (Epic, Product opportunity, Version, AI feature)
- [ ] Stakeholder table includes every role your org requires
- [ ] §1.4 has ≤5 metrics, each directly controllable
- [ ] §1.5 Users dropped (or actually says something useful)
- [ ] User-stories §2 has Won't-haves, each with a Reason
- [ ] §3.2 lists endpoint *names* + one-line customer-visible behaviour each (no path/query/body/response/error tables; those live in engineering-spec.md §2.6)
- [ ] §3.3 lists export *names* + one-line description (no schema/caps tables; those live in engineering-spec.md §2.6)
- [ ] §4 design decisions follow the Proposed → Rationale → Open question → Decision pattern
- [ ] §5 rollout & adoption populated: pilot stakeholders named, success criteria stated
- [ ] No `§ Technical approach` / `Implementation steps` / `Test plan` sections (those are engineering-spec)
- [ ] No file paths, class/method names, or MR numbers inline in prose
- [ ] Terminology matches engineering-spec.md for any shared mechanism name
- [ ] §1.2 Solution has a simple diagram if it describes 3+ interacting pieces
