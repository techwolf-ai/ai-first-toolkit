#!/usr/bin/env bash
# Post a comment on a Jira work item. Thin wrapper over
# `acli jira workitem comment create`. Markdown bodies are auto-converted to ADF
# via md_to_adf.py; ADF JSON bodies pass through. Falls back to the legacy
# --body <string> path on conversion failure / missing python3.
#
# Usage:
#   comment.sh <KEY> <body-file|->                       # live: calls acli
#   comment.sh <KEY> <body-file|-> --from-fixture <path> # test: no-op success
#
# Body is read from a file, or from stdin when <body-file> is "-".
#
# Output: nothing on stdout on success; warnings/errors to stderr.
# Exit:
#   0 — comment posted (or fixture success)
#   1 — body empty / unreadable
#   2 — bad usage
#   3 — acli not on PATH, or acli call failed

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

if ! command -v acli >/dev/null; then
  echo "acli not on PATH; install Atlassian CLI" >&2
  exit 3
fi

# ADF JSON → --body-file as-is. Markdown → convert via md_to_adf.py → --body-file.
# Fall back to --body <string> on conversion failure / missing python3.
TMP_BODY=""
cleanup() { [[ -n "$TMP_BODY" && -f "$TMP_BODY" ]] && rm -f "$TMP_BODY"; return 0; }
trap cleanup EXIT

USE_BODY_FILE=false
first_char="$(printf '%s' "$BODY" | tr -d '[:space:]' | head -c 1)"
if [[ "$first_char" == "{" ]] && printf '%s' "$BODY" | jq -e '.type == "doc"' >/dev/null 2>&1; then
  TMP_BODY="$(mktemp -t specto-comment.XXXXXX)"
  printf '%s' "$BODY" > "$TMP_BODY"
  USE_BODY_FILE=true
elif command -v python3 >/dev/null && [[ -r "$HERE/md_to_adf.py" ]]; then
  TMP_BODY="$(mktemp -t specto-comment.XXXXXX)"
  if printf '%s' "$BODY" | python3 "$HERE/md_to_adf.py" > "$TMP_BODY" 2>/dev/null \
     && jq -e '.type == "doc"' "$TMP_BODY" >/dev/null 2>&1; then
    USE_BODY_FILE=true
  else
    rm -f "$TMP_BODY"; TMP_BODY=""
    echo "warning: md_to_adf.py conversion failed; posting raw body (will render as plain text in Jira)" >&2
  fi
else
  echo "warning: python3 not on PATH; cannot convert Markdown→ADF, posting raw body (will render as plain text in Jira)" >&2
fi

if $USE_BODY_FILE; then
  if ! acli jira workitem comment create --key "$KEY" --body-file "$TMP_BODY" >/dev/null 2>&1; then
    echo "acli comment create failed on $KEY (auth? key?)" >&2
    exit 3
  fi
else
  if ! acli jira workitem comment create --key "$KEY" --body "$BODY" >/dev/null 2>&1; then
    echo "acli comment create failed on $KEY (auth? key?)" >&2
    exit 3
  fi
fi
