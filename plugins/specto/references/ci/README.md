# Specto CI snippets

Drop-in CI examples that wire Specto's lint pre-pass (and, with a bit of effort, the model-driven reviewer agents) into your repo's CI — GitLab CI or GitHub Actions.

## What's here

| File | What it does |
|---|---|
| `gitlab-spec-review.example.yml` | Runs the deterministic lint pre-pass (em-dashes, emoji codes, metadata rows, metric count) on changed `product-spec.md` files in an MR. Fails the job on lint violations. |
| `github-spec-review.example.yml` | The same lint gate as a GitHub Actions workflow on `pull_request` (ubuntu-latest ships bash + jq, so no image setup). |

## How to wire

1. **Copy `gitlab-spec-review.example.yml`** into your repo. Either:
   - Paste its contents into your repo's `.gitlab-ci.yml` directly.
   - Save it as a separate file (e.g. `.gitlab/ci/spec-lint.yml`) and `include:` it from your main pipeline.

2. **Make the lint scripts available to the runner.** Two options:
   - **Plugin-installed runners** (recommended for runners with the plugin pre-installed): set `SPECTO_LINT_DIR=/opt/specto/scripts/lint` (or wherever the plugin is installed) as a CI variable.
   - **Copy into your repo:** `cp -r path/to/plugins/specto/scripts/lint .specto/scripts/lint` and set `SPECTO_LINT_DIR=$CI_PROJECT_DIR/.specto/scripts/lint`. Adds a few hundred lines of vendored Bash but removes the runner-install dependency.

3. **Test the gate on a real MR.** Edit a `docs/development/specs/<initiative>/product-spec.md` to introduce an em-dash or remove a required metadata row. The pipeline should fail the `specto-spec-lint` job. Revert and confirm the pipeline goes green.

## Adding model-driven review (advanced)

The `review-spec` Specto skill dispatches `product-review`, `scope-review`, `okr-alignment-review`, and `change-classification-review` in parallel. Wiring this into CI is more involved than the lint pass because:

- The reviewer agents need an Anthropic API key (or Claude Code CLI access) on the runner.
- They post findings via the forge helper (`scripts/forge/post-mr-comment.sh`) — the runner needs a forge token with API scope and a configured CLI login (`glab auth login` / `gh auth login`).
- The agent dispatch happens via Claude Code's Task tool, not via a CLI binary; you'd typically wrap with a thin Python script that invokes the Anthropic API directly (`anthropic.messages.create` with the agent's system prompt copied from `plugins/specto/agents/<name>.md`).

A worked example is out of scope for now: CI shapes vary per org (which runners, which secrets, which CI variables exist). If you wire this up, please contribute the example back to `references/ci/` as a follow-up patch.

## What CI does NOT do

Specto's design treats CI as a **gating layer**, not a workflow driver. CI runs the deterministic lint pass and (with the advanced wiring above) posts model-review findings. Specto's actual workflow — drafting, brainstorming, planning, ticket-creation, implementation, DoD check — runs in human-driven Claude Code sessions, not in CI. The CI snippet is a quality gate, not a replacement for the skills.
