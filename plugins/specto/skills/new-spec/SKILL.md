---
name: new-spec
description: Use when the user wants to start a new product spec sheet, create a spec folder for a new initiative, draft a product-spec.md, or asks "let's spec out X" / "create a spec for X" / "start a new initiative".
---

# new-spec

Scaffold a new in-repo spec folder and produce a polished `product-spec.md` draft. The engineering spec is sequential: once the product spec is approved, invoke with `--add-engineering` to brainstorm the engineering layer and draft `engineering-spec.md` (see [Add-engineering mode](#add-engineering-mode)).

For an already-scaffolded folder (context gathered in a prior session, `product-spec.md` still the template), invoke with `--writer-only` / `--resume` to dispatch the writer against the existing inputs — see [Writer-only / resume mode](#writer-only--resume-mode).

## Prerequisite check

Specto requires the superpowers plugin. If `superpowers:brainstorming` is not available in the skill list, stop and ask the user to install superpowers.

## Inputs the user provides

When invoked, ask the user for (one question at a time, multiple choice when possible):

- **Initiative slug** (kebab-case, will be appended to today's date for the folder name). Examples: `contact-dedup`, `org-redesign`, `task-feedback-loop`.
- **Whether `.specto/config.yml` exists.** If not, offer to create a starter file (Notion OKR page id, Jira project key, default DoD checklist). Do not block on this; the writer agent works without it, only the OKR-alignment reviewer cares.
- **Linked epic key (optional).** Ask: *"do you have an epic for this work? Paste the key (e.g. `APP-1234`), or leave blank if not yet."* If a key is supplied, validate it matches the regex `^[A-Z][A-Z0-9_]+-[0-9]+$`; on mismatch, ask once more. If blank, the spec ships with placeholder rows for the engineer to fill manually.

## Steps the skill executes

**Step 0 — choose the spec ceremony (ask this first).** Before brainstorming, one `AskUserQuestion`: *"How much spec does this change need?"* with options **Full (product + engineering)** — the default, recommended for a real initiative: a product spec now, the engineering spec later via `--add-engineering` — and **Lean (single spec)** — one combined spec for a small, self-contained change. Record the choice in `<SPEC_FOLDER>/context/compiled/brainstorm.md` (a `ceremony: full|lean` line) so `--add-engineering` and reviewers can see it, and set the default per team from `plugin-config.sh get spec_ceremony` when present.

- On **Full**, run steps 1–9 unchanged; the engineering spec is a later, separate `--add-engineering` pass.
- On **Lean**, still run steps 1–9, but: the product-spec-writer drops the §1.3 Objectives (OKR) and Delivery Stakeholders sections unless the brainstorm actually surfaced them (pass `lean: true` in step 6 — see the writer's *Lean mode*), and there is no separate engineering spec — engineering decisions that arise go in a short `## Engineering notes` tail of the same spec. Do not force a second spec for a two-file change.

Tickets remain the unit of work in both modes — lean trims *spec ceremony*, never the ticket/plan step.

1. **Brainstorm intent.** Invoke `superpowers:brainstorming` with the initiative as the topic. The brainstorming skill walks the user through scope, KRs, stakeholders, in/out-of-scope. Capture the full transcript.

2. **Scaffold the folder.** Run:

```bash
TODAY=$(date +%F)
SLUG="<user-provided-slug>"
SPEC_FOLDER="docs/development/specs/${TODAY}-${SLUG}"
mkdir -p "$SPEC_FOLDER/context/raw" "$SPEC_FOLDER/context/compiled"
cp "<plugin-root>/templates/product-spec.md" "$SPEC_FOLDER/product-spec.md"
```

If the folder already exists, abort and tell the user. Do not overwrite.

   **Scaffold `.specto/.gitignore`.** When creating `.specto/` (e.g. alongside the starter `config.yml` from the Inputs step), write `.specto/.gitignore` if it does not already exist, so the tracked OKR-source inputs survive the MR while the transient `plan.md` stays local:

   ```bash
   if [ ! -f .specto/.gitignore ]; then
     mkdir -p .specto
     cat > .specto/.gitignore <<'EOF'
   *
   !.gitignore
   !config.yml
   !okrs.md
   EOF
   fi
   ```

   `config.yml` (holds `notion_okr_page_id`) and `okrs.md` (the OKR snapshot) are the inputs `okr-alignment-review` needs — without whitelisting them, an MR reviewer or CI gets no OKR source and the review silently degrades to the `no-okr-source` advisory. `plan.md` is intentionally left ignored by the leading `*`. (Deferred V2 scope is *not* here — `resolve-spec-comments` writes `v2-candidates.md` into the spec folder, which is tracked docs.)

3. **Populate the spec from the linked epic (if one was supplied).** When the user provided an epic key, first read `.specto/config.yml` and check for a `compliance:` block (the opt-in compliance profile; shape in `<plugin-root>/references/compliance-profile.example.yml`). The block gates how much of the header is populated:

   **No compliance block — generic metadata only.** Run the helper without `--questions`:

   ```bash
   PLUGIN_ROOT="<plugin-root>"
   EPIC_KEY="<user-provided-key>"
   "$PLUGIN_ROOT/scripts/tracker/epic-fields.sh" "$EPIC_KEY"
   ```

   It emits only the generic metadata lines (`development_stage`, `epic_type`, `delivery_cycle` where resolvable) plus `classification=unconfigured`. Populate the `Epic link`, `Development Stage`, and `Epic Type / Delivery cycle` rows as below, and **delete the template's `Change classification` row** — nothing will ever populate it in this repo.

   **Compliance block present — classification too.** Build the questions JSON from the block (one object per declared question: `id`, `flag`, `question`, `epic_field`, `epic_field_id`) and pass it:

   ```bash
   QUESTIONS_JSON='[{"id":"Q1","flag":"security","question":"...","epic_field":"...","epic_field_id":"customfield_NNNNN"}, ...]'
   "$PLUGIN_ROOT/scripts/tracker/epic-fields.sh" "$EPIC_KEY" --questions "$QUESTIONS_JSON"
   ```

   It emits one `flag_<id>=Yes|No` line per question, `classification=Standard|Non-standard (<Yes-question list>)`, the generic metadata lines, and `resolved_via=`.

   Exit-code handling (both variants):

   - If exit code is 3 (the tracker CLI, e.g. `acli`, failed), print the diagnostic and ask the user to either fix its auth and retry, or proceed without the epic. Do not abort the whole `new-spec` flow.
   - If exit code is 1 (some fields missing), print which fields didn't resolve and proceed with the values that did. Mark unresolved rows in the spec with `<unresolved — verify on epic>`.
   - On exit code 0, capture the `key=value` output lines as shell variables.

   Then surgically replace the placeholder rows in `<SPEC_FOLDER>/product-spec.md`:

   - The `Epic link` row's value cell becomes `[<EPIC_KEY>](<url>)`, where `<url>` comes from `"${CLAUDE_PLUGIN_ROOT}/scripts/tracker/ticket-url.sh"` `<EPIC_KEY>`.
   - The `Change classification` row's value cell becomes the helper's `classification` value (e.g. `Standard` or `Non-standard (Q1 / Q3)`) — only when a compliance profile is configured; delete the row otherwise (see above).
   - The `Development Stage` row's value cell becomes the helper's `development_stage` value.
   - The `Epic Type / Delivery cycle` row's value cell becomes `<epic_type> / <delivery_cycle>`.

   Use the Edit tool with one `old_string`/`new_string` pair per row; each row is unique in the file because of the bold label prefix (`**Change classification**`, etc.).

   Finally, write the spec-folder metadata sidecar so reviewer agents (and future `dod-check`) can find the epic. With a compliance profile, include one `flag_<id>:` line per declared question:

   ```bash
   cat > "$SPEC_FOLDER/.specto-meta.yml" <<EOF
   epic: $EPIC_KEY
   classification: $classification
   flag_q1: $flag_q1
   flag_q2: $flag_q2
   flag_q3: $flag_q3
   development_stage: $development_stage
   epic_type: $epic_type
   delivery_cycle: $delivery_cycle
   EOF
   ```

   (the `flag_*` line names follow the profile's question ids — write whatever `flag_<id>=` lines the helper emitted). Without a compliance profile, omit the `flag_*` lines and write `classification: unconfigured` through as the helper returned it.

   When the user provided no epic key, skip the surgery. The template's placeholder rows ship as-is for the writer agent (or the engineer) to fill manually — except the `Change classification` row, which is still deleted when no compliance block is configured. Still write the meta sidecar with `epic:` set to empty so reviewer agents can detect "no epic linked":

   ```bash
   cat > "$SPEC_FOLDER/.specto-meta.yml" <<EOF
   epic:
   EOF
   ```

4. **Save the brainstorm artefact.** Write the structured brainstorming output (goal, scope, KRs, stakeholders, won't-haves with reasons) to `<SPEC_FOLDER>/context/compiled/brainstorm.md` so it is available to the writer agent and to future sessions. End the artefact with a `## Open questions` section: one bullet per item the brainstorm surfaced but did not resolve. If the brainstorm resolved everything, write `## Open questions` followed by `_None._`. The before-dispatch pass (step 5) reads this section.

5. **Before-dispatch clarification.** Read the `## Open questions` tail of `<SPEC_FOLDER>/context/compiled/brainstorm.md`. For each unresolved item, ask the user with `AskUserQuestion` — group related questions, and since `AskUserQuestion` takes at most 4 questions per call, walk in passes when there are more. Append every resolved answer to `<SPEC_FOLDER>/context/compiled/clarifications.md` in the [persisted format](#clarification-persistence-format). Skip this step when there are no open questions. Resolving these now means the writer drafts from cleaner inputs rather than guessing.

5b. **Choose the drafting structure.** One `AskUserQuestion`: *"Spec structure?"* with options **Standard template structure** (drafted in one pass), **Outline-first** (agree the section skeleton before any content lands), and **Staged (value-first)** (recommended default — draft and confirm the value case before writing requirements). On **Standard**, continue to step 6 unchanged. On **outline-first**:

   1. Dispatch the writer (step 6's inputs) with the extra input `skeleton_only: true`. It writes only the section skeleton — headers, one italic one-line intent per section, a `<placeholder>` body marker each — and returns the skeleton in its report.
   2. Present the skeleton and let the author shape it: add / remove / rename / reorder sections (free-form discussion plus `AskUserQuestion` where choices are crisp). Apply the agreed structural edits to the spec file directly with `Edit`.
   3. Re-dispatch the writer in fill mode: pass `fill_sections: [§…]` listing the approved sections (all of them, or the subset the author wants to drill into first — remaining sections can be filled in later passes in the order the author chooses). Fill mode is the writer's existing edit-only re-dispatch behaviour: it resolves only the marked slots and never regenerates a section the author hand-filled between dispatches.

   On **Staged (value-first)** — the same `fill_sections` mechanism, driven in gated passes so the author aligns on *why* before *what*:

   1. **Value first.** Dispatch the writer with `fill_sections: [§1]` (the §1 Value case: problem, who it's for, the value it brings — in stakeholder language, not engineering). Present the drafted §1 and **stop for confirmation**: the author edits/approves the value case before anything else is written. This is where iteration should be richest.
   2. **Then requirements.** Once §1 is agreed, re-dispatch with `fill_sections: [§2, §3]` (user stories with MoSCoW priority, functional requirements). Present and confirm.
   3. **Then the rest.** Re-dispatch with `fill_sections: [§4, §5]` (design decisions, rollout).

   Between passes the writer never regenerates an already-approved section (edit-only fill mode), so each gate's sign-off sticks.

   Then continue with steps 7-9 unchanged (lint, after-writer clarification, summary).

6. **Dispatch the product-spec-writer agent.** Use the Task tool with `subagent_type="specto:product-spec-writer"`. Pass these inputs in the prompt:

   - `spec_folder`: absolute path to the scaffolded folder.
   - `template_path`: absolute path to `<plugin-root>/templates/product-spec.md`.
   - `guidelines_path`: prefer `.specto/product-spec-guidelines.md` if it exists in the user's repo; otherwise `<plugin-root>/references/product-spec-guidelines.md`.
   - `exemplar_path`: absolute path to `<plugin-root>/references/exemplars/duplicate-detection/product-spec.md`.
   - `brainstorm_artefact`: path to `<SPEC_FOLDER>/context/compiled/brainstorm.md` (from step 4). Pass the path, not the inlined content — the writer reads every file in `context/compiled/` already (see product-spec-writer required-reads).
   - `context_folder`: absolute path to `<SPEC_FOLDER>/context/`.

7. **Run the lint pre-pass on the produced draft.** Run `<plugin-root>/scripts/lint/product-spec-lint.sh "<SPEC_FOLDER>/product-spec.md"`. If lint fails, surface the failures and offer to re-dispatch the writer with the lint findings as feedback. Do not auto-retry; the user decides.

8. **After-writer clarification.** The writer's report ends with an `## Open questions (for new-spec to walk)` block (see [product-spec-writer "After writing"](../../agents/product-spec-writer.md)). For each line, ask the user with `AskUserQuestion`, batched by section — at most 4 questions per call, so walk longer lists in passes. Append each answer to `<SPEC_FOLDER>/context/compiled/clarifications.md` keyed by its `[§<section>]` tag in the [persisted format](#clarification-persistence-format). Then **offer to re-dispatch the writer (step 6)** — on re-dispatch it runs in edit-only mode, resolving just the marked slots from `clarifications.md` (see product-spec-writer "Re-dispatch mode"). Do not auto-re-dispatch; the user decides. Skip this step when the writer returned no Open questions block.

9. **Print a summary.** State which folder was created, whether the epic was linked (and which fields resolved), what the writer produced (sections fully populated, sections with `<placeholder>` markers, `TODO(product-approval)` markers), which open questions were resolved into `clarifications.md` and which remain, and what the recommended next step is (typically: "run review-spec when you're ready for reviewer feedback").

## Clarification persistence format

Resolved clarifications are appended to `<SPEC_FOLDER>/context/compiled/clarifications.md`. Both writers read every file in `context/compiled/` first, so a re-dispatch consumes these answers with no extra input wiring. Each answer is a level-3 heading followed by the answer prose:

- **After-writer answers** key off the writer's marker tag, so the writer can match them to the slot it left: `### [§1.4]`, `### [§4]`.
- **Before-dispatch answers** (resolved from the brainstorm, before any section exists) key off a short topic: `### scope`, `### target-customer`.

```
### [§1.4]
We commit to a 20% lift in adoption, measured weekly.

### scope
V1 covers the EU region only; APAC is explicitly out.
```

Append, never overwrite — the file accumulates across before-dispatch and after-writer passes and across sessions.

## Writer-only / resume mode

When the `--writer-only` (alias `--resume`) flag is supplied, the spec folder already exists — context was gathered in a prior session and the user just wants the writer dispatched against the existing inputs. This is the common "gathered context yesterday, drafting today" case; without the flag the skill would abort on the existing folder (see Hard rules).

1. **Resolve the existing spec folder.** Take it from the user's pwd or ask. It must already exist (the abort-on-exists rule is inverted under this flag — a *missing* folder is the error here). It is expected to contain `context/raw/`, `context/compiled/` (including `brainstorm.md`), and a `product-spec.md` that is still the bare template or a stale draft.
2. **Skip step 1 (brainstorm)** — the artefact is already on disk at `context/compiled/brainstorm.md`. **Skip step 2 (scaffold)** — the folder and its tree exist.
3. **Step 3 (epic surgery) is conditional:**
   - If `<SPEC_FOLDER>/.specto-meta.yml` is already populated (non-empty `epic:`), skip it.
   - If the user supplies `--writer-only --epic <KEY>` (the epic landed mid-draft), run step 3's epic-fields surgery and **rewrite** `<SPEC_FOLDER>/.specto-meta.yml` before dispatching the writer.
4. **Skip step 4 (save brainstorm artefact)** — already on disk, including its `## Open questions` tail.
5. **Run steps 5 (before-dispatch clarification — the brainstorm's `## Open questions` tail is on disk and is walked here), 5b (structure choice), 6 (dispatch `product-spec-writer`), 7 (lint pre-pass), 8 (after-writer clarification), and 9 (summary) unchanged.** The writer agent already accepts the path-based inputs; this mode is purely about which steps the skill runs. If a `clarifications.md` already exists from a prior session, the before-dispatch pass appends to it and the writer consumes it in edit-only re-dispatch mode.

## Add-engineering mode

When the `--add-engineering` flag is supplied to `new-spec`:

1. **Verify the spec folder contains a product-spec.md.** Resolve the spec folder from the user's pwd or ask. If `product-spec.md` does not exist, abort and tell the user the engineering spec is gated on the product spec.
2. **Verify the product-spec is approved or near-merged.** Look for a populated `## Delivery Stakeholders` Product table with at least one `✓` mark. If none, warn the user but proceed (they may be drafting the eng-spec in parallel; the writer will leave more `TODO(eng-approval)` markers).
3. **Copy the engineering-spec template** from `<plugin-root>/templates/engineering-spec.md` to `<spec_folder>/engineering-spec.md` if the file does not yet exist. If it does, abort and tell the user (don't overwrite).
4. **Brainstorm the engineering layer.** Invoke `superpowers:brainstorming` with an engineering framing: architecture sketch, NFRs (latency / SLO / cost envelope), test approach, rollout/rollback, risks, and dependent-repo touchpoints. This is a *separate* pass from the product brainstorm — engineering decisions need engineering-flavoured exploration, not product-flavoured context. Save the structured output to `<spec_folder>/context/compiled/brainstorm-engineering.md`, ending with a `## Open questions` section (one bullet per unresolved item; `_None._` if all resolved). The product-phase `brainstorm.md` stays as additional input — this adds the missing engineering layer rather than replacing it. Skip this step if `brainstorm-engineering.md` already exists (a prior session ran it).
5. **Before-dispatch clarification.** Read the `## Open questions` tail of `brainstorm-engineering.md` and walk any unresolved items with `AskUserQuestion` (batched, 4 per call). Append answers to `<spec_folder>/context/compiled/clarifications-engineering.md` in the [persisted format](#clarification-persistence-format). Skip when there are no open questions.
5b. **Choose the drafting structure.** Same as product-mode step 5b: one `AskUserQuestion` — **Standard template structure** (default) or **Outline-first**. On outline-first, dispatch the engineering-spec-writer with `skeleton_only: true`, walk the skeleton with the author, apply structural edits, then re-dispatch in fill mode with `fill_sections: [§…]`. The applicability matrix still governs which sections exist — outline-first shapes structure, it never resurrects an out-of-scope section.

6. **Dispatch the engineering-spec-writer agent.** Use the Task tool with `subagent_type="specto:engineering-spec-writer"`. Pass these inputs in the prompt:
   - `spec_folder`: absolute path.
   - `product_spec_path`: `<spec_folder>/product-spec.md` (absolute).
   - `template_path`: `<plugin-root>/templates/engineering-spec.md`.
   - `guidelines_path`: `.specto/engineering-spec-guidelines.md` if present, else `<plugin-root>/references/engineering-spec-guidelines.md`.
   - `brainstorm_artefact`: path to `<spec_folder>/context/compiled/brainstorm-engineering.md` (the engineering brainstorm). Pass the path, not the inlined content — the writer reads every file in `compiled/` already, including `brainstorm.md` and `clarifications-engineering.md`.
   - `context_folder`: `<spec_folder>/context/`.
7. **After-writer clarification.** Walk the writer's `## Open questions (for new-spec to walk)` block with `AskUserQuestion` (batched by section, 4 per call). Append answers to `clarifications-engineering.md` keyed by their `[§<section>]` tag. Then **offer to re-dispatch the writer (step 6)** — on re-dispatch it runs in edit-only mode, resolving just the marked slots (see engineering-spec-writer "Re-dispatch mode"). Do not auto-re-dispatch. Skip when the writer returned no Open questions block.
8. **Print a summary.** Path to the produced engineering-spec.md, section completeness, list of `TODO(eng-approval)` markers, which open questions were resolved into `clarifications-engineering.md` and which remain, recommended next step (typically *"run review-spec on engineering-spec.md"*).

The skill runs an engineering-flavoured `superpowers:brainstorming` pass (step 4) before drafting the engineering spec; the product-phase `brainstorm.md` is reused as additional input, not replaced.

## Hard rules

- **Date-prefix folders only.** Never `NNNN-<slug>/`; always `<YYYY-MM-DD>-<slug>/`.
- **Never overwrite an existing spec folder.** If `<SPEC_FOLDER>` exists, abort and tell the user — *unless* `--writer-only` / `--resume` was supplied, in which case the existing folder is expected and the skill dispatches the writer against it (see [Writer-only / resume mode](#writer-only--resume-mode)). Even then, never overwrite a populated `.specto-meta.yml` except via the explicit `--writer-only --epic <KEY>` path.
- **Do not commit on the user's behalf.** The user reviews and commits the draft.
- **Epic is the source of truth, when present.** When an epic key is supplied, never re-prompt the user for the classification/metadata values; always use what `epic-fields.sh` returned. The header rows are a *surface* — drift between epic and surface is `change-classification-review`'s job to catch, not `new-spec`'s.
- **Outline-first changes structure only.** The lint pre-pass (step 7) gates identically in both modes, and flow-diagram drafting (structural mermaid + sequenceDiagrams per the writer's rules) is untouched — the skeleton phase never waters either down.

## When this skill should NOT run

- The user has an existing spec they want reviewed: invoke `review-spec` instead.
- The user wants to plan implementation: invoke `plan-from-spec` (V0.5).
- The user wants to address MR comments: invoke `resolve-spec-comments` (V0.6).
