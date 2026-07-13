#!/usr/bin/env bash
# Dispatcher: resolves the configured tracker backend and execs its add-to-sprint impl.
set -u
set -o pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../lib/dispatch.sh"
specto_dispatch tracker add-to-sprint "$@"
