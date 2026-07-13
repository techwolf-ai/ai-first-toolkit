#!/usr/bin/env bash
# Create a link between two Jira work items. Thin wrapper over
# `acli jira workitem link create`. Used by create-ticket.sh and standalone.
#
# Usage:
#   link-tickets.sh <link-type> <from-KEY> <to-KEY>
#   link-tickets.sh <link-type> <from-KEY> <to-KEY> --from-fixture <path>
#
# The link reads as: "<from-KEY> <link-type-outward-description> <to-KEY>".
#   link-tickets.sh Blocks  APP-100 APP-200  ->  "APP-100 blocks APP-200"
#   link-tickets.sh Relates APP-100 APP-200  ->  "APP-100 relates to APP-200"
#   link-tickets.sh reviews APP-100 APP-200  ->  "APP-100 reviews APP-200"
#
# `acli jira workitem link type` lists the link-type NAMES the workspace
# exposes (e.g. "Blocks", "Relates", "Post-Incident Reviews"). Pass the NAME
# to `--type`, not the inward / outward description.
#
# acli flag quirk: DO NOT "FIX" THE --in / --out WIRING BELOW. For the Blocks
# type, acli's `--in` carries the BLOCKER and `--out` carries the BLOCKED,
# which is the OPPOSITE of Jira REST's `inwardIssue` / `outwardIssue` semantics
# (where outwardIssue is the blocker). acli's success message also lies: it
# prints "X Blocks Y" with --out as subject regardless of what was stored. The
# only trustworthy verification is a follow-up `acli jira workitem view <KEY>
# --fields=issuelinks --json` and inspecting `inwardIssue` / `outwardIssue` on
# the issue's own view. create-ticket.sh does that automatically after a batch
# of links. This script's positional contract (<from> = subject, <to> = object)
# hides the acli flag confusion from callers.
#
# After a real create, the stored direction is self-verified by re-reading the
# subject's issuelinks (acli's flags + success message both lie about direction).
#
# Output: nothing on stdout on success; warnings/errors to stderr.
# Exit:
#   0 - link created (or fixture says success)
#   2 - bad usage
#   3 - acli not on PATH, acli call failed, or the link stored in the wrong direction

set -u
set -o pipefail

usage() {
  echo "usage: link-tickets.sh <link-type> <from-KEY> <to-KEY> [--from-fixture <path>]" >&2
  exit 2
}

[[ $# -lt 3 ]] && usage
LINK_TYPE="$1"
FROM_KEY="$2"
TO_KEY="$3"
shift 3

FIXTURE=""
if [[ $# -gt 0 ]]; then
  if [[ "$1" == "--from-fixture" && $# -ge 2 ]]; then
    FIXTURE="$2"
    shift 2
  else
    usage
  fi
fi

if [[ -n "$FIXTURE" ]]; then
  # Fixture mode: a present (any-content) file means "the link create succeeded".
  [[ -f "$FIXTURE" ]] || { echo "fixture not found: $FIXTURE" >&2; exit 3; }
  exit 0
fi

if ! command -v acli >/dev/null; then
  echo "acli not on PATH; install Atlassian CLI" >&2
  exit 3
fi

# See the "acli flag quirk" note in the header for why --in = subject ($FROM_KEY).
if ! acli jira workitem link create --type "$LINK_TYPE" --in "$FROM_KEY" --out "$TO_KEY" --yes >/dev/null 2>&1; then
  echo "acli link create failed: $FROM_KEY $LINK_TYPE $TO_KEY (auth? keys? link type?)" >&2
  exit 3
fi

# Self-verify the stored direction. acli's --in/--out flag names AND its success
# message both lie (see header), so the only trustworthy check is to re-read the
# subject and confirm it now has an OUTWARD link of this type to $TO_KEY — i.e.
# "$FROM_KEY <outward> $TO_KEY" really stored that way, not reversed. This catches
# an acli swap regression even when called standalone (create-ticket.sh runs the
# same check on its batch). Best-effort: a view/jq failure warns but does not fail
# the run — the create itself already succeeded.
if command -v jq >/dev/null; then
  links_json="$(acli jira workitem view "$FROM_KEY" --fields=issuelinks --json 2>/dev/null || true)"
  if [[ -z "$links_json" ]]; then
    echo "warning: linked $FROM_KEY $LINK_TYPE $TO_KEY but could not verify direction (acli view failed)" >&2
  elif ! jq -e --arg t "$LINK_TYPE" --arg to "$TO_KEY" '
      .fields.issuelinks[]?
      | select(.type.name == $t)
      | select(.outwardIssue.key == $to)
    ' <<<"$links_json" >/dev/null; then
    echo "ERROR: link stored in the WRONG direction — expected \"$FROM_KEY $LINK_TYPE $TO_KEY\" (outward). Delete the reversed link and retry." >&2
    exit 3
  fi
fi
