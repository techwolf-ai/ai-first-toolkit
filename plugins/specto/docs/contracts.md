# Specto contracts

Cross-cutting rules every Specto agent and skill follows. Each section is a contract: if you write a new Specto agent that touches the same surface, follow it.

---

## The meta-vs-live contract for `.specto-meta.yml`

`new-spec` writes `<spec-folder>/.specto-meta.yml` when it scaffolds an initiative. It records the facts that were true *at scaffold time* — the linked epic key, the change-classification answers (Q1/Q2/Q3 + Development Stage / Epic Type / Delivery cycle), and similar. It is a **convenience cache, not a source of truth**: anything in it can go stale the moment someone edits the epic, transitions a ticket, or re-classifies the change.

**The rule.** Any agent or skill that reasons about *live* state — current ticket status, current epic classification, the epic's Issue Checklist, ticket assignees, sprint membership — **must re-fetch it** before acting. Use `scripts/tracker/epic-fields.sh <epic-key>`, `scripts/tracker/get-ticket-status.sh <KEY>`, `scripts/forge/mr-fetch.sh`, etc. Act on the live value. The `.specto-meta.yml` snapshot may be used to *detect drift* — compare live against snapshot and warn the user if they disagree — but the live value wins.

**What `.specto-meta.yml` is safe for.** Reading the *epic key* from it is fine: the key is stable for the life of the initiative, and it's the cheapest way to discover *which* epic to query. What's not fine is assuming the classification answers, or any ticket state, recorded next to that key are still accurate — re-fetch those.

**Current consumers (all consistent with this contract):**

- The `dod` agent reads the epic key from `.specto-meta.yml`, then re-queries the tracker for the epic's Issue Checklist, its live change-classification answers (via `epic-fields.sh`, for the non-standard-change controls), and each ticket's acceptance criteria. It also re-fetches each ticket's live status (state-desync findings, ticket-level mode) rather than trusting any cached status.
- `change-classification-review` reads the epic key from `.specto-meta.yml`, then re-fetches the live classification answers via `epic-fields.sh` and flags drift between the spec header and the live epic.
- `plan-to-tickets` re-fetches the epic at ticket-create time and warns on drift versus the `.specto-meta.yml` snapshot before creating tickets.
- Reviewer agents that only need the epic *key* (not its state) read it straight from `.specto-meta.yml` — that's within the contract, since the key is stable.

If you add a Specto agent that reads `.specto-meta.yml`: read the key, re-fetch the state, warn on drift, act on live.

---

## Single vetted entry point for tracker + forge side effects

Every skill or agent that touches the tracker or the forge shells out to a **dispatcher shim** under `scripts/tracker/` or `scripts/forge/`, invoked as `"${CLAUDE_PLUGIN_ROOT}/scripts/<domain>/<verb>.sh"`, instead of inlining a vendor CLI (`acli`, `glab`, `gh`, raw `curl`). The shim path is stable; the backend behind it is configuration.

### How dispatch works

Each shim is a ~6-line script that sources `scripts/lib/dispatch.sh` and calls `specto_dispatch <domain> <verb> "$@"`. The dispatcher resolves the configured backend for the domain (forge, tracker, or vcs) and `exec`s the implementation at `scripts/<domain>/<backend>/<verb>.sh` with the caller's argv passed through verbatim, including `--from-fixture`. Backend implementations (today: `scripts/forge/gitlab/`, `scripts/tracker/jira/`) obey the same helper shape as any vetted helper (see *The rule* below) and carry their own README and test suite.

### Backend selection precedence

Implemented once, in `scripts/lib/config.sh`. For each domain, first hit wins:

1. Environment variable: `SPECTO_FORGE` / `SPECTO_TRACKER` / `SPECTO_VCS`.
2. Repo config: the `forge:` / `tracker:` / `vcs:` key in the nearest `.specto/config.yml`, walking up from `$PWD` (flat `key: value` scalar lines only; that constraint holds for every `.specto/*.yml` file Specto reads in shell).
3. Machine default: `plugin-config.sh get forge|tracker|vcs`.
4. Autodetect. Forge: origin remote host (`github.com` maps to github; a GitLab host, or any host `glab` has a token for, maps to gitlab). Tracker: `.specto/tracker-jira.yml` present or a `jira_project_key` configured maps to jira; `$LINEAR_API_KEY` set maps to linear; forge resolved to github maps to github (issues). Vcs: `jj root` succeeds maps to jj, else git.

No answer at any tier: exit `3` with setup guidance on stderr. Tests pin a backend with `SPECTO_BACKEND_OVERRIDE_FORGE` / `_TRACKER` / `_VCS`, which short-circuits all four tiers without touching config files.

### Exit-code taxonomy

| Code | Meaning | Emitted by |
|---|---|---|
| `0` | ok | |
| `1` | data missing / unparseable (data-shape mismatch) | backend helpers |
| `2` | bad usage (the helper's `usage()` line goes to stderr) | helpers and shims |
| `3` | external-command failure (CLI not on PATH, not in a repo, API call errored); also "no backend configured or detectable" | backend helpers; dispatcher |
| `4` | the verb has no implementation on the selected backend | dispatcher only |

### The vetted entry points

Forge (`scripts/forge/`):

| Concern | Helper | Used by |
|---|---|---|
| Create or update an MR (idempotent, draft) | `scripts/forge/create-mr.sh` | `implement-ticket`, `create-mr` |
| Read MR data (`info`, `discussions`, or `diff`; default current branch, `--iid <N>` or `--branch <name>` to target another MR) | `scripts/forge/mr-fetch.sh` | `implement-ticket`, `mr-walkthrough`, `reconcile-spec`, `resolve-mr-comments`, `resolve-spec-comments`, `review-mr`, `review-spec` |
| Maintain a marker-delimited section of the MR description (idempotent splice) | `scripts/forge/mr-describe.sh` | `mr-walkthrough` |
| Post a line-anchored review discussion (idempotent, marked) | `scripts/forge/post-mr-comment.sh` | the six reviewer agents, `review-spec` |
| Reply to a discussion thread (by default resolves; `--no-resolve` for non-resolvable bot threads / deferred items) | `scripts/forge/mr-reply.sh` | `resolve-mr-comments`, `resolve-spec-comments` |
| Flip an MR out of draft | `scripts/forge/mr-ready.sh` | `create-mr`, `implement-ticket` |
| Latest pipeline status + failed job ids | `scripts/forge/pipeline-status.sh` | `create-mr`, `implement-ticket` |
| Tail of a CI job trace | `scripts/forge/job-trace.sh` | `implement-ticket` |
| File a plugin-friction issue | `scripts/forge/create-issue.sh` | `plugin-feedback` |
| Find MRs whose title carries `[<KEY>]` (the implement-ticket title convention) | `scripts/forge/find-mr-for-ticket.sh` | `dod` |

Tracker (`scripts/tracker/`):

| Concern | Helper | Used by |
|---|---|---|
| Create a ticket of any type (Task, Bug, Story, Test Plan), with Blocks/BlockedBy links created in the same invocation | `scripts/tracker/create-ticket.sh` | `plan-to-tickets`, `create-ticket`, `create-test-plan` |
| Link two work items (any link type) | `scripts/tracker/link-tickets.sh` | `create-ticket.sh` itself, `create-ticket`, `create-test-plan` |
| Delete links across work items (`--type`, `--dry-run`) | `scripts/tracker/delete-links.sh` | maintenance utility (no fixed caller yet) |
| Set / read a ticket's parent | `scripts/tracker/set-parent.sh`, `scripts/tracker/get-ticket-parent.sh` | `create-test-plan` |
| Transition a ticket, with workflow-synonym fallback | `scripts/tracker/transition-ticket.sh` | `create-mr`, `implement-ticket`, `dod` |
| Assign a ticket | `scripts/tracker/assign-ticket.sh` | `implement-ticket` |
| Add labels (additive, never clobbers) | `scripts/tracker/label-ticket.sh` | `plan-to-tickets` |
| Comment on a ticket | `scripts/tracker/comment.sh` | `create-test-plan` |
| Resolve the active sprint(s) for a board | `scripts/tracker/active-sprint.sh` | `create-ticket`, `plan-to-tickets` |
| Place a ticket in a sprint | `scripts/tracker/add-to-sprint.sh` | `create-ticket`, `create-test-plan` |
| Read a ticket's active sprint | `scripts/tracker/get-ticket-sprint.sh` | `create-test-plan` |
| Read a ticket's type / title / live status | `scripts/tracker/get-ticket-type.sh`, `scripts/tracker/get-ticket-summary.sh`, `scripts/tracker/get-ticket-status.sh` | `create-ticket` + `create-test-plan` (type), `create-test-plan` (title), `dod` (status) |
| Read a ticket's description as markdown | `scripts/tracker/get-ticket-description.sh` | `create-mr`, `implement-ticket`, `review-mr`, `code-mr-review` |
| Read epic classification fields | `scripts/tracker/epic-fields.sh` | `new-spec`, `change-classification-review` |
| List an epic's children as normalized JSON | `scripts/tracker/list-children.sh` | `dod-check`, `dod` |
| Canonical browse URL for a ticket | `scripts/tracker/ticket-url.sh` | any prose or template that renders a ticket link (never hardcode a tenant URL) |

Cross-cutting:

| Concern | Helper | Used by |
|---|---|---|
| Render the Test Plan ADF document (structurally guarantees no `taskItem` wraps in `paragraph`) | `references/test-plan-adf-template.jq` | `create-test-plan` |
| Persistent machine defaults (`forge` / `tracker` / `vcs` backend keys, plus user defaults like `jira_project`, `jira_board_id`, `gitlab_user`, `test_command`, `typecheck_command`) | `scripts/plugin-config.sh` | `create-ticket`, `create-test-plan`, `new-spec`, `resolve-mr-comments`, `verify-milestone`; `scripts/lib/config.sh` (tier 3 of backend selection) |

The six reviewer agents are `change-classification-review`, `code-mr-review`, `eng-review`, `okr-alignment-review`, `product-review`, and `scope-review`. The normalized stdout shape and decision-line grammar for every verb above live in `docs/adapter-contract.md`; consumers may rely only on the guaranteed fields documented there.

**The rule.** A new skill/agent that needs the tracker or the forge MUST either reuse one of these shims or, if no existing verb covers the case, add a new sibling verb: one implementation at `scripts/<domain>/<backend>/<verb>.sh` per backend that supports it (backends without an implementation get the dispatcher's exit `4` for free), plus a same-named shim at `scripts/<domain>/<verb>.sh`. Every implementation keeps the same shape: `set -u`, `set -o pipefail`, an explicit `usage()` line that exits `2`, structured exit codes (`0` ok · `1` data-shape mismatch · `2` bad usage · `3` external-command failure), a `--from-fixture` test mode, and a paired entry in that backend's `tests/run-tests.sh`. Decision lines printed in fixture mode must be identical across backends. Skills inlining `acli` / `glab` / `gh` directly are out of contract.

### The one remaining inline-CLI exception

`resolve-spec-comments`' optional ticket-impact lookup (step 5 of its SKILL.md) runs a free-text JQL search (`acli jira workitem search --jql "… text ~ '<spec-section-anchor>'"`) because no vetted verb covers free-text search yet. It is explicitly optional and degrades silently: when the CLI or the tracker is unavailable, the skill skips the lookup without failing. Do not copy this pattern; if you need search behavior, add a vetted verb instead.
