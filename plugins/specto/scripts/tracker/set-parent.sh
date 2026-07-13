#!/usr/bin/env bash
# Dispatcher: resolves the configured tracker backend and execs its set-parent impl.
set -u
set -o pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../lib/dispatch.sh"
specto_dispatch tracker set-parent "$@"
