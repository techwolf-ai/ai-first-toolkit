# Judge rubric — same-theme bundling (dry run)

Given the dry-run transcript, PASS only if ALL hold:

1. **One bundled ticket, not two.** The dry-run proposes exactly ONE ticket that
   covers both plan tasks (the `foo_flag`→`feature_foo` rename and its default),
   not two separate tickets.
2. **AC granularity preserved.** Both tasks survive as their own acceptance-
   criteria lines inside that one ticket — bundling did not collapse them into a
   single vague AC.
3. **Dry run only.** Nothing was created or modified in Jira.

FAIL if it proposed two tickets, lost an AC, or performed a live write. Answer
PASS or FAIL and one sentence why.
