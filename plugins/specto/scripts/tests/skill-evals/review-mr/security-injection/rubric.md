# Judge rubric — code-mr-review catches a SQL injection

Given the code-mr-review run over the branch diff (anchored on `engineering-spec.md`
§2.6 and ticket TOY-2's AC), PASS only if:

1. **Caught the injection.** The review flags that `get_reply_text` builds its SQL
   query by f-string interpolation of the caller-supplied `reply_id`
   (`f"SELECT text FROM saved_replies WHERE id = {reply_id}"`) — a SQL injection —
   and recommends a parameterised query. This is a `security-*` axis finding
   citing the vulnerable line.
2. **Did not wrongly fail the covered AC.** Both AC lines are implemented (one-click
   insert, and the closed-ticket guard with a test), so it must not claim an AC is
   uncovered.

FAIL if it missed the injection. It may additionally raise other minor notes; that
does not fail this scenario. Answer PASS or FAIL and one sentence why.
