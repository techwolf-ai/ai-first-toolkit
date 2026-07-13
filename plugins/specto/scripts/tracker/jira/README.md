# specto / scripts / jira

Vetted helpers that read and write Jira data on behalf of Specto skills and agents. **One source of truth for every `acli` invocation** — skills and agents shell out to these, they never inline `acli`. Each helper accepts a `--from-fixture <path>` mode that reads a JSON file instead of calling `acli`, so the test harness runs offline.

Conventions shared by all helpers:

- `set -u` (+ `set -o pipefail` where it doesn't break intended behaviour).
- Warnings and errors go to **stderr**; the documented payload goes to **stdout**.
- Exit codes: `0` ok · `1` data missing / unparseable · `2` bad usage · `3` external-command failure (`acli` not on PATH, or an `acli` call errored).
- If `acli` isn't on PATH, exit `3` with a clear message.

## `epic-fields.sh <epic-key> [--from-fixture <path>]`

Reads the 3 non-standard-change answers + 3 classification metadata fields from a linked Jira epic. Output: one `key=value` per line — keys `q1_authn`, `q2_availability`, `q3_customer_data`, `development_stage`, `epic_type`, `delivery_cycle`, `classification`, `resolved_via`. The resolver tries the field's display name, then a known custom-field ID, then a substring match on question keys (3-tier fallback). Exit `1` if a *gating* field (Q1–Q3) is missing or the JSON is unparseable; optional metadata fields just warn.

## `create-ticket.sh <project-key> <epic-key> <summary> <description-file|-> [--blocks <KEY>]... [--blocked-by <KEY>]... [--from-fixture <path>]`

Creates a Jira **Task** (`--type Task --project <project> --summary <summary> --description-file <body> --label specto --parent <epic-key>`), reads the new key back from `acli ... --json`, and — **in the same invocation** — creates each Blocks / BlockedBy link (so a partial create can't leave a missing link). `<description-file>` may be `-` to read the body from stdin. Markdown descriptions are auto-converted to ADF via `md_to_adf.py`; ADF JSON inputs and `--description-adf-file <path>` pass through unchanged. A `resolve_customfields()` hook (3-tier, mirroring `epic-fields.sh`) returns a per-project `additionalAttributes` JSON object applied via a follow-up `acli jira workitem edit --from-json` — it is **empty by default** (no APP-only IDs hardcoded; extend the `case` to add a project map). Output: the new issue key on stdout, nothing else. Exit `1` if create succeeded but the key couldn't be parsed; `3` if create or any link create failed. Fixture: the JSON `acli create --json` would return (e.g. `{"key":"APP-1234"}`); the link loop runs against `link-tickets.sh`'s own fixture mode.

## `link-tickets.sh <link-type> <inward-KEY> <outward-KEY> [--from-fixture <path>]`

Thin wrapper over `acli jira workitem link create --type "<link-type>" --in <inward-KEY> --out <outward-KEY> --yes`. `--type` accepts the *outward* description (e.g. `Blocks`). `link-tickets.sh Blocks A B` means "A Blocks B". No stdout on success.

## `assign-ticket.sh <KEY> [<assignee>] [--from-fixture <path>]`

Sets the assignee (`acli jira workitem assign`; default `@me`). When an explicit account ID / email is passed (not `@me`/`default`), also best-effort sets `reporter` via `acli jira workitem edit --from-json` — a locked reporter field is a stderr warning, not a failure. No stdout on success; exit `3` if the assignee call itself fails.

## `transition-ticket.sh <KEY> <target-status> [--from-fixture <path>]`

Transitions the issue, with **workflow-name fallback discovery**. `acli` has no "list transitions" flag, so live mode tries the literal status name and then walks known synonyms — `To Do`→{`Backlog`,`Open`,`Selected for Development`}, `In Progress`→{`Doing`,`Started`,`In Development`}, `In Review`→{`Code Review`,`Review`,`In Code Review`,`Peer Review`}, `Done`→{`Closed`,`Resolved`,`Complete`} — and the first accepted name wins. Prints `transitioned_to=<name>` on stdout; warns to stderr when a synonym (not the literal name) matched. Exit `1` if no name was accepted; `3` if every `acli` attempt errored at the infra level. Fixture: a JSON array of the workflow's available status names (e.g. `["Backlog","In Progress","Code Review","Done"]`) — the helper picks the first literal/synonym present in that array.

## `comment.sh <KEY> <body-file|-> [--from-fixture <path>]`

Posts a comment via `acli jira workitem comment create`. Reads the body from a file, or stdin when `<body-file>` is `-`. Markdown bodies are auto-converted to ADF via `md_to_adf.py` and posted via `--body-file`; ADF JSON bodies pass through. Falls back to `--body <string>` on conversion failure or missing python3. Exit `1` on an empty body. No stdout on success.

## `add-to-sprint.sh <SPRINT_ID> <KEY> [--from-fixture <path>]`

Places `<KEY>` into sprint `<SPRINT_ID>` via the Jira **Agile REST API** (`POST /rest/agile/1.0/sprint/<id>/issue` with `{"issues":["<KEY>"]}`). Bypasses `acli` entirely because `create-ticket.sh`'s `--sprint-id` follow-up (`acli jira workitem edit --key … --from-json …`) errors with `if any flags in the group [key jql filter generate-json from-json] are set none of the others can be` on several `acli` versions, silently dropping the ticket to the backlog. Auth: set `JIRA_EMAIL` and `JIRA_API_TOKEN`. Each may be a literal value or an `op://<vault>/<item>/<field>` 1Password reference (resolved via `op read` when the 1Password CLI is on PATH); if either is missing, exits `3` with a clear message + the board URL. `JIRA_SITE` resolves from the env var, then the tenant profile (`.specto/tracker-jira.yml` `site`), then plugin-config `jira_site`; unset everywhere exits `3` with guidance. The legacy one-arg form (`add-to-sprint.sh <KEY>`) is preserved for backwards compatibility (no-op + warning, exit `0`). Fixture modes: the new `{"status":"ok"}` / `{"status":"error","error":"..."}` shapes for the two-arg path, and the legacy `{"board_id","active_sprint":...}` shape for the one-arg path.

## `get-ticket-type.sh <KEY> [--from-fixture <path>]`

Reads `.fields.issuetype.name` (Epic / Task / Bug / Story / Test Plan / …) and prints it on stdout. Sibling of `get-ticket-summary.sh`. Used by `create-ticket` and `create-test-plan` to probe a would-be-parent before passing it to `--parent` — `acli` rejects with "Given parent work item does not belong to appropriate hierarchy" when the supposed epic is actually a Task (a common labelling trip wire).

## `get-ticket-parent.sh <KEY> [--from-fixture <path>]`

Reads the parent key with the Task-as-epic fallback baked in: tries `.fields.parent.key` first, then falls back to the first inward `Relates` link's outward key. Prints `<KEY>\tparent` for a real `--parent` link, `<KEY>\trelates` for the Relates-based fallback, or nothing if the ticket has no parent. Used by `create-test-plan` to mirror the implementer's parent onto the Test Plan regardless of which mechanism wired it.

## `get-ticket-sprint.sh <KEY> [--from-fixture <path>]`

Reads `.fields.customfield_10020[]` (Jira's standard Sprint customfield), filters to the array's first ACTIVE sprint, and prints its id on stdout. Empty stdout means "not in an active sprint". Used by `create-test-plan` to mirror the implementer's sprint onto the Test Plan via `add-to-sprint.sh`.

## `md_to_adf.py`

Reads Markdown on stdin, emits ADF JSON on stdout. Used by `create-ticket.sh` and `comment.sh` to auto-convert Markdown bodies before they reach acli. Supports ATX headings (1–6), paragraphs, bullet / ordered lists, blockquotes, fenced code blocks, and inline `**strong**` / `` `code` `` / `[text](url)` / bare URLs. Tables, nested lists, images, and HTML are not supported — write ADF JSON by hand if you need them. Exit `0` with ADF on stdout; `1` on empty input. Complement of `get-ticket-description.sh`.

## `render-mermaid.py`

Reads a JSON ticket list on stdin (`[{"id": "M1-SE1", "version": "V-Agent", "blocked_by": [...], "short_label": "..."}, ...]`), emits a `flowchart LR` mermaid source on stdout. Nodes coloured per version (`V-Agent` blue / `V-Console` green / `V-plus` orange); edges from `blocked_by`; optional `short_label` adds a second line to each node label. Used by `plan-to-tickets` at the end of a run to print a dependency graph in the agent's stdout (and save to `.specto/dep-graph.mmd`) — does **not** push to Jira. Exit `0` with mermaid on stdout; `1` on empty / unparseable input.

## `get-ticket-description.sh <KEY> [--from-fixture <path>]`

Runs `acli jira workitem view <KEY> --json --fields description` and renders the **Atlassian Document Format** description tree (at `.fields.description`) to plain **Markdown** on stdout — headings → `#`/`##`/…, paragraph → text, `bulletList`/`orderedList` → `- `/`1. `, `codeBlock` → fenced ```` ``` ````, `rule` → `---`, `blockquote` → `> `, text marks `strong`→`**bold**` / `em`→`_italic_` / `code`→`` `code` ``, `link`/`inlineCard`/`mention` → `[text](url)`, hard breaks → newline. The tree walk is a recursive `jq` program (no `python`). Exit `1` if the JSON is unparseable or there's no ADF description; used by `implement-ticket` to read the ticket body + acceptance criteria + spec link. Fixture: a work-item JSON object with a realistic `.fields.description` ADF node.

## Tests

`bash tests/run-tests.sh` — fixtures live in `tests/fixtures/` (read-only JSON). Covers happy paths, the customfield-fallback no-op, the transition workflow-name fallback (literal absent → synonym matched), missing-active-sprint, malformed/empty ADF, and bad-usage (exit 2) for every helper. All asserts pass on a clean checkout. CI should run this on every change to `scripts/tracker/`.

### acli flag notes (verified at authoring time)

- Comments: `acli jira workitem comment create --key … --body …` (not `comment add`).
- Links: `acli jira workitem link create --type <outward-desc> --in <inward> --out <outward> --yes` (flags are `--in`/`--out`, **not** `--inward`/`--outward`).
- Transitions: `acli jira workitem transition --key … --status … --yes` — there is **no** flag to list available transitions, hence the attempt-and-retry fallback above.
- No `acli` board/sprint command exists, so `add-to-sprint.sh` calls the Jira Agile REST API (`POST /rest/agile/1.0/sprint/<id>/issue`) directly via `curl`.
- `acli jira workitem edit --key … --from-json …` is rejected on several `acli` versions with "if any flags in the group [key jql filter generate-json from-json] are set none of the others can be". `create-ticket.sh`'s post-create `additionalAttributes` follow-up therefore silently drops sprint placement to the backlog; use `add-to-sprint.sh` instead of `--sprint-id`.
