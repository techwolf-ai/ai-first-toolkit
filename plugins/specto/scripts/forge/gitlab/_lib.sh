#!/usr/bin/env bash
# Shared helpers for the specto gitlab scripts. Source it, don't execute it.
# Defines functions only — no side effects on source.
#
# specto_source_branch (git + jj-colocated source-branch resolution) is VCS
# logic, not GitLab logic; it lives in scripts/vcs/_lib.sh and is re-sourced
# here so every gitlab helper keeps its single `. "$SCRIPT_DIR/_lib.sh"` line.

# shellcheck source=../../vcs/_lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../vcs/_lib.sh"
