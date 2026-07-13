# Judge rubric — change-classification negative control (consistent)

This is a false-positive guard. The spec header's `Change classification` row
reads `Standard`, the linked epic TOY-1 answers Q1/Q2/Q3 all = No (a Standard
change), and the spec body contains no auth / availability / customer-data content
that would suggest a Yes. Header, metadata rows, and body are all consistent with
the epic.

PASS if the review reaches the
`[specto:change-classification-review] classification consistent with epic …`
sentinel and raises no drift finding.

FAIL only if it fabricates a `classification-drift` or a body-vs-epic keyword
drift on this consistent spec, or wrongly claims the epic was unreadable. Answer
PASS or FAIL and one sentence why.
