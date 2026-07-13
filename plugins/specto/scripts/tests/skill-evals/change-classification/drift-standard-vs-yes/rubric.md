# Judge rubric — change-classification catches spec-vs-epic drift

The spec header's `Change classification` row reads `Standard`, but the linked
epic TOY-1 (resolved via the acli stub) answers Q1 (auth/authz) = Yes (Q2 and Q3
= No). The correct classification is therefore `Non-standard (Q1)`.

PASS only if:

1. **Read the epic.** The review reflects the epic's classification fields — it
   did not claim `acli` was unavailable or the epic unreadable (the stub returned
   the fields).
2. **Caught the drift.** It flags that the header `Standard` disagrees with the
   epic (Q1 = Yes → should be `Non-standard (Q1)`), and recommends updating the
   spec header to match the epic (the epic is the source of truth).

FAIL if it reported the classification as consistent, claimed the epic was
unreadable, or recommended changing the epic instead of the spec. Answer PASS or
FAIL and one sentence why.
