> **Exemplar.** Fully synthetic. Orbit CRM is a fictional product; every name, key, and link is invented. Use as a structural reference, not a literal copy.

| | |
|---|---|
| **Epic link** | [CRM-2048](https://example.atlassian.net/browse/CRM-2048) |
| **AI feature** *(Does this introduce a new AI feature or significantly change an existing AI feature?)* | YES. Embedding-based contact similarity is a new AI capability. The AI test plan (eval set, precision threshold, regression gate) lives in the engineering spec. |
| **Product opportunity** | [OPP-112](https://example.atlassian.net/browse/OPP-112) |
| **Version / scope** | V1 |

## Delivery Stakeholders

> This file is the **product specification**. The engineering specification lives in [engineering-spec.md](engineering-spec.md) and has its own stakeholder table for engineering, platform, and security reviewers.

| Representing / SME  | Representative | ✓ / ✗ |
| ------------------- | -------------- | ----- |
| Product manager     | @alex.rivera   |       |
| Engineering manager | @sam.okafor    |       |
| Engineering team    | @jordan.lee    |       |
| Engineering team    | @casey.kim     |       |
| Platform team       | @riley.novak   |       |
| PS                  |                |       |

---

# Product Specifications

> **V1 scope:** duplicate detection for standard contact records only. Custom-object dedup (accounts and custom-schema objects) is a separate V2 milestone.

## 1. What value does this bring?

### 1.1. Problem

Duplicate contacts fragment a customer's data. When the same person exists as two records, their activity history splits across both, routing sends them to different reps, and reports double-count them. Today Orbit CRM only catches exact-match duplicates (identical email or identical name plus phone); fuzzy duplicates (a typo, a nickname, a changed email) slip through and accumulate.

This matters because the fuzzy duplicates are the ones that cause visible damage, and admins currently have no way to find them at scale.

- A rep opens a contact and sees only half the activity history; the rest lives on the duplicate.
- Marketing double-sends a campaign because the two records both match the audience filter.
- Territory routing assigns the two records to different reps, who then both work the same account.
- Admins spend hours each month hunting duplicates by eye and merging them one at a time.

### 1.2. Solution

Introduce a symmetric similarity score (0 to 1) between two contact records, computed from field embeddings rather than exact-match rules. The score powers three surfaces: an on-demand API for the routing engine and integrations, a merge-suggestion queue that admins review in the UI, and a nightly export for bulk cleanup.

The score is exposed through four endpoints and one nightly export. Merges are never automatic; every suggestion is confirmed by an admin.

### 1.3. Objectives

The objectives below are the conditions under which we'd call duplicate detection "done and worth having shipped." They are not OKR rows; they are the roadmap-item-level outcomes that contribute to the OKRs tracked in the repo's `.specto/okrs.md`.

| # | Objective | Customer / segment | OKR |
| - | --------- | ------------------ | --- |
| 1 | Expose contact similarity scoring via the CRM API so admins and the routing engine can act on fuzzy duplicates | Tenants with large contact books | O2.KR1 |
| 2 | Cut duplicate-driven routing and reporting errors for tenants running cleanup | Tenants piloting dedup | O2.KR3 |
| 3 | Ship the merge-suggestion queue as part of the data-hygiene product line | Tenants consuming the cleanup tools | O5.KR2 |

### 1.4. Key results / metrics

*≤5 metrics, each directly controllable by this feature.*

| Metric | Threshold | Why this matters |
| ------ | --------- | ---------------- |
| Adoption: distinct tenants enabling dedup within 30 days of GA | ≥ *(proposed: 8)* | The feature only delivers value if tenants turn it on. |
| Precision@10 vs the labelled duplicate-pair set | ≥ 0.9 | Low precision trains admins to ignore the queue; high precision keeps suggestions trustworthy. |
| API latency: p99 for the single-pair endpoint | ≤ 300ms | The routing engine calls this inline; it must not be a bottleneck. |
| False-merge rate on confirmed suggestions | ≤ 0.5% | A wrong merge destroys history; a false merge costs far more than a missed one. |

## 2. User stories

**Must haves**

| User story | In scope |
| ---------- | -------- |
| As the routing engine, I want the similarity score between two contacts, so that I don't assign duplicates to different reps. | ✓ |
| As an admin, I want the top matching contacts for a given contact, so that I can review and merge duplicates in one place. | ✓ |
| As an admin, I want a queue of high-confidence duplicate pairs, so that I can clear the backlog without hunting for them. | ✓ |
| As a caller, I want to filter top-N matches (by owner, region, custom field), so that I can scope cleanup to one book of business. | ✓ |

**Should haves**

| User story | In scope |
| ---------- | -------- |
| As an integration, I want to score an ad-hoc pair of records supplied inline, so that I can check for a duplicate before creating a contact. | ✓ |
| As an admin, I want a nightly export of duplicate pairs, so that I can run bulk cleanup outside the UI. | ✓ |

**Won't haves** *(every row needs a Reason)*

| User story | Reason |
| ---------- | ------ |
| Cross-object dedup (accounts, custom objects) | V2 milestone; depends on the custom-object schema work landing first. |
| Auto-merge without human confirmation | A wrong merge is unrecoverable, so V1 always routes merges through admin review. Governance requires a human in the loop. |
| Caller-supplied per-field weights | Built-in field weighting covers the piloted use cases; defer until a tenant asks. |
| Real-time streaming dedup on every write | The nightly batch and on-demand endpoints cover the use cases at a fraction of the compute cost. |

## 3. Functional requirements

### 3.1. Inputs

| Input | Source | Notes |
| ----- | ------ | ----- |
| Contact records | CRM core store | Standard contact fields only. Custom-object records are out of V1 scope (see §2 Won't-haves). |
| Field embeddings | Embedding service, computed at contact write time | One embedding per contact, stored on create or update. Never recomputed at match time (see §4.1). |
| Tenant merge history | CRM core store | Prior confirmed and rejected merges; used to suppress already-decided pairs from the queue. |
| Activity counts per contact | Activity service | Used to rank which record in a pair is the likely survivor of a merge. |

### 3.2. Endpoints

*Endpoint names and one-line customer-visible behaviour each. Path/query/body/response/error tables and caps live in [engineering-spec.md §2.6](engineering-spec.md); do NOT duplicate them here.*

| Endpoint | Customer-visible behaviour | Priority |
| -------- | -------------------------- | -------- |
| `GET /contacts/{id}/contacts/{other_id}/similarity` | Returns the 0-1 similarity score for one pair of contacts. | Must-have |
| `POST /contacts/{id}/matching_contacts` | Returns the top-N most similar contacts to a given contact, with optional filters. | Must-have |
| `GET /merge_suggestions` | Returns the queued high-confidence duplicate pairs awaiting admin review. | Must-have |
| `POST /contacts/similarity` | Scores an ad-hoc pair of contact records supplied inline, not tied to stored IDs. | Should-have |

**Precedent endpoints.** Mirror Orbit's existing exact-match dedupe surface so naming stays aligned:

- Single-pair similarity mirrors the exact-match `Contact Duplicate Check` endpoint (path shape and echoed id fields).
- Top-N matching mirrors the `Matching Records` list endpoint (limit, offset, and filter semantics).
- The merge-suggestion queue mirrors the `Cleanup Queue` list surface used by the exact-match cleanup tool.
- The ad-hoc pair endpoint has no precedent; it is a new set-vs-set primitive.

### 3.3. Exports

*Export names and one-line description each. Schema and caps live in [engineering-spec.md §2.6](engineering-spec.md).*

| Export | Description (source, cadence, caller use case) |
| ------ | ---------------------------------------------- |
| Duplicate-pairs matrix (CSV) | Top duplicate pairs per contact from the nightly dedup run; feeds bulk admin cleanup. Precedent: the exact-match `duplicate_report` export. |

## 4. Design decisions for product approval

*Choices that need product sign-off before engineering locks the implementation.*

### 4.1. Match on raw records, not normalized golden records

- **Proposed (V1):** score similarity on the raw contact records tenants see and edit, not on an internally normalized "golden" representation.
- **Rationale:** keeps a single source of truth (no parallel golden representation to reconcile), and merge suggestions point at the records admins recognize.
- **Caveat:** the prototype that validated match quality and the similarity floor ran on **normalized** records. Switching to raw means the quality benchmarks need re-validation against raw-record data before V1 locks; raw records carry more field noise and a different score distribution.
- **Open question for product:** none; confirming the raw-record decision.
- **Decision (V1):** raw records. Approved by @alex.rivera (the scalability concern is noted and tracked via the engineering spec).

### 4.2. Exact-match dedupe vs similarity dedupe

- **Proposed (V1):** ship similarity dedupe alongside the existing exact-match dedupe rather than replacing it. Exact-match stays the cheap first pass; similarity catches the fuzzy duplicates it misses. *Symmetric = one score per pair, direction-independent; rule-based = a fixed set of field-equality rules.*

  | Dimension | Exact-match (today) | Similarity (V1, proposed) |
  | --------- | ------------------- | ------------------------- |
  | Matching shape | Rule-based field equality | Symmetric 0-1 score per pair |
  | Weighting | All-or-nothing per rule | Weighted by field importance (built-in) |
  | Custom fields | Ignored unless a rule names them | Contribute to the score by default |
  | Explanation shape | Which rule fired | Not in V1 (V2 candidate: per-field contribution) |
  | Governance scope | Global rule set | Per-tenant `dedup_scope` setting (see §4.3) |

- **Open question for product:** none.
- **Decision (V1):** differences accepted by product (@alex.rivera). Similarity does not need to match exact-match behaviour dimension for dimension.

### 4.3. Per-tenant dedup scope setting

- **Proposed (V1):** add a per-tenant `dedup_scope` setting with values `active_only` (default) or `include_archived`.
- **Rationale:** most tenants only want to dedup active records; some want archived contacts considered so a reactivated duplicate is caught. Default `active_only` keeps the queue small and the compute bounded.
- **Open question for product:** none; confirming the default and the two values.
- **Decision (V1):** add `dedup_scope`, default `active_only`. Engineering estimate ~1 developer week. Approved by @sam.okafor and @jordan.lee.

## 5. Rollout & Adoption

### 5.1. Customer demand

| Customer | What they asked for | Source (link) |
| -------- | ------------------- | ------------- |
| Customer A | Merge suggestions for the fuzzy duplicates their exact-match rules miss | Support ticket #4821 |
| Customer B | A nightly duplicate report to hand their ops team for bulk cleanup | Q2 QBR note (account file) |

### 5.2. Pilot stakeholders

| Side | Role | Name |
| ---- | ---- | ---- |
| Vendor | Product owner | @alex.rivera |
| Vendor | Solutions engineer | @riley.novak |
| Customer | Champion | Customer A ops lead |

**Pilot success criteria:** ≥ 2 of 3 piloted tenants clear their duplicate backlog and keep the queue enabled after 2 weeks, with the false-merge rate under the §1.4 threshold.

### 5.3. Rollout cadence

| Phase | Scope | Gate to next phase |
| ----- | ----- | ------------------ |
| Pilot | 3 tenants; dedup endpoints and queue behind a flag | Precision@10 ≥ 0.9 on the pilot tenants' labelled pairs (§1.4) |
| GA    | All tenants, opt-in per tenant | 30-day monitoring window: false-merge rate ≤ 0.5% and no P1 incidents |

### 5.4. Adoption goals

≥ 8 distinct tenants with dedup enabled and the merge queue in active use within 30 days of GA. Source-of-truth: §1.4 row 1.
