# `scripts/conventions/`

Helpers that surface the `AGENTS.md` / `CLAUDE.md` conventions Specto agents and
skills must honour.

## `nearest-agents-md.sh <path> [<path>...]`

Prints, **nearest-first**, the `AGENTS.md` and `CLAUDE.md` files that apply to
each target path: from the path's directory up to the first directory holding a
`.git` or `.jj` marker (the repo root, auto-detected per path). A non-existent
leaf resolves to its nearest existing ancestor; output is deduped across paths.

By the [agents.md](https://agents.md) convention the chain is **cumulative** —
repo-wide rules sit at the root, subtree rules sit deeper — and the **closest**
file wins on conflict. The nearest-first ordering is that precedence order, so a
consumer reads every line but resolves conflicts in favour of the first.

Exit codes: `0` ok (empty output when nothing is found is not an error) · `2`
bad usage.

Tests: `bash tests/run-tests.sh` (builds throwaway fake repos in temp dirs).
