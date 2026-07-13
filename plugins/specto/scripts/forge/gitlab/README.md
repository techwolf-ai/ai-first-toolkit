# specto / scripts / gitlab

Vetted helpers that read and write GitLab MR and issue data on behalf of Specto skills and agents. **One source of truth for every `glab` invocation** — skills and agents shell out to these, they never inline `glab api`. Every helper accepts a `--from-fixture <dir>` mode (see *Fixture mode* below) so the test harness runs offline.

Conventions shared by all helpers:

- `set -u` + `set -o pipefail`.
- Warnings and errors go to **stderr**; the documented payload goes to **stdout** (in fixture mode several helpers print a single machine-parseable decision line so tests can assert the branch taken).
- Exit codes: `0` ok · `1` data missing / unparseable (empty body, no diff_refs SHAs) · `2` bad usage · `3` external-command failure (`glab` not on PATH, not in a repo, no MR for the branch, or the API call errored).
- The project path + MR iid are resolved like `resolve-spec-comments` does: `glab repo view --output json | jq -r .id` and `glab mr view "$BRANCH" --output json | jq -r .iid`.
- **Source branch resolution** (`_lib.sh` → `specto_source_branch`). Every helper that targets "the current branch's MR" passes the branch explicitly instead of letting `glab` infer it from `git rev-parse --abbrev-ref HEAD` — that inference returns the literal `HEAD` under **jj colocated with git**, where HEAD stays detached at the parent commit after `jj git push`. Resolution order: `$SOURCE_BRANCH` → current git branch (`git symbolic-ref`) → the jj bookmark on `@` then `@-` → a local branch ref pointing at git HEAD. Override with `SOURCE_BRANCH=<name>` (any helper) or `create-mr.sh --source-branch <name>`.

## `mr-fetch.sh <discussions|info|diff> [--from-fixture <dir>]`

Single read path for MR data. `discussions` → a JSON array of all MR discussion threads (`glab api … --paginate`, which emits one array per page, flattened with `jq -s 'add'` into one array). `info` → the MR object JSON (contains `.diff_refs.{base_sha,head_sha,start_sha}`, `.iid`, `.web_url`, `.draft`, …). `diff` → a JSON array of per-file diff entries (`.old_path`, `.new_path`, `.diff` — the hunk-only unified diff), paginated and flattened; `post-mr-comment.sh` uses it to compute line positions. Sourced from `GET …/changes?access_raw_diffs=true`, **not** `/diffs`: the `/diffs` endpoint collapses large per-file diffs to an empty `.diff` (which would silently strip the hunks needed to anchor a line); `/changes` with `access_raw_diffs` returns the raw, uncollapsed diff. Fixture: reads `<dir>/discussions.json`, `<dir>/info.json`, or `<dir>/diff.json`.

## `post-mr-comment.sh <agent-name> <spec-path> <line> <section> <finding-type> <body-file|-> [--from-fixture <dir>]`

Posts a **line-anchored** review discussion on the current branch's MR — **idempotently**. A stable marker `sha8 = sha1("<agent-name>\0<spec-path>\0<normalized-section>\0<normalized-finding-type>")[:8]` is embedded in the body as `[specto:<agent-name>#<sha8>] `. `<section>` and `<finding-type>` are each normalized (lowercase, runs of non-alphanumerics collapsed to `-`) so the key is reproducible across runs regardless of wording — that is what stops re-runs from orphaning old threads. Before posting, every note in every existing discussion is scanned for that marker: if found → the note is updated in place (`glab api --method PUT …/discussions/<did>/notes/<nid> -f body=…`); if not → a new discussion is created. The create POST sends `{body, position}` as **nested JSON** via `--input` + `Content-Type: application/json` — *not* `-f "position[new_line]=…"`, which glab serializes into a flat JSON key (`"position[new_line]"`) that GitLab silently ignores, dropping the anchor to a plain note. After creating an anchored comment the helper checks the response's `.notes[0].position` and fails loudly (exit 3) if GitLab dropped it. The position is computed from the MR diff (`mr-fetch.sh diff`): an **added** line sends `position[new_path]`, `position[old_path]`, `position[new_line]`; an **unchanged** line (the common case for spec findings — context inside a hunk or any line outside one) additionally sends `position[old_line]` (`= new_line − net insertions before it`); SHAs come from `mr-fetch.sh info`. The `<spec-path>` may be absolute (agents are handed an absolute path) — it's matched against the diff entry by exact path **or repo-relative suffix**, and the diff's canonical repo-relative path is what gets sent in `position[…]`, so anchoring doesn't silently degrade to a general note when the caller passes an absolute path. A finding on a file **not in the MR diff** falls back to a general note (no `position`, marker preserved, so it stays idempotent) with a loud stderr line. So re-running a reviewer collapses onto the same thread instead of duplicating findings. `<body-file>` may be `-` for stdin. Exit `1` on an empty body or missing diff_refs SHAs; on a `glab` failure the real API error is surfaced to stderr (exit `3`). **Fixture mode does not touch the network** — it reads `<dir>/info.json` (SHAs), `<dir>/discussions.json` (marker search), and (on a CREATE) `<dir>/diff.json` (position), and prints one of `CREATE sha8=<8hex> ANCHOR new_line=<n> [old_line=<o>]`, `CREATE sha8=<8hex> GENERAL`, or `EDIT sha8=<8hex> discussion=<id> note=<id>`.

## `create-mr.sh <title> <description-file|-> [--reviewer <user>]... [--target <branch>] [--source-branch <name>] [--from-fixture <dir>]`

Creates a **draft** MR for the source branch (`glab mr create --draft --title … -d <body> --source-branch "$BRANCH"` — note `glab mr create` has **no** `--description-file`, so the body is read into memory and passed via `-d`; same for updates). The title is passed through **verbatim** (the caller formats `[KEY] <title>`). **Idempotent**: if an MR already exists for the branch (`glab mr view "$BRANCH"` succeeds), it updates that MR (`glab mr update "$BRANCH" --title … -d …`) instead of creating a duplicate. `--reviewer` may be repeated; `--target` defaults to the repo default branch; `--source-branch` overrides branch resolution (see *Source branch resolution* above) and is the way to drive this under jj-colocated detached HEAD. Prints the MR web URL on stdout (live). Exit `1` on an empty description. Fixture: reads `<dir>/mr.json` (`{"exists":true,"iid":42,…}` or `{"exists":false}`) and prints `CREATE` or `UPDATE iid=<iid>`.

## `create-issue.sh <title> <body-file|-> --repo <group/project> [--from-fixture <dir>]`

Creates a GitLab **issue** (work item) for plugin friction, used by the `plugin-feedback` skill's drain step. The target is `--repo <group/project>`: required in live mode; the skill reads `feedback_repo` from config. `glab issue create` has **no** `--description-file`, so the body is read into memory and passed via `-d`. `<body-file>` may be `-` for stdin. Prints **only the new issue's IID** on stdout (parsed from the returned `…/-/issues/<iid>` URL), so the skill can splice the `→ !N` pointer. Exit `1` on an empty body or an unparseable IID. Fixture: reads `<dir>/issue.json` (`{"iid":7,…}`) and prints that iid (no network).

## `mr-ready.sh [--from-fixture <dir>]`

`glab mr update --ready` on the current branch's MR — flip it out of draft. No stdout on success. Fixture: no-op success (the dir just has to exist).

## `pipeline-status.sh [--from-fixture <dir>]`

Reports the latest pipeline for the current branch's MR. Prints exactly one of `running` / `success` / `failed` / `none` on the first stdout line; when it's `failed`, a `---` line follows, then the failed job IDs one per line (feed each to `job-trace.sh`). Live mode: `GET …/merge_requests/<iid>/pipelines` (newest first → `.[0]`), then `GET …/pipelines/<pid>/jobs` for the failed job ids. Fixture: reads `<dir>/pipelines.json` (array, newest first, each `{id,status}`) and `<dir>/jobs.json` (array of `{id,status}`).

## `job-trace.sh <job-id> [--from-fixture <dir>]`

Prints the last ~200 lines of a CI job's trace (`GET …/jobs/<job-id>/trace` — the API form, since `glab ci trace` streams interactively). The failing tail is what `implement-ticket` needs to attempt a fix. Fixture: reads `<dir>/trace-<job-id>.txt`.

## Fixture mode

A fixture is a **directory** (not a single JSON file) under `tests/fixtures/`, because several helpers need *multiple* mocked responses per run (`post-mr-comment.sh` reads `info.json`, `discussions.json`, and `diff.json`; `pipeline-status.sh` reads `pipelines.json` and `jobs.json`). In `--from-fixture <dir>` mode a helper reads the files it needs *by filename* from that dir:

| Helper | Reads from `<dir>/` |
|---|---|
| `mr-fetch.sh discussions` | `discussions.json` |
| `mr-fetch.sh info` | `info.json` |
| `mr-fetch.sh diff` | `diff.json` |
| `post-mr-comment.sh` | `info.json`, `discussions.json`, `diff.json` (prints `CREATE … ANCHOR`/`CREATE … GENERAL`/`EDIT` decision; no network) |
| `create-mr.sh` | `mr.json` (prints `CREATE`/`UPDATE` decision; no network) |
| `create-issue.sh` | `issue.json` (prints the iid; no network) |
| `mr-ready.sh` | — (dir must exist; no-op) |
| `pipeline-status.sh` | `pipelines.json`, `jobs.json` |
| `job-trace.sh <id>` | `trace-<id>.txt` |

## Tests

`bash tests/run-tests.sh` — covers discussions-array handling + info; `post-mr-comment` CREATE vs EDIT branches + the computed `sha8`; `create-mr` CREATE vs UPDATE; `mr-ready` no-op; `pipeline-status` parsing `running`/`success`/`failed`/`none` + the failed-job-id list; `job-trace` tail; and bad-usage (exit 2) for every helper. All asserts pass on a clean checkout. CI should run this on every change to `scripts/forge/`.

## Adding a helper

1. Decide which fixture files the helper consumes; document them in the *Fixture mode* table above.
2. Add a fixture dir under `tests/fixtures/<case>/` with those files.
3. Add assertions to `tests/run-tests.sh`; run the harness and confirm they fail.
4. Write `scripts/forge/<helper>.sh`: `#!/usr/bin/env bash`, `set -u` + `set -o pipefail`, the standard `usage()` → exit 2, the `--from-fixture <dir>` branch, exit codes `0/1/2/3` as above, errors to stderr. Source `_lib.sh` and resolve the branch with `specto_source_branch` before any `glab mr` call; resolve project/MR via `glab repo view` / `glab mr view "$BRANCH"`. `chmod +x` it.
5. Run the harness again; confirm it passes. Wire the helper into the consuming skill/agent (never inline `glab` there).
