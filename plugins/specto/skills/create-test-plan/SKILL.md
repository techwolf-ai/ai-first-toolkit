---
name: create-test-plan
description: Use when an existing non-standard implementation ticket needs a paired Test Plan ticket — the manual verification gate that automated tests can't cover (public ingress exposure, multi-step migrations touching production users, auth/role changes, cutovers). Triggers on "create a test plan", "add a test plan", "write a test plan", "test plan for <ticket key>", or "pair a test plan with <ticket key>". Builds the ADF document, creates the Test Plan via `scripts/tracker/create-ticket.sh --type "Test Plan"`, and links it to the implementer via a configurable link type (default `Relates`). For batch creation under a fresh epic, use `plan-to-tickets` instead.
argument-hint: "<implementation ticket key>"
allowed-tools: Bash, Read, AskUserQuestion
---

# create-test-plan

Create a paired `Test Plan` ticket for an existing non-standard implementation ticket. Links the Test Plan back to the implementer via the configured link type (default `Relates`) so tracker automation and any compliance bot see the pairing.

This skill is for the "implementer ticket already exists; add the Test Plan after the fact" case. For batch creation of Test Plans alongside fresh implementation tickets under an epic, defer to `plan-to-tickets` / `populate-epic`.

**Invocation.** This skill is intentionally model-invocable (no `disable-model-invocation`) so a compliance flow can reach it, but creating a Jira ticket is a real, non-idempotent side effect — so step 5 **stops for an explicit confirmation** (via `AskUserQuestion`) before any `create-ticket.sh` call. A re-run without that confirmation creates a duplicate Test Plan.

**Link type override.** The default is `Relates`. Compliance-gated tenants usually expose a reviews-shaped link type (a name whose outward description is "reviews" — sometimes literally `reviews`, sometimes another tenant-specific name) that their merge-gating automation requires; plain `Relates` does not satisfy such a bot. To override, set `SPECTO_TEST_PLAN_LINK_TYPE` in the environment, OR `test_plan_link_type` in the repo's `.specto/tracker-jira.yml`, OR the machine-level plugin-config key:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/plugin-config.sh" set jira_test_plan_link_type "reviews"
```

The skill resolves the link-type name in that order (env, then repo `tracker-jira.yml`, then plugin-config), falling back to the default. Run `acli jira workitem link type` to list the names a tenant actually exposes when unsure.

## Prerequisite check

- `acli` is on PATH and authenticated.
- The implementation ticket key is supplied (argument) or the user can name it.
- The change actually is non-standard. If the user can't articulate the invariant a Test Plan protects in one sentence, ask before continuing — a Test Plan on a standard change is bureaucratic dead weight.

## Critical rules

- **Type is exactly `Test Plan`** (case sensitive). Pass `--type "Test Plan"` to the helper — do not rely on auto-detection from the summary.
- **Link type defaults to `Relates`** — override it when your tenant's compliance automation requires a specific reviews-shaped link type. Full default + override mechanics in the *Link type override* note above; applied at step 6.
- **`acli` link direction is inverted** — the implementer key is `--out`, the Test Plan key is `--in`. Exact `link-tickets.sh` mapping at step 6 (the call site); get it backwards and the compliance link points the wrong way.
- **`taskItem` content is inline runs — NEVER wrapped in `paragraph`.** Most common ADF mistake; acli rejects with `INVALID_INPUT` when `taskItem.content[0].type == "paragraph"`.
- **Never tick the boxes on behalf of the user.** The Test Plan is for humans to walk; the orchestrator only posts evidence comments.

## Inputs the user provides

- **Implementation ticket key** (argument). Matches `[A-Z]+-\d+`. Otherwise ask.

## Steps

### 1. Resolve the implementation ticket

```bash
IMPL_KEY="ABC-1991"     # from argument or AskUserQuestion
IMPL_SUMMARY="$("${CLAUDE_PLUGIN_ROOT}/scripts/tracker/get-ticket-summary.sh" "$IMPL_KEY")"
```

`get-ticket-summary.sh` is the single vetted read path for the ticket title (`.fields.summary`). It exits non-zero on auth / key / network failure — propagate that to the user, do NOT fabricate a summary.

### 2. Decide what makes the change non-standard

Frame in one short sentence: *we want to do X because Y; the risk is W if Z isn't held*. If you can't fill all three slots, the change is either standard or under-specified.

Filter out:

- **Pure feature additions** that introduce no failure mode for existing users (no Test Plan needed).
- **The setup half of a phased rollout.** Turning on shadow mode is not the risky step; the risky step is the rollout *after* shadow has run quietly. The Test Plan belongs on the rollout, not the toggle.

What remains is the part where *something users rely on could break in a way automated tests don't catch*. That's the only thing a Test Plan should cover.

#### Hunt edge cases before drafting risks

The "happy path" risk ("the new code works for typical users") rarely earns a Test Plan on its own — it's usually covered by automated tests. The Test Plan exists because the *edges* are the unsafe part. Before drafting the Risks section, force yourself to enumerate:

- **Sentinel / absent fields.** What if the new field is null / missing / empty? Migrating users may have it unset (e.g. unmigrated metadata with no `plan_tier` field). Does old behaviour still hold?
- **Full vs partial coverage.** If a grant collapses N items into one parent (family, group, role), what happens when the user has only some? Does that promote silently? Stay explicit? Drop access?
- **Boundary values.** The first / last / single-element case in any list; the 0 / 1 / max input; the just-below / just-above-threshold case (e.g. ~1000 tags against a 32KB metadata ceiling).
- **Wildcard vs empty.** A wildcard grant (`["*"]`) and an empty grant (`[]`) often share serialisation but have opposite semantics. Confirm neither flips into the other.
- **Cross-system roundtrips.** If the same data lives in two stores (identity provider + profile store; DB + cache), does writing one but not the other leave a consistent state?

Each surviving edge becomes its own Rn in the Risks section, with a case that drives it.

### 3. Structure the plan

Four required sections, in order. Add `Rollout cadence` only for multi-step rollouts. Skip `Pre-requisites` unless the verifier truly needs setup that isn't obvious from the cases.

- **Context** — one short paragraph: *we want to do X because Y, and automated tests can't fully prove the invariant because [shape-driven / requires real users / cross-system / etc.].* No risks here, no background, no link soup.
- **Risks** — a bullet per risk. The template auto-prefixes each bullet with **R1 —**, **R2 —**, … so cases can reference them. Phrase each as the failure mode in human terms: *"R1 — Unmigrated oversized accounts can't load the dashboard after the deploy."* If you can't name two or three concrete risks, the change probably isn't non-standard.
- **Rollout cadence** (multi-step only) — staging → prod per step; for shadow → rollout, frame as "shadow must reveal no anomalies before the rollout step starts."
- **Pre-requisites** (optional) — one-liners. 1Password path for real-user creds, branch SHA, anything else the verifier can't infer.
- **Test cases** — each case prefixes the title with the risk id(s) it covers: `1. (R1) Title.` or `2. (R1, R2) Title.`. The template renders **bold title** + setup + **bold "Expected:"** + expected outcome, so split your input into `{title, setup, expected}` — don't pre-concatenate.
- **Sign-off** (optional) — extra gates beyond "all cases pass". Skip entirely when the case-pass criteria are the only thing that matters; only add when there's a real per-environment or soak gate.

Risk-to-case mapping is the load-bearing structure: a reviewer must see every `Rn` referenced by at least one case, and every case must reference at least one `Rn`. The template doesn't enforce this — the orchestrator does, in step 5's confirmation summary.

### 4. Build the ADF document

Render the ADF via the vetted jq template at `${CLAUDE_PLUGIN_ROOT}/references/test-plan-adf-template.jq`. The template encodes the `taskItem.content`-not-wrapped-in-`paragraph` invariant **once, at the structural level** — caller-side mistakes can't reintroduce it. Inputs are JSON arrays of plain-text strings (or `{title, body}` for cases), so there's no JSON-in-shell quoting to break.

```bash
adf_tmp="$(mktemp -t testplan-adf.XXXXXX)"
jq -n \
  --arg     context "$CONTEXT_PARA" \
  --argjson risks   "$RISKS_JSON"    \
  --argjson prereqs "$PREREQS_JSON"  \
  --argjson cases   "$CASES_JSON"    \
  --argjson signoff "$SIGNOFF_JSON"  \
  --argjson rollout "$ROLLOUT_JSON"  \
  -f "${CLAUDE_PLUGIN_ROOT}/references/test-plan-adf-template.jq" \
  > "$adf_tmp"
```

Input shapes (build these from the user's input + your structure decisions in steps 2–3):

| Variable | Type | Example |
|---|---|---|
| `$CONTEXT_PARA` | string | `"We want X because Y. Automated tests can't fully prove this because the failure mode is shape-driven across real metadata payloads we don't synthesise in CI."` |
| `$RISKS_JSON`   | `[string]` | `'["Unmigrated oversized accounts can no longer load the dashboard after the deploy.", "OR-merge silently prefers one field over the other."]'`. Template auto-prefixes each with `R1 —`, `R2 —`, …. |
| `$PREREQS_JSON` | `[string]` | `'[]'` to skip (default); else `'["1Password path: vault/key."]'`. Skip unless the verifier truly needs setup. |
| `$CASES_JSON`   | `[{title, setup, expected}]` | `'[{"title":"1. (R1) Unmigrated account keeps dashboard access.","setup":"Sign in as the seeded large-account user on staging and load the dashboard.","expected":"Page renders within normal latency; visible record set matches the pre-MR baseline for this user."}]'`. Title MUST start with `(Rn[, Rm])`. Don't pre-concatenate setup + expected — the template bolds "Expected:" for you. |
| `$SIGNOFF_JSON` | `[string]` | `'[]'` to skip (default); else `'["Both prod regions soak 24h before promoting tenant-by-tenant."]'`. Skip when "all cases pass" is the only gate. |
| `$ROLLOUT_JSON` | `[string]` | `'[]'` for single-deploy; `'["Shadow run: no profile-store discrepancy logs above threshold X for 48h.", "Rollout: flip feature flag tenant-by-tenant; abort if shadow signal regresses."]'` for shadow → rollout. |

**Title prefix convention.** The template wraps each case's `title` in `strong` (bold) marks, leaving `body` as plain text — match the **`<n>. <Title>.`** + concrete-body shape from step 3. The trailing space between title and body is added by the template; don't include it yourself.

**Escape hatch for inline runs.** Inline `code` / `link` marks (e.g. `\`GET /skills\``) are not modelled by the template's `{title, body}` shape. If a case genuinely needs inline marks, build the ADF for that case manually using `text` nodes with marks (`code` for inline code, `strong` for bold, `link` with `attrs.href` for links) and splice it into `$CASES_JSON` as a raw element. The template's `taskItem`-no-paragraph invariant still holds — only the inline runs change.

Lint guard: the jq template ships with `scripts/tracker/jira/tests/run-tests.sh` assertions that fail if any `taskItem.content[0].type == "paragraph"`. The regression is caught by the test runner, not just code review.

### 5. Create the Test Plan ticket

Resolve the link-type name first so it can appear in the confirmation summary:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib/config.sh"
LINK_TYPE="${SPECTO_TEST_PLAN_LINK_TYPE:-}"
[[ -z "$LINK_TYPE" ]] && LINK_TYPE="$(specto_yaml_get .specto/tracker-jira.yml test_plan_link_type)"
[[ -z "$LINK_TYPE" ]] && LINK_TYPE="$("${CLAUDE_PLUGIN_ROOT}/scripts/plugin-config.sh" get jira_test_plan_link_type 2>/dev/null || true)"
[[ -z "$LINK_TYPE" ]] && LINK_TYPE="Relates"
```

**Confirmation gate (required).** Before any Jira write, present the proposed Test Plan to the user with `AskUserQuestion` — show the implementation ticket key, the Test Plan title (`[$IMPL_KEY] Test plan: $IMPL_SUMMARY`), and the link-type `$LINK_TYPE` that will be applied — and only proceed once they confirm. Creating a ticket is non-idempotent; do not skip this gate just because the inputs look complete.

Resolve the Jira project:

```bash
JIRA_PROJECT="$("${CLAUDE_PLUGIN_ROOT}/scripts/plugin-config.sh" get jira_project 2>/dev/null || true)"
[[ -z "$JIRA_PROJECT" ]] && JIRA_PROJECT="${IMPL_KEY%-*}"
```

Then call the helper. The Test Plan is standalone (no parent epic) — pass `-` (or `--no-epic`) for the epic positional, and `-` for the description-file positional since `--description-adf-file` supersedes it:

```bash
TEST_PLAN_KEY="$(
  "${CLAUDE_PLUGIN_ROOT}/scripts/tracker/create-ticket.sh" \
    "$JIRA_PROJECT" - "[$IMPL_KEY] Test plan: $IMPL_SUMMARY" - \
    --type "Test Plan" \
    --no-epic \
    --description-adf-file "$adf_tmp" \
    --label non-standard-change \
    --assign
)"
rm -f "$adf_tmp"
```

The helper prints **only** the new key on stdout. Capture it as `TEST_PLAN_KEY`. Get the URL from `"${CLAUDE_PLUGIN_ROOT}/scripts/tracker/ticket-url.sh"` `${TEST_PLAN_KEY}`.

### 6. Link the Test Plan to the implementer

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/tracker/link-tickets.sh" "$LINK_TYPE" "$TEST_PLAN_KEY" "$IMPL_KEY"
```

`link-tickets.sh <link-type> <inward> <outward>` maps to `acli ... --type "$LINK_TYPE" --in <TEST_PLAN_KEY> --out <IMPL_KEY>` — the implementer is the outward key, the Test Plan the inward key. The acli success message reads the two backwards but the stored link is the right way around; `link-tickets.sh` self-verifies the direction after the create. (`$LINK_TYPE` was resolved in step 5 — default `Relates`, override per the *Link type override* note.)

### 6b. Mirror the implementation ticket's parent and sprint

The Test Plan should sit alongside the implementer in the same epic and the same sprint — otherwise the reviewer has to hunt for it.

**Mirror the parent.** Probe the implementer's parent the same way `create-ticket` does:

```bash
PARENT_LINE="$("${CLAUDE_PLUGIN_ROOT}/scripts/tracker/get-ticket-parent.sh" "$IMPL_KEY" 2>/dev/null || true)"
PARENT_KEY="${PARENT_LINE%%$'\t'*}"
PARENT_MECH="${PARENT_LINE#*$'\t'}"
```

- `PARENT_LINE` empty → implementer has no parent; skip this step.
- `PARENT_MECH == "parent"` → real Epic; check its type and either re-apply the parent via `scripts/tracker/set-parent.sh` (preferred; exits 3 when the `acli` version doesn't support `edit --parent`) OR add a `Relates` link as a fallback so the Test Plan at least surfaces under the epic in search.
- `PARENT_MECH == "relates"` → Task-as-epic; mirror with a `Relates` link.

```bash
if [[ -n "$PARENT_KEY" ]]; then
  PARENT_TYPE="$("${CLAUDE_PLUGIN_ROOT}/scripts/tracker/get-ticket-type.sh" "$PARENT_KEY" 2>/dev/null || true)"
  if [[ "$PARENT_TYPE" == "Epic" ]]; then
    # Best-effort: re-apply parent via the vetted helper. If it exits 3 (some acli
    # versions don't support `edit --parent`), fall through to the Relates fallback.
    if ! "${CLAUDE_PLUGIN_ROOT}/scripts/tracker/set-parent.sh" "$TEST_PLAN_KEY" "$PARENT_KEY"; then
      "${CLAUDE_PLUGIN_ROOT}/scripts/tracker/link-tickets.sh" Relates "$TEST_PLAN_KEY" "$PARENT_KEY"
    fi
  else
    "${CLAUDE_PLUGIN_ROOT}/scripts/tracker/link-tickets.sh" Relates "$TEST_PLAN_KEY" "$PARENT_KEY"
  fi
fi
```

**Mirror the sprint.**

```bash
IMPL_SPRINT_ID="$("${CLAUDE_PLUGIN_ROOT}/scripts/tracker/get-ticket-sprint.sh" "$IMPL_KEY" 2>/dev/null || true)"
if [[ -n "$IMPL_SPRINT_ID" ]]; then
  if ! "${CLAUDE_PLUGIN_ROOT}/scripts/tracker/add-to-sprint.sh" "$IMPL_SPRINT_ID" "$TEST_PLAN_KEY"; then
    TICKET_URL="$("${CLAUDE_PLUGIN_ROOT}/scripts/tracker/ticket-url.sh" "$TEST_PLAN_KEY")"
    BOARD_URL="${TICKET_URL%%/browse/*}/jira/software/projects/${TEST_PLAN_KEY%-*}/boards"
    echo "warning: $TEST_PLAN_KEY landed in the backlog; drag it to sprint $IMPL_SPRINT_ID manually: $BOARD_URL" >&2
  fi
fi
```

Sprint placement is best-effort; surface any warning to the user with the board URL so they can drag the Test Plan into the right sprint manually. `add-to-sprint.sh` uses the Jira Agile REST API and needs `JIRA_EMAIL` + `JIRA_API_TOKEN` (each may be a literal value or an `op://<vault>/<item>/<field>` 1Password reference) — without them the helper exits 3 with a clear message and the Test Plan lands in the backlog.

### 7. Output

Return:

- Test Plan key + URL.
- One-line confirmation: `Test Plan ABC-XXXX reviews ABC-YYYY (linked via $LINK_TYPE).` Mention the mirrored parent and sprint when set: `… (linked via $LINK_TYPE, under <PARENT>, in sprint <SPRINT_ID>).`
- Reminder that your organization's designated security reviewer, if your compliance profile requires one, must approve the Test Plan before the implementer's MR can merge. The reviewer is assigned by the implementing dev when the MR is ready, not at ticket-creation time.

### Posting evidence comments

Post evidence on the Test Plan ticket as test cases land; never tick the description boxes. Re-paste the relevant checkbox with `- [x]` and a paragraph of proof underneath. `comment.sh` runs the body through `md_to_adf.py`, which recognises GFM checkboxes and emits ADF `taskList` / `taskItem` (`DONE` for `[x]`, `TODO` for `[ ]`) — so the comment renders with real Jira checkboxes, not literal `[x]`.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/tracker/comment.sh" "$TEST_PLAN_KEY" - <<'MD'
## Section — proof

- [x] **First case title.**

  Unit test `path/to/test.py::TestClass::test_first_case`. Staging echo: jobs `527 → 8`.

- [x] **Second case title.**

  Confirmed against staging deploy at SHA `<sha8>`.
MD
```

## Common mistakes

| Mistake | Effect |
|---|---|
| Wrapping `taskItem` content in `paragraph` | acli rejects with `INVALID_INPUT`. The jq template at `references/test-plan-adf-template.jq` makes this structurally impossible for the common case; the test runner catches it for the manual-inline-runs escape hatch. |
| Leaving the default `Relates` on a compliance-gated tenant | The tenant's merge-gating bot blocks the MR with no actionable hint — it looks for the tenant's reviews-shaped link type, which `Relates` is not. Configure `test_plan_link_type` (or `SPECTO_TEST_PLAN_LINK_TYPE`) with the name your tenant exposes. |
| Guessing the link-type name | LESSON: link-type names vary per tenant — one tenant exposes a literal `reviews` type, another a differently-named type whose outward description is "reviews". `acli` rejects unknown names with "type not found". List the real names with `acli jira workitem link type`, and verify the stored direction after linking. |
| Passing `link-tickets.sh "$LINK_TYPE" <IMPL> <TEST_PLAN>` | Wrong direction — Test Plan must be the inward (`<inward> <outward>`) |
| Using `Task` type "because the summary makes it obvious" | Auto-detection is incidental; type must be set explicitly |
| Inlining `acli jira workitem create` | Bypasses customfield + label handling. Always go via `create-ticket.sh`. |
| Ticking boxes during the run | The Test Plan is for humans; orchestrators post evidence comments, never tick |
| Synthesising a "test user" framing for production cutovers | Use real-user snapshots; synthetic users hide the actual risk surface |

## Writing style for test cases

Each test case should be:

- **Numbered** and **bolded** on the title.
- **Concrete** — name the actual command (`curl`), endpoint, scope, or role rather than "make a request".
- **One line if possible** — setup + action + expected. Two lines max.
- **Mapped to implementation step or risk** — reviewers should see which part of the change each case covers.

Bad: `Test the auth flow.`
Good: `**3. Real M2M token → 200.** Fetch a token via client_credentials against the staging identity tenant. Hit /api/protected → 200, body contains the expected sub/iss/aud claims.`
