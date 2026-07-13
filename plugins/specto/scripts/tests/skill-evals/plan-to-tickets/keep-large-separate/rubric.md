# Judge rubric — plan-to-tickets keeps large independent tasks separate

Given the plan-to-tickets dry-run transcript for a plan with two large,
independent workstreams (inverted-index ingestion pipeline; ranked query API),
PASS only if ALL hold:

1. **Two tickets, not one.** The dry-run proposes exactly TWO MR-sized tickets —
   one per workstream — and does NOT over-bundle the two large, distinct tasks
   into a single ticket.
2. **AC + spec link preserved.** Each ticket carries its own acceptance criteria
   and a spec-section link back to `engineering-spec.md`.
3. **Dry run only.** Nothing was created or modified in Jira.

FAIL if it bundled the two into one ticket, dropped a workstream or its AC, or
performed a live write. Answer PASS or FAIL and one sentence why.
