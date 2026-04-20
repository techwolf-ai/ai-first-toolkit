---
name: kb-answer
description: |
  Answer questions using your project's knowledge base with evidence-backed citations.
  Every answer must cite literal quotes from KB files to prevent hallucinations.
  Use this for any question that should be answered from documented knowledge rather than general knowledge.
---

# KB Answer Workflow

Follow these steps in order for every question. For multiple independent questions, use parallel agents.

## Prerequisites

Check that `kb/` exists in the project root. If not, tell the user to run `/setup-knowledge-base` first.

## Step 1: Navigate Using the Index

**Always start by reading the KB index:**
```
kb/index.md
```

The index provides:
- **Keyword Lookup**: find the right file by keyword
- **Category overview**: all files grouped by topic

If the index is empty or outdated, run the index script first:
```bash
python3 scripts/kb-index.py
```

### Quick Navigation

1. Check the keyword lookup table for matching terms
2. Go to the matching file(s)
3. If no keyword match, browse the category that best fits the question

## Step 2: Read Relevant Files

Based on the index navigation:
1. Read the most relevant file first
2. Check `related:` links in the frontmatter if the file references other entries
3. Read additional files if the first doesn't fully cover the question

## Step 3: Search (if needed)

If the index doesn't point to the right file, search the KB using the Grep tool with path `kb/` and the relevant keyword.

## Step 4: Check Active Scope

If `kb/scopes/` contains scope files beyond `_default.yaml`:
1. Ask the user which scope applies (if not already established in this conversation)
2. Read the active scope file
3. Apply `in_scope`, `out_of_scope`, and `notes` to shape your answer

If only `_default.yaml` exists, skip this step.

## Step 5: Formulate Answer

### Answer Format

**Yes/No questions**: Start with "Yes" or "No", followed by 1 sentence.

**Other questions**: Answer directly in 1-3 sentences. Add detail only if needed.

**If format requirements are provided**: Follow them exactly.

### Citation Requirements

Every claim in your answer MUST be backed by a literal quote from a KB file.

Format each citation as:

```
> "exact quote copied from the KB file"
> Source: kb/category/filename.md
```

**Rules:**
- Copy the quote character-for-character. Do not paraphrase, summarize, or rephrase.
- If you cannot find a literal quote supporting a claim, do not make that claim.
- **Include markdown formatting verbatim.** If the source says `**Confidential**: ...`, your quote must be `**Confidential**: ...`, not `Confidential: ...`. If the source uses bullet list dashes, include them. Missing markdown is the #1 reason `kb-verify.py` flags citations. The script has a normalized-match fallback that will PASS with a warning, but strict mode will FAIL, so always copy formatting literally.
- For long passages, prefer quoting a single self-contained sentence rather than a multi-line block. Multi-line blocks are fragile across reformatters.

### What to Avoid

- Don't over-elaborate. Match answer depth to question depth.
- Don't pad with "more details available upon request".
- Don't start with summary phrases like "Based on our documentation...". Go straight to the answer.
- Be honest about limitations. If something isn't in the KB, say so.

### If Information is Missing

1. State clearly what information is not in the KB
2. Provide what can be answered from available info
3. Do not make up or infer information not in the KB
4. Suggest which KB entry should be created to cover the gap

## Step 6: Verify Citations

After formulating your answer, verify all citations are accurate by running:

```bash
python3 scripts/kb-verify.py <<'EOF'
{your answer with citations}
EOF
```

The script checks that every quoted string exists in the referenced KB file. It runs two passes:
1. **Strict**: the quote is byte-exact (including markdown markers and whitespace).
2. **Normalized** (fallback): markdown markers (`**`, `*`, `_`, `` ` ``) and whitespace are stripped from both sides before comparison. Reported as `PASS (normalized)`.

Target strict passes. If the script reports `PASS (normalized)`, re-copy the quote with its original markdown so the next verify run is clean.

- All citations PASS (strict or normalized): present the answer.
- Any citation FAIL: re-read the source file, copy the exact text (including markdown), and verify again.
- Use `python3 scripts/kb-verify.py --strict answer.md` when you want to guarantee byte-exact citations (e.g., before publishing to a customer).

Do not present an answer with any FAIL citations.

## Handling Multiple Questions

**Related questions** (same topic): Group together, share file reads.

**Independent questions**: Use parallel agents, each following this workflow.

Example:
```
Q1: "What encryption do we use?"     -> security
Q2: "Who are our customers?"         -> general
Q3: "What's our SLA?"                -> security

Group 1 (security): Q1 + Q3
Group 2 (general): Q2
```
