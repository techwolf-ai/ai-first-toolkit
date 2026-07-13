# Judge rubric — eng-review catches a prose-only multi-actor flow (no sequenceDiagram)

Given the eng-review run over `engineering-spec.md`, PASS only if:

1. **Caught the defect.** The review flags that §2.1 describes a multi-actor flow
   (console → API → reply store → audit log, four participants across ≥4 steps)
   in **prose only**, with no mermaid `sequenceDiagram` — and recommends adding a
   `sequenceDiagram` for the flow. The structural `graph` diagram being present
   does not excuse the missing sequence diagram.
2. **No fabricated findings on the clean parts.** It does not invent violations
   on the otherwise well-formed sections — §2.3 storage references the
   `console/AGENTS.md` `feature_flags` convention (no convention-conflict), the
   out-of-scope sections are correctly marked `*Not applicable*`, §3.2 is marked
   not-an-AI-feature, and §6 follows the decision pattern.

FAIL if it missed the missing sequence diagram, or padded the report with
fabricated findings on the clean content. Answer PASS or FAIL and one sentence why.
