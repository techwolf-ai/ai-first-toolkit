---
name: resolve-spec-comments
description: Use when the spec merge request (MR) / pull request (PR) has accumulated review threads and the author wants a structured revision plan. Triggers on "address the MR threads", "resolve spec comments", "what do reviewers want", "process the spec feedback". Reads unresolved threads via the forge CLI (`glab`/`gh`), clusters by section + topic + author overlap, classifies into 7 buckets, produces a revision plan in chat. Advisory only — never resolves threads or edits the spec without explicit user ask.
---

# resolve-spec-comments

Read unresolved review threads on an open spec MR, cluster them by spec section + topic + author overlap, classify each cluster, and produce a revision plan the author executes selectively.

## Prerequisite check

- An open MR exists on the forge for the current branch (`"${CLAUDE_PLUGIN_ROOT}/scripts/forge/mr-fetch.sh" info` exits 0; exit 3 means no MR — wrong skill state).
- The MR touches at least one file under `docs/development/specs/` (otherwise this is the wrong skill).
- The forge CLI (`glab`/`gh`) is on PATH.

## Inputs the user provides

- **`--update-decisions`** (optional flag). When supplied, additionally scan resolved threads since the last spec edit and propose updates to the spec's `Decision (V1):` rows as a diff (no auto-apply).
- **`--draft-reply <cluster-id>`** (optional). When supplied, draft a reply for the named cluster but print to chat (do not post). User says "post it" to actually post via `"${CLAUDE_PLUGIN_ROOT}/scripts/forge/mr-reply.sh" --discussion <thread-id> <body-file|-> --no-resolve` (advisory replies never resolve human spec threads).
- **`--apply`** (optional flag). The single, explicit, scoped exception to advisory-only mode: apply the drafted `style-nit` diffs to the spec file and resolve those specific bot threads. Nothing else is auto-applied — see [`--apply` mode](#--apply-mode).
- **`--close-addressed`** (optional flag, #41). After the author has pushed fixes, map each addressed thread to the commit that resolved it (by section + the pushed diff) and offer, **per thread**, to post an `addressed in <sha>` reply and resolve it via `scripts/forge/mr-reply.sh` (reply + resolve, or `--resolve-only` for a silent close). Closes the gap where fixes ship but reviewers never see the threads acknowledged — the author otherwise has to ask "did we react to the comments?". Opt-in and per-thread confirmed; advisory-only stays the default.

## Steps the skill executes

1. **Fetch unresolved threads** via the shared helper (single read path, `--paginate` under the hood):
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/forge/mr-fetch.sh" discussions
   ```
   Filter to threads where any note has `resolved: false`.

2. **Map line → section header.** For each thread's `position.new_line`, look up the nearest `^##` or `^###` header in the spec file at that revision. The revision plan reads "§1.4 KR thresholds" not "line 47" — section headers are stable across edits, line numbers aren't.

3. **Cluster the threads.** Group by:
   - Same spec section.
   - Topical overlap (similar words in the comment bodies; cheap text similarity is fine).
   - Author overlap is a *signal* (5 reviewers on the same line → 1 cluster) but not a hard rule.

   Aim for 3–10 clusters across a typical 20–50 thread MR. Don't over-cluster (separate concerns get separate buckets); don't under-cluster (5 threads on the same em-dash → 1 cluster).

4. **Classify each cluster** into exactly one bucket. Apply the tests in order — first match wins: **bug** (factual error in the spec) → **style-nit** (pure formatting: em-dash / emoji / style) → **out-of-scope** (wants work beyond this version) → **decision-request** (needs PM/EM sign-off) → **question** (asks a question) → **disagreement** (pushes back on a choice) → **suggestion** (a concrete edit).

   | Bucket | What it looks like | What the author does |
   |---|---|---|
   | `suggestion` | Concrete edit ("change X to Y"). | Apply, or push back with rationale. |
   | `question` | Asks for clarification. | Answer + reply. |
   | `decision-request` | Needs PM/EM sign-off. | Escalate; fill the spec's Decision row when resolved. |
   | `disagreement` | Pushback on a choice. | Litigate or accept. |
   | `style-nit` | Em-dash / emoji code / formatting. | Lint pre-pass should have caught these; mechanical fix. |
   | `out-of-scope` | Wants V2 work. | Defer; offer to add to the spec folder's `v2-candidates.md`. |
   | `bug` | Factual error in the spec. | Fix. |

   Reviewer-agent threads (prefixed `[specto:<agent-name>#<sha8>]`) cluster separately from human threads — bot suggestions are batched. Cluster on the `[specto:<agent-name>` prefix; additionally key on the `#<sha8>` per-finding hash so that when `review-spec` is re-run (it edits findings in place rather than re-posting), the same finding collapses onto one cluster instead of spawning a duplicate.

5. **Ticket-impact lookup (optional).** For each cluster touching a section that's referenced by an open tracker ticket (via the V0.5 `Spec section: <link>` ticket-description prefix), flag: *"this cluster affects §3.2, which is referenced by APP-1234, APP-1235."* On Jira, use `acli jira workitem search --jql "project = APP AND text ~ '<spec-section-anchor>'"` if available (no vetted cross-backend verb covers free-text search yet). If unavailable, skip silently.

6. **Render the revision plan to chat.** One block per cluster:

   ```text
   ## Cluster <N>: <section> (<thread count> threads, <classification>)
   Threads:    <list of thread permalinks>
   Authors:    <author handles>
   Crux:       <one-line summary>

   Recommended action:
     - <action 1>
     - <action 2>
   ```

7. **Offer follow-up actions** at the end of the plan:
   - For `out-of-scope` clusters: offer to write each as an entry in the spec folder's `v2-candidates.md` — `<spec-folder>/v2-candidates.md`, alongside `product-spec.md` (the skill already knows the spec folder from the file the MR touches). Deferred scope belongs with the spec that deferred it, not in a repo-global file. One section per cluster. Format:
     ```markdown
     ## <slug from cluster crux>

     Source: MR !<iid>, threads <ids>.
     Authors: <handles>.

     Crux: <cluster crux>.

     Status: deferred from <YYYY-MM-DD>.
     ```
   - For `decision-request` clusters: offer to draft the corresponding `Decision (V1):` row update as a diff against the spec.
   - For `style-nit` clusters: offer to *draft* the mechanical fix as a diff for the user to review. Default mode never applies it — applying the diff (and resolving the corresponding bot threads) happens only under `--apply` (see below).
   - For any specific cluster: offer to draft a reply for paste (or, on explicit user say-so, post via `"${CLAUDE_PLUGIN_ROOT}/scripts/forge/mr-reply.sh" --discussion <thread-id> <body-file|-> --no-resolve` — reply only, never resolve the human thread).
   - **Recompile stale compiled context.** For `question` clusters whose resolution required pulling new files into `context/raw/` (research asks like *"collect raw context on X"* or *"cross-check our internal docs"*): the related `context/compiled/*.md` topical docs were compiled before that raw material existed and now lie. Identify the compiled doc(s) that reference adjacent raw files and offer to recompile them — either invoke `specto:synthesize-context` scoped to those topics, or edit them in place. Without this the author closes the thread pointing at the new raw file while the compiled doc stays stale. As a backstop: if **any** new file landed under `context/raw/` during this skill run, ask the user whether `context/compiled/*.md` needs a refresh before the threads are closed.

## `--update-decisions` mode

When this flag is supplied:

1. Find resolved threads since the most recent commit on the spec file (use `git log --since` style heuristic on the resolved-at timestamps).
2. For each resolved thread that touched a section with a `Decision (V1):` row, propose an update with:
   - The decision value (inferred from the resolution thread's final note).
   - The approver (the author of the final note that resolved the thread).
   - The date (resolved-at).
3. Print as a diff against the spec; never auto-apply.

## `--apply` mode

The one explicit, scoped exception to advisory-only behaviour. When the user invokes `resolve-spec-comments --apply`, the skill *may*:

1. **Apply the drafted `style-nit` diffs** to the spec file — and only the `style-nit` clusters. The mechanical fix is the one the skill would otherwise have merely drafted in step 7.
2. **Resolve those specific threads** — the bot threads behind the applied `style-nit` clusters, and *only* those. This goes through the same idempotency layer used for posting: resolving a `[specto:<agent-name>#<sha8>]` bot thread is fine to batch; human threads are **never** auto-resolved, even under `--apply`.

Everything else still produces drafts/plans only — `decision-request`, `disagreement`, `out-of-scope`, and `bug` clusters are never auto-applied and their threads are never auto-resolved, with or without `--apply`. `--apply` is not a "do everything" switch; it is style-nits plus their bot threads, nothing more.

## Hard rules

- **Advisory only by default.** In default mode: never resolve threads, never edit the spec without an explicit user ask, never post replies without explicit user say-so. The single exception is `--apply`, which is scoped to `style-nit` diffs and their bot threads only (see [`--apply` mode](#--apply-mode)) — nothing else is ever auto-applied or auto-resolved, and human threads are never auto-resolved even then.
- **One classification per cluster.** A cluster doesn't span buckets — split if the threads disagree on what they are.
- **Section headers, not line numbers.** Stable across edits; reviewable.
- **Bot threads cluster separately from human threads.** Tagged-prefix `[specto:<agent-name>#<sha8>]` threads form their own batch; clustering keys on the `[specto:<agent-name>` prefix and additionally on the `#<sha8>` per-finding hash so a re-run of `review-spec` (which edits findings in place) collapses onto the existing cluster instead of duplicating it.
- **V2 backlog lives in the spec folder.** Deferred scope is spec content, not repo-global state — write it to `<spec-folder>/v2-candidates.md`, next to `product-spec.md`. Because the spec folder is tracked docs (never gitignored), the backlog is committed by default and travels with the spec it came from; no `.specto/.gitignore` whitelisting needed.

## When this skill should NOT run

- No open MR: nothing to read.
- The MR has no spec files: invoke `resolve-mr-comments` — specto's code-MR sibling that plans + implements fixes and resolves threads.
- The user wants to draft a new spec from scratch: invoke `new-spec`.
- The user wants reviewer feedback on an in-progress spec: invoke `review-spec`.
