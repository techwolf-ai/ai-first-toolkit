---
name: reconcile-spec
description: Use when a spec has drifted from what actually shipped — decisions written as "Proposed / deferred / Open question" that are now settled in code, NFR numbers that were guesses and are now measured, or won't-haves that quietly shipped. Triggers on "reconcile the spec", "update the spec to what shipped", "the spec is stale", "sync spec with the code", "fix spec drift". Diffs the in-repo spec against shipped code + merged MRs and proposes a rewrite to reality, keeping product (what/why) and engineering (how) content in their own files. Advisory-first — never rewrites the spec without the author's approval.
---

# reconcile-spec

Close the living-spec loop: an in-repo spec is only a source of truth if it reflects what shipped. This skill finds where the spec still says "we plan to / it is undecided / we will not" while the code says otherwise, and proposes a rewrite so the spec reads as the record of what was built — not the guess made before building.

It is **advisory-first**: it produces a reconciliation plan you approve section by section. It never rewrites the spec or edits the tracker on its own.

## Prerequisite check

- A spec folder is identifiable (the user names it, or the most-recently-edited `engineering-spec.md` / `product-spec.md` under `docs/development/specs/`).
- There is shipped work to reconcile against — at least one of: merged MRs for the linked epic, the tickets the spec's plan produced, or a range of commits the user points at. If nothing has shipped, say so and stop — there is nothing to reconcile yet.

## What counts as drift

Look for these in the current spec, then check each against shipped reality:

- **Provisional decisions.** `Proposed:` rows with a blank `Decision:`, `TODO(product-approval)` / `TODO(eng-approval)` markers, `Open question for product/engineering:` lines — that the merged code has since settled.
- **Guessed NFRs.** Latency / throughput / cost targets written as estimates in `engineering-spec.md` §1 that load testing or production has since measured.
- **Scope reality.** Won't-haves (product §2) that actually shipped, or Must-haves that were cut. Endpoints in product §3.2 / engineering §2.6 that changed shape.
- **Architecture reality.** §2 technical-approach decisions (storage model, placement, algorithm) that the implementation diverged from, with the divergence visible in the merged diff.

## Steps

1. **Resolve inputs.** Spec folder; the linked epic (from `.specto-meta.yml`); the shipped surface — merged MRs (via `scripts/forge/mr-fetch.sh` for each, or the forge CLI's merged-MR listing: `glab mr list --state merged` (GitLab) / `gh pr list --state merged` (GitHub), filtered to the epic's branches) and/or a commit range the user gives. Read `product-spec.md` and `engineering-spec.md` in full.
2. **Collect drift candidates.** Enumerate the provisional/guessed/scope/architecture items above, each with its spec location (`§<section>`, file) and the exact current text.
3. **Match each to shipped reality.** For each candidate, find the evidence in the merged diffs / code (the DDL that landed, the endpoint contract that shipped, the measured number, the feature that did/didn't ship). Where there is no evidence, mark it `unresolved — still open` rather than guessing.
4. **Draft the reconciliation, respecting the split.** For each resolved item, write the replacement text. **Product-level facts (scope, user-visible behaviour, value) go in `product-spec.md`; engineering-level facts (schema, contracts, NFR numbers, architecture) go in `engineering-spec.md`.** A shipped storage decision updates engineering §2.3, never product §3. Turn `Proposed → Decision (shipped): <what landed>, per !<MR>` (`!<MR>` on GitLab, `#<PR>` on GitHub); replace guessed NFRs with measured ones and cite the source; move a shipped won't-have into the Must/Should table with a note.
5. **Present the plan for approval.** One block per item: location, current text, proposed text, evidence (`!<MR>` / file:line / measurement). The author approves, edits, or rejects each. Only on explicit approval do you apply the edits with `Edit`.
6. **Flag downstream ticket impact.** When a reconciled decision changes an AC that a tracker ticket already carries, list the affected tickets (match by their `> Spec section:` link) and recommend running `plan-to-tickets` in dry-run to re-sync them — do not edit the tracker here.

## Hard rules

- **Advisory-first.** Never rewrite the spec or touch the tracker without per-item approval. This mirrors `resolve-spec-comments`.
- **Evidence or `unresolved`.** Every rewrite cites the merged MR / commit / measurement it reflects. No evidence → leave the item open and say so; do not invent a resolution.
- **Respect the product/eng split.** A fact's home is decided by its kind, not by where the stale text happened to live. Move it to the right file if the drift put it in the wrong one.
- **Terse, factual rewrites.** The reconciled text follows the spec guidelines (no AI-flavoured prose, one source of truth per fact). Decisions state what shipped and cite the MR; deliberation stays out.

## When this skill should NOT run

- Before anything has shipped — there is nothing to reconcile (use `resolve-spec-comments` for pre-merge review feedback instead).
- To *author* a new spec (`new-spec`) or to review one (`review-spec`).
