# specto / scripts / tracker / linear

The Linear implementation of every tracker verb, dispatched to when the tracker backend resolves to `linear` (see `scripts/tracker/README.md` for selection precedence; `LINEAR_API_KEY` being set is the autodetect signal). GraphQL-over-curl: there is no CLI dependency. Every verb is a thin query/mutation over the single transport `_gql.sh`; no verb touches the network directly.

Why scripts and not Linear's official MCP server: specto's helpers are called from dispatched subagents (which cannot rely on the parent session's MCP connections), from CI runners (no interactive MCP auth), and from a fixture-based offline test harness — all three rule out MCP as the transport. The official MCP (`mcp.linear.app`) remains a fine complement for ad-hoc interactive Linear queries in a Claude session; specto's contract paths just never depend on it.

## Transport: `_gql.sh`

`_gql.sh [--from-fixture <file>] <query> [<variables-json>]` POSTs `{query, variables}` to `https://api.linear.app/graphql` (override with `SPECTO_LINEAR_ENDPOINT`; the offline test harness points it at a mock curl). It prints the response's `.data` on stdout, surfaces every `errors[].message` on stderr with exit `3`, and exits `3` on transport failures.

Auth: `LINEAR_API_KEY`, either a literal personal API key or a 1Password reference (`op://<vault>/<item>/<field>`, resolved via `op read`). The key goes in a bare `Authorization: <key>` header. It is NEVER placed on curl's argv (ps leakage): the header rides a mode-0600 `curl -K` config file and the body rides stdin. The test suite asserts this.

## Mapping decisions (jira-argv parity, Linear semantics)

Every verb mirrors its `../jira/` counterpart's argv exactly. The semantic mapping:

| Concept | Linear mapping |
|---|---|
| Ticket key | The issue identifier (`ENG-123`), passed through opaquely |
| Project | The `<project>` positional is the Linear TEAM key; `-` falls back to config: `project` (repo `.specto/config.yml`, then machine), then `linear_team` (machine) |
| Epic | A parent issue: `create-ticket <epic>` / `set-parent` map to `parentId`; `get-ticket-parent` reads `issue.parent.identifier`, falling back to the first `related` relation (`<KEY>\trelates`) |
| Type | Derived, not native: has children -> `Epic`; else the first `bug`/`task`/`story` label (case-insensitive) capitalized; else `Issue`. `create-ticket --type <T>` attaches the lowercase `<T>` label for non-Task types so the round trip works |
| Status | Workflow states: `transition-ticket` lists `issue.team.states`, walks the same synonym table as jira (To Do -> Backlog/Open/..., Done -> Closed/Resolved/...), applies `issueUpdate(stateId)`, and prints the same `transitioned_to=<name>` line; no match exits `1` listing the available states |
| Sprint | A cycle, 1:1: `active-sprint <team>` lists `isActive` cycles as `<id>\t<name>` rows (nameless cycles render `Cycle <number>`); `add-to-sprint` / `create-ticket --sprint-id` set `cycleId`; `get-ticket-sprint` reads `issue.cycle.id` |
| Links | `issueRelationCreate` / `issueRelationDelete`. Canonical names map: `blocks`->`blocks`, `relates`->`related`, `duplicate`->`duplicate`; anything else exits `4` (Linear has no custom link types). Direction is self-verified by read-back after every live create |
| Bodies | Markdown-native, byte-for-byte passthrough in and out. No ADF anywhere; `create-ticket --description-adf-file` exits `4` |
| Priority | `--priority` maps names onto Linear's 0-4 scale: `urgent=1`, `high=2`, `medium=3`, `low=4` (`0`=none); raw 0-4 passes through; unknown values warn and skip |
| Impact | `--impact <v>` becomes a label `impact:<v>` (lowercased); Linear has no impact field |
| Labels | Found case-insensitively (`issueLabels(filter:{name:{eqIgnoreCase}})`), created via `issueLabelCreate` when missing; the `specto` label is always applied on create; `label-ticket` is additive (`issueAddLabel`) |
| Assignee | `issueUpdate(assigneeId)`; `@me` resolves via `viewer`; explicit values match by email, then display name. Linear's creator is immutable, so jira's best-effort reporter step has no equivalent |
| URL | `ticket-url` reads `issue.url` (the workspace slug is embedded by the API; nothing tenant-shaped is configured or hardcoded) |
| epic-fields | Exit `4`: the change-classification profile is not yet wired for linear (issues have no custom fields; the future path is a `source: body` block on the parent issue). The exit gates the classification feature off cleanly for callers |

`ticket-url.sh` carries a `--from-fixture` mode the jira counterpart lacks (jira builds its URL offline from config; this one performs a read). Callers passing just `<KEY>` are unaffected.

## Tests

`tests/run-tests.sh` is fully offline, two patterns:

1. **Fixture mode**: fixtures in `tests/fixtures/` are raw GraphQL responses (backend-shaped: `{"data": ...}` / `{"errors": [...]}`) routed through `_gql.sh --from-fixture`. Mutation verbs' fixtures are the canned response for their final mutation; the preliminary resolution queries are live-only.
2. **Mock curl on PATH**: live paths run against a mock `curl` that logs argv, the `-K` auth config file, and the stdin body, answering canned responses keyed on the request body. This asserts the endpoint, mutation names + variables shapes, priority mapping, synonym-walked state picks, direction verification, and that the API key never appears on argv.

| Fixture | Feeds |
|---|---|
| `gql-ok/gql-errors/gql-malformed.json` | `_gql.sh` transport contract (data passthrough, errors[] -> exit 3, unparseable -> exit 1) |
| `create-ok/create-no-key.json` | `create-ticket.sh` |
| `link-ok.json` | `link-tickets.sh` + `create-ticket.sh`'s link loop |
| `comment-ok.json` | `comment.sh` |
| `update-ok/update-fail.json` | `assign-ticket.sh`, `set-parent.sh`, `add-to-sprint.sh` |
| `label-add-ok.json` | `label-ticket.sh` |
| `states-altnames/states-weird.json` | `transition-ticket.sh` synonym walk |
| `relations-multi/relations-empty.json` | `delete-links.sh` (de-dupe across both directions, type filter) |
| `ticket-parent-*.json` | `get-ticket-parent.sh` (parent / relates / inverse / none) |
| `ticket-type-*.json` | `get-ticket-type.sh` (Epic / label / Issue fallback) |
| `ticket-status/ticket-summary/ticket-desc*/ticket-sprint*.json` | the scalar read verbs |
| `cycles-*/team-missing.json` | `active-sprint.sh` |
| `children/children-none.json` | `list-children.sh` |
| `url.json` | `ticket-url.sh` |

Run it directly (`bash tests/run-tests.sh`) or via `scripts/tests/run-all.sh`, which globs it up automatically.
