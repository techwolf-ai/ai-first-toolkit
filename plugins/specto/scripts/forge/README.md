# specto / scripts / forge

Dispatcher shims: the stable entry points for every forge (merge/pull request) side effect. Skills and agents call `"${CLAUDE_PLUGIN_ROOT}/scripts/forge/<verb>.sh"`; they never call a backend directory or a vendor CLI directly (`docs/contracts.md`, single-vetted-entry-point rule).

Each shim is ~6 lines: it sources `../lib/dispatch.sh` and calls `specto_dispatch forge <verb> "$@"`. The dispatcher resolves the configured backend (env `SPECTO_FORGE` > repo `.specto/config.yml` `forge:` > `plugin-config.sh` machine default > remote-host autodetect; implemented in `scripts/lib/config.sh`) and `exec`s `scripts/forge/<backend>/<verb>.sh` with argv passed through verbatim, including `--from-fixture`. No backend resolvable: exit `3` with guidance. Verb missing on the selected backend: exit `4`. `SPECTO_BACKEND_OVERRIDE_FORGE=<backend>` pins a backend for tests without touching config.

Verbs: `create-issue` `create-mr` `find-mr-for-ticket` `job-trace` `mr-describe` `mr-fetch` `mr-ready` `mr-reply` `pipeline-status` `post-mr-comment`.

Backends: `gitlab/` (see its README for per-helper detail and fixture shapes).

Contracts:

- Normalized stdout shapes + the decision-line grammar every backend must print: `docs/adapter-contract.md`.
- Vetted-entry-point rule, backend-selection precedence, exit-code taxonomy: `docs/contracts.md`.

## Adding a backend

1. Create `scripts/forge/<backend>/` with a same-named `<verb>.sh` per supported verb, standard helper shape: `set -u`, `set -o pipefail`, `usage()` → exit `2`, exit codes `0/1/2/3`, a `--from-fixture <dir>` offline mode, payload on stdout and warnings on stderr. A verb you skip costs nothing; the dispatcher exits `4` for it.
2. Map the backend's raw responses into the shapes in `docs/adapter-contract.md`. Fixtures are backend-shaped (they mimic your backend's API), but the decision lines your fixture tests assert must be identical to the ones the `gitlab/` suite asserts.
3. Add `tests/run-tests.sh` + `tests/fixtures/` beside the impls (read `gitlab/tests/run-tests.sh` first; suites are pure-bash assert harnesses), wire the suite into `scripts/tests/run-all.sh`, and give the directory a README documenting its fixture table.
