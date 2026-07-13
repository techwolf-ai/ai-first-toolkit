#!/usr/bin/env bash
# Dispatcher: resolves the configured forge backend and execs its create-mr impl.
set -u
set -o pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../lib/dispatch.sh"
specto_dispatch forge create-mr "$@"
