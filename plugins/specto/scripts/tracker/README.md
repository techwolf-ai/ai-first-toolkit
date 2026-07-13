# specto / scripts / tracker

Dispatcher shims: the stable entry points for every tracker (ticket) side effect. Skills and agents call `"${CLAUDE_PLUGIN_ROOT}/scripts/tracker/<verb>.sh"`; they never call a backend directory or a vendor CLI directly (`docs/contracts.md`, single-vetted-entry-point rule).

Each shim is ~6 lines: it sources `../lib/dispatch.sh` and calls `specto_dispatch tracker <verb> "$@"`. The dispatcher resolves the configured backend (env `SPECTO_TRACKER` > repo `.specto/config.yml` `tracker:` > `plugin-config.sh` machine default > autodetect; implemented in `scripts/lib/config.sh`) and `exec`s `scripts/tracker/<backend>/<verb>.sh` with argv passed through verbatim, including `--from-fixture`. No backend resolvable: exit `3` with guidance. Verb missing on the selected backend: exit `4`. `SPECTO_BACKEND_OVERRIDE_TRACKER=<backend>` pins a backend for tests without touching config.

Verbs: `active-sprint` `add-to-sprint` `assign-ticket` `comment` `create-ticket` `delete-links` `epic-fields` `get-ticket-description` `get-ticket-parent` `get-ticket-sprint` `get-ticket-status` `get-ticket-summary` `get-ticket-type` `label-ticket` `link-tickets` `list-children` `set-parent` `ticket-url` `transition-ticket`.

Backends: `jira/` (see its README for per-helper detail and fixture shapes; `md_to_adf.py` is a Jira-internal detail that stays inside that dir).

Contracts:

- Normalized stdout shapes and the neutral rules (markdown bodies, opaque ticket keys, canonical `blocks`/`relates` link types, canonical `todo`/`in_progress`/`in_review`/`done` statuses with synonym walking): `docs/adapter-contract.md`.
- Vetted-entry-point rule, backend-selection precedence, exit-code taxonomy: `docs/contracts.md`.

## Adding a backend

1. Create `scripts/tracker/<backend>/` with a same-named `<verb>.sh` per supported verb, standard helper shape: `set -u`, `set -o pipefail`, `usage()` → exit `2`, exit codes `0/1/2/3`, a `--from-fixture` offline mode, payload on stdout and warnings on stderr. A verb you skip costs nothing; the dispatcher exits `4` for it.
2. Map the backend's raw responses into the shapes in `docs/adapter-contract.md`. Bodies stay markdown end to end; any backend-native rich format conversion belongs inside your backend dir, like Jira's ADF. Fixtures are backend-shaped, but the lines your fixture tests assert (e.g. `transitioned_to=<name>`, the `epic-fields.sh` `key=value` set) must match the ones the `jira/` suite asserts.
3. Add `tests/run-tests.sh` + `tests/fixtures/` beside the impls (read `jira/tests/run-tests.sh` first; suites are pure-bash assert harnesses), wire the suite into `scripts/tests/run-all.sh`, and give the directory a README documenting its fixture table.
