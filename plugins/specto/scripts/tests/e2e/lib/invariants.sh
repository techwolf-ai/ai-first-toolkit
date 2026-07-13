#!/usr/bin/env bash
# Pure structural predicates over Specto spec / ticket artifacts.
#
# Each predicate exits 0 when the invariant HOLDS and 1 when it is VIOLATED.
# They print nothing and touch no PASS/FAIL counters, so they compose inside
# `assert` calls AND can be exercised directly against good *and* bad fixtures
# (the non-vacuous check: a predicate that can't fail proves nothing).
#
# These cover only what is mechanically decidable from the text. Judgment-level
# invariants (e.g. "does this read well", scope-review's engineering-creep call)
# are deliberately out of scope — they belong to the LLM review agents, not CI.

# Line number of the first line matching the ERE (empty when no match).
inv_first_line() { grep -nE "$2" "$1" 2>/dev/null | head -1 | cut -d: -f1; }

# Heading matching $2 appears before heading matching $3 (both must exist).
inv_order_ok() {
  local a b
  a="$(inv_first_line "$1" "$2")"
  b="$(inv_first_line "$1" "$3")"
  [[ -n "$a" && -n "$b" && "$a" -lt "$b" ]]
}

# File contains at least one line matching the ERE.
inv_has() { grep -qE "$2" "$1"; }

# File contains NO line matching the ERE.
inv_lacks() { ! grep -qE "$2" "$1"; }

# ---- product-spec: engineering content that must NOT appear ---------------------
# Conservative token set — each of these is unambiguously engineering-spec
# material (product-spec-guidelines anti-pattern table). Kept narrow to avoid
# false positives on legitimate product prose.
PRODUCT_ENG_CONTENT_RE='```sql|CREATE TABLE|customfield_[0-9]|^### .*Storage model|^### .*Endpoint contracts'
