#!/usr/bin/env bash
# Wrapper: diagrams appear in both product (§1.2, §5.3) and engineering specs, so the
# dark-mode classDef palette check is shared. Real logic lives in ../_shared.
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../_shared/check-diagram-palette.sh" "$@"
