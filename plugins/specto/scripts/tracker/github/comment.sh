#!/usr/bin/env bash
# Post a comment on a GitHub issue. Thin wrapper over `gh issue comment`.
# Bodies are markdown and pass through UNTOUCHED (gh is markdown-native; the
# jira backend's Markdown-to-ADF conversion has no equivalent here).
#
# Usage (identical to the jira counterpart):
#   comment.sh <KEY> <body-file|->                       # live: calls gh
#   comment.sh <KEY> <body-file|-> --from-fixture <path> # test: no-op success
#
# Body is read from a file, or from stdin when <body-file> is "-".
#
# Output: nothing on stdout on success; warnings/errors to stderr.
# Exit:
#   0 - comment posted (or fixture success)
#   1 - body empty / unreadable
#   2 - bad usage
#   3 - gh not on PATH, or the gh call failed

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/_lib.sh"

usage() {
  echo "usage: comment.sh <KEY> <body-file|-> [--from-fixture <path>]" >&2
  exit 2
}

[[ $# -lt 2 ]] && usage
KEY="$1"
BODY_SRC="$2"
shift 2

FIXTURE=""
if [[ $# -gt 0 ]]; then
  if [[ "$1" == "--from-fixture" && $# -ge 2 ]]; then
    FIXTURE="$2"
    shift 2
  else
    usage
  fi
fi

# Read the body (file or stdin).
if [[ "$BODY_SRC" == "-" ]]; then
  BODY="$(cat)"
else
  [[ -f "$BODY_SRC" ]] || { echo "body file not found: $BODY_SRC" >&2; exit 2; }
  BODY="$(cat "$BODY_SRC")"
fi
if [[ -z "${BODY//[[:space:]]/}" ]]; then
  echo "comment body is empty" >&2
  exit 1
fi

if [[ -n "$FIXTURE" ]]; then
  [[ -f "$FIXTURE" ]] || { echo "fixture not found: $FIXTURE" >&2; exit 3; }
  exit 0
fi

specto_require_gh

# Markdown straight through on stdin: no temp file, no conversion.
if ! printf '%s' "$BODY" | gh issue comment "$KEY" --body-file - >/dev/null 2>&1; then
  echo "gh issue comment failed on #$KEY (auth? number?)" >&2
  exit 3
fi
