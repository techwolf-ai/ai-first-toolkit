# Reviewer posting protocol

Shared output + posting contract for every Specto reviewer agent (`product-review`, `scope-review`,
`okr-alignment-review`, `eng-review`, `change-classification-review`, `code-mr-review`). Each agent
keeps its own lane, finding-types, and one worked collect-format example inline; this file is the
single home for the mechanics they all share. If an agent body disagrees with this file on
mechanics, this file wins.

## The four fields

For each finding, capture four fields:

- **line** — the specific offending line of the problem text, **not** the section heading, so the
  comment lands where a reader fixes it. (Code reviewers anchor to **file + line** in the new code.)
- **section** — the spec section the finding is about (e.g. `§1.4`, `header`, `§2.1`). Code
  reviewers use the spec section for spec-adherence findings, else the file path.
- **finding-type** — the guideline/category that caught it (e.g. `too-many-metrics`,
  `no-sequence-diagram`, `classification-drift`). **Use the category you cite, not a freshly-worded
  phrase** — it is hashed into the dedup key (see below), so a stable slug keeps re-runs converging.
- **body** — one-line issue + one-line concrete recommendation (`*Fix:* …`).

## Two output modes

The dispatching skill (`review-spec` / `review-mr`) decides the mode by whether it passed `mr_iid` /
`project_path`:

- **Collect mode (default — `mr_iid` absent):** post nothing. Emit findings in the collect format
  below; the skill renders them inline for the author to triage and posts the approved survivors via
  the same helper. Emit every field the skill needs (section, line, finding-type, body).
- **Post mode (`mr_iid` and `project_path` set):** post each finding yourself as a line-anchored MR/PR
  discussion via the helper (see *Posting*).

## Collect format

One bullet per finding, grouped under a `### <section>` heading:

```
### §1.4
- **[too-many-metrics] line 42** — §1.4 lists 7 KRs; guidelines cap at 5. *Fix:* keep the 5 directly-controllable ones.
```

The `[finding-type]` and `line N` are the exact args the skill replays to `post-mr-comment.sh`; the
prose after the em-dash (issue + `*Fix:*`) is the comment body. If a finding is about content the MR/PR
did not change, still emit it — the helper posts it as a clearly-flagged general note when the skill
replays it.

## Posting (post mode)

Post each finding via the single vetted helper — never call the forge CLI (`glab`/`gh`) directly, never construct
`position[…]` params or the `[specto:…]` prefix yourself:

```text
"${CLAUDE_PLUGIN_ROOT}/scripts/forge/post-mr-comment.sh" <agent-name> <path-relative-to-repo> <line> <section> <finding-type> -
```

with the body piped on stdin (or a temp file instead of `-`). `<agent-name>` is your own name
(`product-review`, `eng-review`, …). The helper resolves the MR/PR's base/head/start SHAs (via
`mr-fetch.sh`), builds the line-anchored position, prefixes the body with
`[specto:<agent-name>#<sha8>]`, and posts **idempotently**. Just check the exit code (0 = posted or
updated).

## Dedup key + idempotency

`<sha8>` = first 8 hex of `sha1("<agent>\0<path>\0<normalized-section>\0<normalized-finding-type>")`.
The helper normalizes `section` and `finding-type` (lowercase, collapse punctuation), so casing and
spacing don't matter, and it does **not** hash the free-text body or the line number — only the
`(agent, path, section, finding-type)` tuple. Before posting, the helper fetches the MR/PR's discussions
and scans for that marker: if present it PUT-edits that note in place, otherwise it creates a new
discussion. So re-running an agent (or a whole `review-spec` fan-out) after the author fixes things
re-edits the existing thread instead of duplicating it, and the review surface converges. Corollary:
**one thread per `(section, finding-type)`** — don't bundle unrelated findings; two findings of the
same category in the same section collapse onto one thread by design. Do not put line numbers in the
`section` or `finding-type` args.

## Reading discussions

If you need to read existing MR/PR discussions for any reason, use
`"${CLAUDE_PLUGIN_ROOT}/scripts/forge/mr-fetch.sh" discussions` — never an ad-hoc
forge-CLI API call (e.g. `glab api … merge_requests/<iid>`).
