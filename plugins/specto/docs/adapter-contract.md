# Specto adapter contract

The normalized stdout contract every backend implementation of a dispatcher verb must honor. **Consumers (skills, agents, their jq expressions) may rely only on the guaranteed fields and lines below; adapters may emit more.** Anything not listed is backend-private and may disappear.

Ground rules:

- **v1 canonical shape = the GitLab-derived shape, trimmed to the fields consumers actually use.** `scripts/forge/gitlab/` and `scripts/tracker/jira/` emit it natively; other backends map their raw responses into it.
- **Fixtures are backend-shaped; decision lines are backend-neutral.** `--from-fixture` inputs mimic each backend's raw API/CLI responses, but the decision lines printed in fixture mode must be byte-identical across backends. That equality is the cross-backend test contract: adding a backend adds fixtures, never new expected lines.
- `iid` is the backend-neutral change-request number (GitLab MR iid, GitHub PR number).
- Exit codes follow the standard taxonomy (`0/1/2/3`, dispatcher-only `4`); see `docs/contracts.md`.

## Forge verbs

### Change-request object (`mr-fetch.sh info`; array of these: `find-mr-for-ticket.sh`)

| Field | Guarantee |
|---|---|
| `iid` | number (GitLab iid / GitHub PR number) |
| `web_url` | canonical browse URL |
| `title` | string |
| `state` | `opened` \| `merged` \| `closed` |
| `draft` | bool |
| `source_branch`, `target_branch` | strings |
| `diff_refs.{base_sha,head_sha,start_sha}` | anchor SHAs (backends without a distinct start SHA set `base_sha = start_sha`) |

### Thread array (`mr-fetch.sh discussions`)

One flat JSON array, all pages merged. Per thread: `id` (opaque string: GitLab discussion id, GitHub GraphQL thread node id) and `notes[]`, each note carrying `id`, `body`, `author.username`, `system` (bool), `resolvable` (bool), `resolved` (bool), `created_at`, and `position.{new_path,old_path,new_line,old_line}` (members null when the note is not line-anchored).

### Per-file diff array (`mr-fetch.sh diff`)

Per file: `new_path`, `old_path`, `diff` (unified hunks; `@@` headers are required, the anchor math parses them), and the bools `new_file`, `deleted_file`, `renamed_file`.

### Decision-line grammar

One line on stdout in fixture mode, grammar verbatim:

```
create-mr.sh:        CREATE
                     UPDATE iid=<n>
post-mr-comment.sh:  EDIT sha8=<8hex> discussion=<id> note=<id>
                     CREATE sha8=<8hex> ANCHOR new_line=<n> [old_line=<o>]
                     CREATE sha8=<8hex> GENERAL
mr-reply.sh:         REPLY_RESOLVE discussion=<id>
                     REPLY discussion=<id>
                     RESOLVE discussion=<id>
```

The idempotency marker `[specto:<agent-name>#<sha8>]` embedded in comment bodies is backend-invariant; it is what lets a re-run collapse onto the existing thread on any backend.

### Other forge payloads

| Verb | stdout |
|---|---|
| `create-mr.sh` (live) | the MR web URL |
| `mr-describe.sh` | live: the MR web URL; fixture: the spliced description |
| `mr-ready.sh` | nothing (exit codes only) |
| `pipeline-status.sh` | line 1 is one of `running` / `success` / `failed` / `none`; on `failed`, a `---` line then one failed job id per line (each consumable by `job-trace.sh` on the same backend) |
| `job-trace.sh <job-id>` | the last ~200 trace lines, plain text |
| `create-issue.sh` | the new issue's IID/number, nothing else |

## Tracker verbs

Neutral rules for every tracker backend:

- **Bodies are markdown, in and out.** ADF conversion is a Jira-internal detail (`md_to_adf.py` lives inside `scripts/tracker/jira/`); markdown-native backends pass bodies through untouched.
- **Ticket keys are opaque tokens** (`APP-123` Jira, `123` GitHub, `ENG-123` Linear). Scripts pass them through verbatim; only the model renders backend-native notation in prose.
- **Canonical link types:** `blocks` and `relates`. Backend-native type names pass through where the backend supports them.
- **Canonical statuses:** `todo` / `in_progress` / `in_review` / `done`, resolved by synonym walking: the backend tries the literal name, then its known synonyms, and warns on stderr which name actually matched.

| Verb | stdout contract |
|---|---|
| `create-ticket.sh <project> <epic\|-> <summary> <desc-file\|->` + flags | the new ticket key, nothing else; Blocks/BlockedBy links are created in the same invocation |
| `comment.sh <KEY> <body\|->` | nothing |
| `transition-ticket.sh <KEY> <status>` | `transitioned_to=<name>`; stderr warns when a synonym (not the literal) matched |
| `assign-ticket.sh <KEY> [assignee]` | nothing |
| `label-ticket.sh <KEY> <label>…` | nothing (additive; never clobbers existing labels) |
| `link-tickets.sh <type> <FROM> <TO>` | nothing |
| `delete-links.sh <KEY>… [--type T] [--dry-run]` | the deleted (or would-be-deleted) link ids |
| `set-parent.sh <KEY> <PARENT>` | nothing; exit `3` is a soft failure, the caller falls back to a `relates` link |
| `get-ticket-parent.sh <KEY>` | `<PARENT-KEY>\tparent` (real parent), `<PARENT-KEY>\trelates` (link-based fallback), or empty |
| `get-ticket-type.sh <KEY>` | the type string (`Epic` / `Task` / `Bug` / …) |
| `get-ticket-summary.sh <KEY>` | the title string |
| `get-ticket-status.sh <KEY>` | the live status name |
| `get-ticket-description.sh <KEY>` | the description as **markdown** |
| `get-ticket-sprint.sh <KEY>` | the active sprint/cycle id, or empty when not in one |
| `active-sprint.sh <board-or-team>` | one `<id>\t<name>` line per active sprint |
| `add-to-sprint.sh <SPRINT_ID> <KEY>` | nothing |
| `epic-fields.sh <EPIC> [--questions <json>]` | `key=value` lines: `flag_<id>=Yes\|No` per `--questions` entry, generic metadata (`development_stage=`/`epic_type=`/`delivery_cycle=`, empty on backends without fields), `classification=Standard\|Non-standard (<id> / <id>)\|unconfigured`, `resolved_via=`. Questions come from the repo compliance profile (`compliance:` block; `references/compliance-profile.example.yml`); WITHOUT `--questions` every backend prints `classification=unconfigured`, exit 0 (feature off). Jira resolves from epic fields (display name -> field id -> substring); github/linear parse a `### Change classification` checklist block from the epic body |
| `list-children.sh <EPIC>` | JSON array `[{key, summary, status, type}]` |
| `ticket-url.sh <KEY>` | the canonical browse URL |

## Adding a backend

Map the backend's raw responses into the shapes above; do not extend the guaranteed set without updating this file and the consumers' expectations together. Fixtures stay backend-shaped (they mimic your backend's API), but your fixture tests must print the same decision lines the existing suites assert. See `scripts/forge/README.md` / `scripts/tracker/README.md` for the mechanics.
