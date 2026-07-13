#!/usr/bin/env bash
# Wrapper: scaffold check applies to mermaid in both product and engineering specs.
# Real logic lives in ../_shared.
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../_shared/check-mermaid-scaffold.sh" "$@"
