# specto / scripts / forge / github

Vetted helpers that read and write GitHub PR and issue data on behalf of Specto skills and agents, behind the forge dispatcher. **One source of truth for every `gh` invocation**: skills and agents shell out to the dispatcher shims (`scripts/forge/<verb>.sh`), never inline `gh`. Every helper accepts a `--from-fixture <dir>` mode (see *Fixture mode* below) so the test harness runs offline. Requires gh >= 2.94.

Each verb mirrors its gitlab counterpart's argv signature exactly, emits the normalized shapes from `docs/adapter-contract.md`, and prints byte-identical decision lines in fixture mode: that equality is the cross-backend test contract. "MR" stays the specto-generic term; on this backend it is a pull request and `iid` is the PR number.

Conventions shared by all helpers:

- `set -u` + `set -o pipefail`.
- Warnings and errors go to **stderr**; the documented payload goes to **stdout** (in fixture mode several helpers print a single machine-parseable decision line so tests can assert the branch taken).
- Exit codes: `0` ok · `1` data missing / unparseable (empty body, no head SHA) · `2` bad usage · `3` external-command failure (`gh` not on PATH, not in a repo, no PR for the branch, or the API call errored).
- The repo path is resolved once per process (`_lib.sh` → `specto_gh_repo`: `gh repo view --json owner,name`, falling back to parsing the origin remote); the PR number via `specto_gh_pr_number` (`gh pr view <branch> --json number`).
- **Source branch resolution** (`_lib.sh` sources `scripts/vcs/_lib.sh` → `specto_source_branch`). Every helper that targets "the current branch's PR" passes the branch explicitly instead of letting `gh` infer it: that inference breaks under **jj colocated with git**, where HEAD stays detached after `jj git push`. Override with `SOURCE_BRANCH=<name>` (any helper) or `create-mr.sh --source-branch <name>`.
- **Fixtures are GitHub-shaped**: raw `gh pr view --json` objects, raw GraphQL `reviewThreads` responses, raw `pulls/{n}/files` arrays. The helpers run the same normalizers on fixtures as on live responses, so fixture output equals live output.

## `mr-fetch.sh <discussions|info|diff> [--iid <N> | --branch <name>] [--from-fixture <dir>]`

Single read path for PR data, normalized per `docs/adapter-contract.md`. `info` → the change-request object (`gh pr view --json …` mapped to `iid`=number, `web_url`=url, `state` lowercased with OPEN→`opened`, `draft`=isDraft, `diff_refs` synthesized with `base_sha = start_sha = baseRefOid`, `head_sha = headRefOid`; the PR body rides along as the extra `description` field). `discussions` → ONE flat thread array merged from **three** sources: GraphQL `reviewThreads` (paginated `first:100`; thread id = GraphQL node id, `resolvable:true`, position from `path`/`line` with `originalLine` fallback on outdated threads), plus top-level issue comments and non-empty review summaries (`gh pr view --json comments,reviews`) as synthetic single-note threads (`resolvable:false`, `system:false`, `position:null`): the merge is what gives `resolve-mr-comments` bot-comment parity with GitLab; bare approvals (empty review body) are dropped. Threads carry a backend-private `kind` field (`review_thread`/`issue_comment`/`review`) that `post-mr-comment.sh` and `mr-reply.sh` use to pick the right write path. `diff` → per-file entries from `GET repos/{o}/{r}/pulls/{n}/files --paginate`: `filename`→`new_path`, `previous_filename // filename`→`old_path`, `patch`→`diff` (missing patch: binary/oversized: maps to `""`, which downgrades anchoring to GENERAL), `status`→`new_file`/`deleted_file`/`renamed_file`. Fixture files: `info.json`, `threads.json` (raw GraphQL pages, concatenated), `comments.json`, `files.json` (pages may be concatenated).

## `post-mr-comment.sh <agent-name> <spec-path> <line> <section> <finding-type> <body-file|-> [--from-fixture <dir>]`

Posts a **line-anchored** review comment on the current branch's PR: **idempotently**. The marker/sha8 computation is byte-identical with gitlab (`sha8 = sha1("<agent>\0<spec-path>\0<norm-section>\0<norm-type>")[:8]`, embedded as `[specto:<agent>#<sha8>] `), so the same finding folds onto the same thread on either backend. Existing threads (review threads AND synthetic issue-comment/review threads) are scanned for the marker: found → the note is edited in place via GraphQL (`updatePullRequestReviewComment`, `updateIssueComment`, or `updatePullRequestReview` by note kind); not found → a new comment is created. **The GitHub difference:** review comments can only anchor to lines a diff hunk actually shows, so the shared anchor walk (`scripts/forge/_anchor.sh`, sourced by this helper) runs in *hunks-only* mode: a line inside a hunk (added or context) anchors via `POST repos/{o}/{r}/pulls/{n}/comments` with `{body, commit_id: <head_sha>, path, line, side:"RIGHT"}` (no old_line math needed); a line in the gaps between hunks, anchorable on GitLab, falls back to a GENERAL comment (`gh pr comment`) here, still carrying the marker. After an anchored create the response's `.line` is checked and the helper fails loudly (exit 3) if GitHub dropped it. `<spec-path>` may be absolute: matched against the diff by exact path or repo-relative suffix. Decision lines (fixture mode): `EDIT sha8=… discussion=… note=…`, `CREATE sha8=… ANCHOR new_line=<n> [old_line=<o>]`, `CREATE sha8=… GENERAL`: the same grammar the gitlab suite asserts.

## `mr-reply.sh [--discussion <id>] <body-file|-> [--no-resolve | --resolve-only] [--iid <N> | --branch <name>] [--from-fixture <dir>]`

Reply to a discussion thread, resolving it by default. Review threads take a threaded reply (GraphQL `addPullRequestReviewThreadReply`) and resolve via `resolveReviewThread`. Synthetic issue-comment / review-summary threads have no threaded replies on GitHub: a reply becomes a **quote-reply** top-level comment (`gh pr comment`, first line of the original quoted), and they cannot be resolved, so callers use `--no-resolve` for them (the same convention gitlab callers already follow for bot threads). `--resolve-only` resolves without posting (no body allowed; conflicts with `--no-resolve`). Legacy positional form `<discussion-id> <body-file>` preserved. Decision lines: `REPLY_RESOLVE` / `REPLY` / `RESOLVE discussion=<id>`.

## `create-mr.sh <title> <description-file|-> [--reviewer <u>]... [--assignee <u>]... [--target <branch>] [--source-branch <name>] [--from-fixture <dir>]`

Creates a **draft** PR for the source branch (`gh pr create --draft --title … --body-file - --head <branch>`), assigning `@me` unless `--assignee` is passed. **Idempotent**: if a PR already exists for the branch (`gh pr view <branch>` succeeds), it updates that PR (`gh pr edit --title … --body-file -`, people flags via `--add-assignee`/`--add-reviewer`). `--target` maps to `--base`. Prints the PR web URL on stdout (live). Fixture: reads `<dir>/mr.json` (`{"exists":true,"number":42,…}` or `{"exists":false}`) and prints `CREATE` or `UPDATE iid=<number>`.

## `mr-ready.sh [--from-fixture <dir>]`

`gh pr ready <branch>`: flip the PR out of draft. No stdout on success. Fixture: no-op success (the dir just has to exist).

## `mr-describe.sh <body-file|-> [--iid <N> | --branch <name>] [--from-fixture <dir>]`

Idempotently maintains the `<!-- specto:walkthrough:start/end -->`-delimited section of the PR description (same splice as gitlab), reading the current body through `mr-fetch.sh info` and writing via `gh pr edit --body-file -`. Live prints the PR web URL; fixture (reads `<dir>/info.json`, the gh `--json body` shape) prints the spliced description.

## `pipeline-status.sh [--manual-jobs] [--from-fixture <dir>]`

Reports the PR's checks. Prints exactly one of `running` / `success` / `failed` / `none` on the first stdout line (`gh pr checks --json bucket,name,link,state`; any `fail` → failed, else any `pending` → running, else any `pass` → success, else none: the exit code of `gh pr checks` is never trusted, it is non-zero on failing/pending checks). When `failed`, a `---` line follows, then the failed **Actions job ids** one per line, parsed from each check's `…/job/<id>` link (feed each to `job-trace.sh`); failed checks from external apps carry no job id and are skipped with a stderr warning. `--manual-jobs` emits `<environment>\t<run-name>\t<run-url>` per pending deployment approval (runs with `status=waiting` × `pending_deployments`): GitHub's nearest equivalent to GitLab manual jobs; empty output when none (documented degradation). Fixture files: `checks.json`, `waiting-runs.json`, `pending-deployments-<run-id>.json`.

## `job-trace.sh <job-id> [--from-fixture <dir>]`

Prints the last ~200 lines of an Actions job's log: `gh run view --job <id> --log`, falling back to `GET repos/{o}/{r}/actions/jobs/<id>/logs` (the raw endpoint works as soon as the job ends). Fixture: reads `<dir>/trace-<job-id>.txt`.

## `create-issue.sh <title> <body-file|-> --repo <owner/repo> [--from-fixture <dir>]`

Creates a GitHub **issue** for plugin friction (the `plugin-feedback` drain). Unlike the gitlab impl's hardcoded repo, the target is `--repo <owner/repo>`: required in live mode; the skill reads `feedback_repo` from config. Prints **only the new issue's number** (parsed from the returned `…/issues/<n>` URL). The gitlab verification pattern is ported wholesale: the exit code alone never decides failure (a printed URL trumps a non-zero exit), and the created issue is re-fetched and verified against the submitted title + body fingerprint, with an in-place PATCH repair on a body desync and a loud "do NOT re-file" on anything unrepairable. Fixture: `<dir>/issue.json` (`{"number":7,…}`), optional `<dir>/verify.json` (`{"number":7,"title":…,"body":…}`).

## `find-mr-for-ticket.sh <TICKET-KEY> [--state opened|merged|closed|all] [--from-fixture <path>]`

`gh pr list --search "[<KEY>] in:title" --state <s> --json …` → the normalized change-request array (same 7 guaranteed fields as `mr-fetch.sh info`, states lowercased with OPEN→`opened`). `--state opened` maps to gh's `open`. Fixture: a file holding the raw `gh pr list --json` array.

## Fixture mode

A fixture is a **directory** under `tests/fixtures/` (except `find-mr-for-ticket.sh`, which takes a file), holding GitHub-shaped raw responses:

| Helper | Reads from `<dir>/` |
|---|---|
| `mr-fetch.sh info` | `info.json` (gh pr view shape) |
| `mr-fetch.sh discussions` | `threads.json` (raw GraphQL pages), `comments.json` |
| `mr-fetch.sh diff` | `files.json` (pulls/files shape) |
| `post-mr-comment.sh` | `info.json`, `threads.json`/`comments.json`, `files.json` (prints the decision line; no network) |
| `create-mr.sh` | `mr.json` (prints `CREATE`/`UPDATE iid=<n>`; no network) |
| `mr-ready.sh` |: (dir must exist; no-op) |
| `mr-describe.sh` | `info.json` (prints the spliced description) |
| `pipeline-status.sh` | `checks.json`; `waiting-runs.json` + `pending-deployments-<id>.json` for `--manual-jobs` |
| `job-trace.sh <id>` | `trace-<id>.txt` |
| `create-issue.sh` | `issue.json`, optional `verify.json` |
| `find-mr-for-ticket.sh` | a `gh pr list --json` array file |

## Tests

`bash tests/run-tests.sh`: 221 asserts, fully offline: fixture-mode normalization (state mapping, three-source discussion merge, two-page pagination flattening, rename/binary diff mapping), decision-line parity with the gitlab grammar (including the hunks-only GENERAL narrowing and the shared sha8), and mocked-`gh` live paths asserting request shapes (GraphQL mutation names, `side:"RIGHT"` + `line` + `commit_id` in the review-comment payload, `--draft` on create, the idempotent EDIT path, `--repo` on issue create, job-id extraction and the run-view→raw-logs fallback). `scripts/tests/run-all.sh` picks the suite up automatically.

## Adding a helper

Same recipe as the gitlab backend (see `../gitlab/README.md`): fixture dir first, failing asserts, then the helper with the standard shape (`set -u` + `pipefail`, `usage()` → exit 2, `--from-fixture`, exit codes `0/1/2/3`, errors to stderr), sourcing `_lib.sh` for repo/PR/branch resolution. Keep fixtures GitHub-shaped and decision lines byte-identical with the other forge backends.
