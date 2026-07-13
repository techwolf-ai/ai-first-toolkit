---
name: resolve-mr-comments
description: Use when the user wants to process outstanding reviewer feedback on a code merge request (MR) / pull request (PR). Triggers on "address MR comments", "fix MR feedback", "resolve MR threads", "handle review comments", "there are comments on my MR", "reviewer left comments", "address PR comments", or a shared forge MR/PR URL with "fix/address its comments". For spec MRs (specs under `docs/development/specs/`), use `resolve-spec-comments` instead — that skill is advisory only.
argument-hint: "[MR-iid | branch-name | URL]"
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Agent, AskUserQuestion
---

# resolve-mr-comments

Systematic workflow for fetching reviewer comments on a code MR, planning fixes, implementing them TDD-style, and resolving threads on the forge (GitLab/GitHub). Uses `${CLAUDE_PLUGIN_ROOT}/scripts/forge/mr-fetch.sh discussions` for the read side and `${CLAUDE_PLUGIN_ROOT}/scripts/forge/mr-reply.sh` for the write side — never inline the forge CLI (`glab`/`gh`).

This is the **code-MR sibling** of `resolve-spec-comments`. They split by what the MR touches:

| Skill | When | Behaviour |
|---|---|---|
| `resolve-mr-comments` | The MR touches code (no files under `docs/development/specs/`) | Plans + implements fixes; replies + resolves threads. |
| `resolve-spec-comments` | The MR touches spec files | Advisory only — clusters and classifies but never edits the spec or resolves threads without explicit user ask. |

## Prerequisite check

- The forge CLI (`glab`/`gh`) is on PATH and authenticated.
- One of: (a) an open MR exists on the forge for the current branch, (b) the user supplies an MR IID, URL, or branch name. The helper resolves the project automatically from the current repo.
- The MR has at least one unresolved discussion.

## Critical rules

- **Fix in-session, resolve silently — the commit is the reply.** When the fix is in the pushed commit, resolve the thread with `mr-reply.sh --discussion <id> --resolve-only`; a boilerplate "Done"/"resolved" note is noise. Post a reply **only when it carries information the resolve can't**: a deferral naming its follow-up ticket, a genuine question for the reviewer, a bot focus-area trace, or a wrap-up a later reader would otherwise be misled without.
- **Never modify code without entering plan mode and getting user confirmation** (Phase 2). The reviewer's comment is the spec; verify alignment with the user before applying.
- **Always run the full test suite before pushing.** A reviewer fix that breaks a previously passing test is worse than the original comment.
- **Bail loudly on forge CLI (`glab`/`gh`) / `acli` errors.** Don't retry blindly — surface the failure and let the user reauth or check the MR state.

## Inputs the user provides

- **MR identifier** (optional) — an IID, a branch name, or a full forge MR/PR URL. If absent, fall back to "current branch's MR".
- **Confirmation** before any code edits (Phase 2 gates everything).

## Phase 1: fetch + parse

1. Resolve the MR target. The user supplies one of three forms (or none, falling back to the current branch's MR):

   | Input | Helper invocation |
   |---|---|
   | (nothing — default) | `mr-fetch.sh discussions` |
   | `<IID>` (numeric) or a URL ending in `/-/merge_requests/<N>` (GitLab) or `/pull/<N>` (GitHub) (extract the trailing number) | `mr-fetch.sh discussions --iid <N>` |
   | Branch name | `mr-fetch.sh discussions --branch <name>` |

   `mr-fetch.sh` is the single read path; never inline the forge CLI (`glab`/`gh`). The helper resolves the project automatically from the current repo.

   **Record the resolved IID as `MR_IID`** (the numeric form, or fetch it via `mr-fetch.sh info [--branch <name>] | jq -r .iid` when given a branch). Carry it into every Phase 2 / Phase 5 reply command as `--iid "$MR_IID"` — `mr-reply.sh` defaults to the *current branch's* MR otherwise, which breaks on a detached HEAD or when the shell has cd'd into another repo (the exact failure this targeting flag fixes). Skip `--iid` only in the pure default case where no MR was named and you're on the MR's own branch.

2. Fetch all discussions, then filter inline with `jq`. Drop system notes, MR-bot status notes (the `manual` / `merged` / `assigned` boilerplate) and threads that are already resolved. Bot REVIEW threads are kept — see step 4 — they often surface real issues:
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/forge/mr-fetch.sh" discussions [--iid <N>|--branch <name>] \
     | jq -c '.[] | select(
         (.notes[0].system // false) == false              # drop system notes
         and ((.notes[0].body // "") | test("^Manual"; "i") | not)  # drop "manual" status prefix
         and ((.notes[0].resolvable // false) == false
              or (.notes[0].resolved // false) == false)   # drop resolved threads
       )'
   ```

3. For each remaining thread record:
   - `discussion_id` (needed for `mr-reply.sh --discussion`).
   - `resolvable` = `notes[0].resolvable` (boolean). Non-resolvable discussions (bot reviews, the MR description thread, …) must be addressed with `--no-resolve` — the resolve PUT 4xx's on them.
   - `file_path` + `line` (from `notes[0].position.new_path` / `new_line`; null for non-diff comments).
   - `body` (the comment).
   - `thread` (follow-up notes, if any) — they often answer their own question.

4. Categorise each thread into ONE of five buckets. The decision:

   ```dot
   digraph thread_bucket {
       "Thread" [shape=doublecircle];
       "Resolvable?" [shape=diamond];
       "Explicitly deferred?" [shape=diamond];
       "Genuine open question for the reviewer?" [shape=diamond];
       "Already settled in-thread?" [shape=diamond];
       "Bot review" [shape=box];
       "Deferred" [shape=box];
       "Genuine question" [shape=box];
       "Resolved-by-discussion" [shape=box];
       "Actionable" [shape=box];

       "Thread" -> "Resolvable?";
       "Resolvable?" -> "Bot review" [label="no (--no-resolve, per focus area)"];
       "Resolvable?" -> "Explicitly deferred?" [label="yes"];
       "Explicitly deferred?" -> "Deferred" [label="yes (reply --no-resolve)"];
       "Explicitly deferred?" -> "Genuine open question for the reviewer?" [label="no"];
       "Genuine open question for the reviewer?" -> "Genuine question" [label="yes (reply --no-resolve)"];
       "Genuine open question for the reviewer?" -> "Already settled in-thread?" [label="no"];
       "Already settled in-thread?" -> "Resolved-by-discussion" [label="yes (--resolve-only)"];
       "Already settled in-thread?" -> "Actionable" [label="no (fix, then --resolve-only)"];
   }
   ```

   | Bucket | What it looks like | Write invocation |
   |---|---|---|
   | **Actionable (human)** | Resolvable thread from a human reviewer, change suggested, no objection. Fixed in Phase 3. | `mr-reply.sh --discussion <id> --resolve-only` — the pushed commit is the reply |
   | **Resolved-by-discussion (human)** | Resolvable thread, already settled through conversation. | `mr-reply.sh --discussion <id> --resolve-only`; add a one-line wrap-up reply first only when the thread as it stands would mislead a later reader |
   | **Deferred (human)** | Resolvable thread, but the author or commenter explicitly deferred ("revisit later", "out of scope"). | `mr-reply.sh --discussion <id> --no-resolve` naming the follow-up ticket |
   | **Genuine question** | A decision the author actually wants the reviewer's input on — not feedback you can act on. | Prefer staging it locally for the author's own triage first: `"${CLAUDE_PLUGIN_ROOT}/scripts/mdreview/add-local-comment.sh" <repo-root> <file> <line> resolve-mr-comments <section-or-topic> open-question -` with the question on stdin; the author reviews in markdown-reviewer and pushes only what truly needs the reviewer. Fallback (no local repo / file context): `mr-reply.sh --discussion <id> --no-resolve` carrying the *actual question*. |
   | **Bot review** | Non-resolvable thread (CI bots, automated reviewers, …). Often packs several findings in one body — each focus area is a separate item. | `mr-reply.sh --discussion <id> --no-resolve` per focus area |

   Sub-rule for the **Bot review** bucket: if a single bot thread lists multiple focus areas (`<details><summary>Hardcoded IDs</summary>…`), build one reply per area so each is auditable on its own — all into the same `discussion_id`, all `--no-resolve` (non-resolvable thread). Bot threads tagged `[specto:<agent-name>#<sha8>]` belong to `resolve-spec-comments` instead — skip them here.

## Phase 2: plan + confirm

After fetching and categorising, **stop and present a plan before any code edit**.

1. Read every file referenced by the comments — you need the current state, not just the diff context.
2. Render a structured plan:
   - One section per actionable comment, with the specific code change described.
   - A section listing deferred items (reply only — no code change).
   - A section listing bot-review items, one entry per focus area.
   - A **`Post-push thread actions`** section: one ready-to-run `mr-reply.sh` command per thread, with IDs filled in from Phase 1 — and any draft reply written *now*. Phase 5 is then paste-and-run — the user reviews the changes AND the thread actions in one artefact, no second-pass categorisation while typing. The dominant shape is the silent `--resolve-only`; a reply appears only where it adds information.

   Example shape of the Post-push section:

   ```bash
   # Thread 1 — n+1 query in get_user (actionable, fixed in Phase 3 → silent resolve)
   "${CLAUDE_PLUGIN_ROOT}/scripts/forge/mr-reply.sh" --discussion 9c3e0a1f --resolve-only --iid "$MR_IID"

   # Thread 2 — naming nit (resolved-by-discussion, settled in-thread → silent resolve)
   "${CLAUDE_PLUGIN_ROOT}/scripts/forge/mr-reply.sh" --discussion a1b2c3d4 --resolve-only --iid "$MR_IID"

   # Thread 3 — out-of-scope idea (deferred — reply names the ticket, no resolve)
   "${CLAUDE_PLUGIN_ROOT}/scripts/forge/mr-reply.sh" --discussion e5f6a7b8 - --iid "$MR_IID" --no-resolve <<'MSG'
   Acknowledged — deferring to follow-up ticket APP-XXXX.
   MSG

   # Thread 4 — reviewer asked which retention window we want (genuine question — ask it, no resolve)
   "${CLAUDE_PLUGIN_ROOT}/scripts/forge/mr-reply.sh" --discussion c9d8e7f6 - --iid "$MR_IID" --no-resolve <<'MSG'
   30d matches the export TTL, 90d matches audit. Which do you want for this table?
   MSG

   # Thread 5 — PR Reviewer bot, focus area "Hardcoded IDs" (non-resolvable thread, reply-only)
   "${CLAUDE_PLUGIN_ROOT}/scripts/forge/mr-reply.sh" --discussion accf6e4b - --iid "$MR_IID" --no-resolve <<'MSG'
   Added a doc comment + pointed at resolve_customfields as the override hook.
   MSG
   ```

3. Ask clarifying questions when:
   - A comment is ambiguous.
   - Multiple valid implementations exist (pick one explicitly, mention the tradeoff).
   - A change has potential side effects (auth, migrations, public API).
4. Wait for explicit user confirmation before Phase 3.

## Phase 3: implement (TDD)

Resolve the repo-specific test / typecheck commands once, up front:

```bash
TEST_CMD="$("${CLAUDE_PLUGIN_ROOT}/scripts/plugin-config.sh" get test_command 2>/dev/null || echo pytest)"
TYPECHECK_CMD="$("${CLAUDE_PLUGIN_ROOT}/scripts/plugin-config.sh" get typecheck_command 2>/dev/null || true)"
```

The default `pytest` works for simple repos, but many repos need specific flags. Common non-obvious one: `--override-ini="addopts="` to clear `addopts` that include `--dist=loadgroup` (pytest-xdist) — without this, pytest dies with "unknown option" in a worktree / clean venv. A repo's first-run setup should:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/plugin-config.sh" set test_command \
  'uv run pytest tests --random-order --color=yes --override-ini="addopts="'
"${CLAUDE_PLUGIN_ROOT}/scripts/plugin-config.sh" set typecheck_command \
  'uv run ty check your_package/'
```

For each actionable item:

1. **Check existing tests** — read related test files for current coverage.
2. **Update tests first** if the change alters behaviour (skip for pure refactors).
3. **Make the code change.**
4. **Run the relevant tests** to verify locally — `$TEST_CMD <touched-file-or-pattern>`.

Use parallel `Agent` calls for independent changes touching different files; sequential for changes that depend on each other.

## Phase 4: commit + push

1. Run the **full** test suite and (if configured) the typecheck command one final time:
   ```bash
   $TEST_CMD
   [[ -n "$TYPECHECK_CMD" ]] && $TYPECHECK_CMD
   ```
2. Stage the changed files (specific paths — never `git add .`) and commit with a message referencing the MR feedback, e.g. `Address MR !42 review feedback` (`!42` on GitLab, `#42` on GitHub).
3. Push: `git push origin HEAD`.

## Phase 5: resolve (and reply only where it adds information)

Paste-and-run the **`Post-push thread actions`** block from the Phase 2 plan — the IDs (and the few draft replies) are already filled in there. Re-run each command in order; failures surface as the helper's exit code (0/2/3 per the helper contract).

For reference, the three invocation shapes the plan emits (each carries `--iid "$MR_IID"` from Phase 1 so it targets the right MR regardless of the current branch / cwd; drop it only in the pure default current-branch case):

**Actionable + resolved-by-discussion (resolvable thread, fixed/settled → silent resolve — the dominant shape):**
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/forge/mr-reply.sh" --discussion "<DISCUSSION_ID>" --resolve-only --iid "$MR_IID"
```

**Deferred / genuine question (resolvable thread, reply-only — the reply carries the ticket key or the actual question):**
```bash
echo "Acknowledged — deferring to follow-up ticket APP-XXXX" \
  | "${CLAUDE_PLUGIN_ROOT}/scripts/forge/mr-reply.sh" --discussion "<DISCUSSION_ID>" - --iid "$MR_IID" --no-resolve
```

**Bot review (non-resolvable thread, reply-only — one per focus area, all into the same discussion):**
```bash
echo "Addressed in commit <SHA>: <how>." \
  | "${CLAUDE_PLUGIN_ROOT}/scripts/forge/mr-reply.sh" --discussion "<DISCUSSION_ID>" - --iid "$MR_IID" --no-resolve
```

Reply guidelines:

- For fixed items: **no reply** — `--resolve-only`; the commit and the resolve say it. A "Done — fixed in <sha>" note is noise.
- For settled discussions: silent resolve too; add a one-line wrap-up first only when the thread as it stands would mislead a later reader.
- For deferred items: acknowledge the feedback, name the follow-up ticket (if one exists), do NOT resolve (`--no-resolve`).
- For genuine questions: prefer staging into markdown-reviewer's local comments (`add-local-comment.sh`, agent name `resolve-mr-comments`, finding-type `open-question`) so the author triages before anything reaches the MR; when there's no local repo context, post the actual question with `--no-resolve`. Never resolve a question thread yourself.
- For bot focus areas: address each separately into the same non-resolvable discussion; concrete "what changed and where" beats "noted." Reviewers reading the MR later need to see what was acted on.
- Keep the rare replies concise — don't repeat the full diff, never re-post a monologue of the fix.

## Phase 6: follow-up tickets (when applicable)

If deferred items or out-of-scope improvements were identified:

1. Ask the user whether the deferred items warrant a follow-up Jira ticket.
2. If yes, dispatch the **`create-ticket`** skill to create the ticket. Pass the deferred-items summary as the description.
3. Update the deferred thread replies (via `mr-reply.sh --discussion <id> - --iid "$MR_IID" --no-resolve`) to reference the new ticket key.

## Hard rules

- **All forge CLI calls go through the helpers.** `mr-fetch.sh discussions` for reads, `mr-reply.sh` for writes. No inline `glab`/`gh`.
- **Replies are the exception, not the default.** Fixed/settled threads resolve silently (`--resolve-only`); a reply exists only to carry a deferral ticket, a genuine question, or a bot focus-area trace.
- **Bot threads tagged `[specto:<agent-name>]` belong to `resolve-spec-comments`.** This skill should skip them or hand them off; never edit a spec from here.
- **No `git add .`** — stage specific paths only.
- **Phase 2 is a hard gate.** No edits before the user confirms the plan.

This skill is **rigid**: violating the letter of these rules is violating their spirit. A reply you post is not a substitute for the user confirming the plan; "silent resolve" is not "resolve things I didn't actually fix." Use TodoWrite to track the phases (one todo per phase) so the Phase 2 gate is never skipped under momentum.

### Red flags — stop if you catch yourself thinking:

| Rationalization | Reality |
|---|---|
| "The fix is obvious, I'll edit before the plan." | Phase 2 is a hard gate — no edits before the user confirms. |
| "A 'Done — fixed in <sha>' reply is helpful." | It's noise — the commit and the resolve already say it. Reply only when adding information (deferral ticket, genuine question, bot trace). |
| "I'll resolve this question thread — I'm sure the reviewer would agree." | Genuine questions stay open with the actual question posted; only the reviewer settles them. |
| "Faster to hit the forge CLI (`glab`/`gh`) directly." | All reads/writes go through `mr-fetch.sh` / `mr-reply.sh`. |
| "`git add .` is quicker than listing paths." | Stage specific paths only. |
| "This bot thread is mine to edit." | `[specto:…]` bot threads belong to `resolve-spec-comments` — skip/hand off. |

## When this skill should NOT run

- The MR touches files under `docs/development/specs/` — use `resolve-spec-comments` (which is advisory: it never edits the spec or resolves threads without an explicit user ask).
- The user wants a fresh code review (not "address comments") — use a code-review skill (e.g. `mr-workflow:review` if that plugin is installed).
- The pipeline is failing and the user wants it green — use a CI-fix skill (e.g. `mr-workflow:fix-pipeline` if that plugin is installed).
- There are no unresolved discussions — there's nothing to address.
