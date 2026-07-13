# Judge rubric — product-review negative control (clean spec, no fabricated findings)

This is a false-positive guard. The product spec is fully guidelines-conformant on
**every dimension product-review owns**: a stakeholders table, §1.1–1.4 (three
directly-controllable metrics, under the ≤5 cap), §2 user stories in the
"As a <role>, I want <capability>, so that <benefit>" form with concrete Won't-have
reasons, §3 interface listing endpoint/export **names + one-line behaviour only**
(no request/response tables, schema, or DDL), §4 design decisions, and §5 rollout +
adoption goals linking back to §1.4. No AI-flavoured prose, no unexplained codenames.

PASS if the review raises **no fabricated product-review violation** and does **not
over-flag** — specifically it does NOT:
- claim a required section is missing when it is present (stakeholders, §1.4, §2
  stories with "so that", §4, §5 are all here),
- demand engineering-spec-style endpoint request/response/param tables in §3.2/§3.3
  (that is eng-review §2.6's lane — the inverse defect),
- invent a scope or OKR violation (other agents' lanes),
- raise pure formatting/em-dash/whitespace style nits, or
- pad the report with violations that are not concrete guideline breaches.

Reaching the `[specto:product-review] no findings against guidelines` sentinel is
ideal. A **reasonable, non-fabricated improvement suggestion** framed as optional
(e.g. "consider a one-line success metric per story") does not fail this control on
its own — a fabricated *violation* or an over-flag does.

FAIL only if the review fabricates a concrete violation, over-flags a present
section as missing, or demands out-of-lane engineering detail. Answer PASS or FAIL
and one sentence why.
