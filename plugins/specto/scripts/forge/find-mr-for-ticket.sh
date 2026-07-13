#!/usr/bin/env bash
# Dispatcher: resolves the configured forge backend and execs its find-mr-for-ticket impl.
set -u
set -o pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../lib/dispatch.sh"
specto_dispatch forge find-mr-for-ticket "$@"
