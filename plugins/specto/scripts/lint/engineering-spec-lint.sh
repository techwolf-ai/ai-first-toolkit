#!/usr/bin/env bash
# Run all engineering-spec lints on the given file.
# Usage: engineering-spec-lint.sh <file>
# Exit 0 = all pass, 1 = any failure, 2 = bad usage.
# Thin shim over run-checks.sh + checks.d/engineering/.

set -u
if [[ $# -ne 1 ]]; then
  echo "usage: engineering-spec-lint.sh <file>" >&2
  exit 2
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$HERE/run-checks.sh" "$HERE/checks.d/engineering" "$1"
