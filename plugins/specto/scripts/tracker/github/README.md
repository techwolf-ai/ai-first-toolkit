# specto / scripts / tracker / github

GitHub Issues as the tracker backend, over the `gh` CLI (assumes gh >= 2.94:
native sub-issues, issue types, and issue dependencies). Every helper mirrors
its `tracker/jira/` counterpart's argv exactly; the dispatcher passes argv
through verbatim, so callers never see which backend answered. Conventions
(`set -u`, `set -o pipefail`, `usage()` exit `2`, exit codes `0/1/2/3`,
`--from-fixture` offline mode, payload on stdout / warnings on stderr) follow
`docs/contracts.md`; normalized output shapes follow `docs/adapter-contract.md`.

## Concept mapping

| Specto concept | GitHub mapping |
|---|---|
| Ticket key | bare issue number (`123`); passed to gh verbatim, rendered `#123` only in prose |
| Project | the current repo checkout. `create-ticket.sh`/`active-sprint.sh` accept an `owner/repo` value to target another repo (exported as `GH_REPO` / used in the REST path); any other project value (`PROJ`, a board id) is accepted and ignored |
| Epic / parent | native sub-issue parent (`gh issue edit --set-parent`, `--json parent`, `--json subIssues`) |
| Ticket type | native issue type (`--json issueType`); an issue with sub-issues or an `epic` label reads as `Epic`; fallback `Issue` |
| Bodies | markdown in and out, byte-for-byte passthrough. There is NO ADF path here; `--description-adf-file` exits `4` |
| `blocks` link | native issue dependency. `link-tickets.sh blocks A B` ("A blocks B") writes `gh issue edit B --add-blocked-by A` (GitHub models the edge from the blocked side). gh's flags are unambiguous, so no read-back direction verify is needed (the acli `--in`/`--out` lie has no equivalent) |
| `relates` link | exit `4` (no native concept; a task-list mention is a v2 idea) |
| Impact / Priority | labels `impact:<v>` / `priority:<v>` (value lowercased); GitHub issues have no such fields |
| Sprint | milestone (documented degradation). Sprint id = milestone number; `active-sprint.sh` lists open milestones, `add-to-sprint.sh` resolves number -> title for `gh issue edit --milestone` |
| Status | state `open`/`closed` mapped to `To Do`/`Done`, plus a `status:*` label override on OPEN issues (see below) |
| Ticket URL | `gh issue view --json url` (no config needed, nothing hardcoded) |

## Status degradation (transition-ticket.sh / get-ticket-status.sh)

GitHub issues have two states, so the four canonical statuses map as:

| Canonical | Write (`transition-ticket.sh`) | Read (`get-ticket-status.sh`) |
|---|---|---|
| `done` | `gh issue close` (+ best-effort clears `status:*` labels) | state closed -> `Done`; state always wins when closed (a stale label never shadows it) |
| `todo` | `gh issue reopen` (+ best-effort clears `status:*` labels) | open, no `status:*` label -> `To Do` |
| `in_progress` | add label `status:in_progress`, swap out `status:in_review`, warn on stderr, exit 0 | open + `status:in_progress` -> `In Progress` |
| `in_review` | add label `status:in_review`, swap out `status:in_progress`, warn on stderr, exit 0 | open + `status:in_review` -> `In Review` |

`transition-ticket.sh` accepts the same synonym set the jira backend walks
(`Closed`/`Resolved`/`Complete` -> done, `Code Review`/`Review` -> in_review,
`Backlog`/`Open` -> todo, ...), case-insensitively, plus the canonical machine
tokens; it prints `transitioned_to=<display name>` and notes on stderr when
the input was not the resolved display name. Unknown `status:<v>` label values
print verbatim on read.

Labels: gh does not auto-create labels (unlike Jira's freeform labels), so
`create-ticket.sh`, `label-ticket.sh`, and the transition label path all retry
once after a best-effort `gh label create` when an edit/create is rejected.

## Degradations and unsupported verbs (exit 4)

| Surface | Behaviour |
|---|---|
| `epic-fields.sh` | always exit `4`: the change-classification profile (body-block parsing) is not yet wired for github; it lands with the compliance-profile milestone. Callers gate the classification feature off on exit 4 |
| `link-tickets.sh relates ...` (and any non-`blocks` type) | exit `4`, no native concept |
| `delete-links.sh --type <non-blocks>` | exit `4` |
| `create-ticket.sh --description-adf-file` | exit `4`, ADF is Jira-internal |
| Sprint = milestone | repos without milestones get clean empty output (`active-sprint.sh`) / a resolvable error (`add-to-sprint.sh`); Projects-v2 iterations are a v2 idea |
| `list-children.sh` child status | derived from the sub-issue state only (`OPEN` -> `To Do`, `CLOSED` -> `Done`); sub-issue entries carry no labels |
| `assign-ticket.sh` | assignee only; GitHub has no reporter field (the author is immutable), so the jira backend's reporter side-write has no equivalent |
| `delete-links.sh` edge ids | GitHub exposes no per-edge id, so ids are rendered as `<blocker>-blocks-<blocked>` (link ids are backend-opaque per the adapter contract) |

## Fixture table (`tests/fixtures/`)

Fixtures are backend-shaped: they mimic what `gh issue view --json ...` or the
REST endpoints return. Presence-only fixtures (any-content file = "the write
would succeed") are marked (p).

| Fixture | Shape / used by |
|---|---|
| `create-ok.json` | `{"number": 1234}`; create-ticket fixture create |
| `link-ok.json` (p) | link-tickets / set-parent / comment / assign / label / transition fixture success |
| `ticket-parent.json`, `ticket-parent-none.json` | `--json parent`; get-ticket-parent |
| `ticket-type-*.json` | `--json issueType,labels,subIssues`; get-ticket-type (native type / sub-issue epic / epic label / fallback) |
| `ticket-status-*.json` | `--json state,labels`; get-ticket-status (open, closed, label override, custom label, closed-beats-label) |
| `ticket-summary.json`, `ticket-no-title.json` | `--json title`; get-ticket-summary |
| `ticket-body.json`, `ticket-body-empty.json` | `--json body`; get-ticket-description markdown passthrough |
| `ticket-milestone*.json` | `--json milestone`; get-ticket-sprint (open, none, closed) |
| `milestones-*.json` | REST `milestones?state=open` array; active-sprint |
| `sprint-add-ok.json`, `sprint-add-error.json` | `{"status": ...}`; add-to-sprint |
| `deps.json`, `deps-empty.json` | `{"blocked_by": [...], "blocking": [...]}`; delete-links |
| `children.json`, `children-empty.json`, `children-missing.json` | `--json subIssues`; list-children |
| `malformed.json` | unparseable-JSON exit-1 paths |

## Tests

`bash tests/run-tests.sh`: fully offline via fixture mode plus a mock `gh`
binary prepended to PATH (the mock logs argv, captures body files/stdin, and
returns canned JSON), same two patterns as `forge/gitlab/tests/`. The suite is
auto-discovered by `scripts/tests/run-all.sh`. No live network calls anywhere.
