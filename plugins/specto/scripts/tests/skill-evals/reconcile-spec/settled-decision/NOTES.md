# Needs the branch installed

`reconcile-spec` is **new in the specto v1 stack (!72)** and is **not in the
installed base plugin**. Headless skill-evals load the *installed* user-level
plugin (see `../../README.md` → Limitations), so this scenario only exercises the
real skill once the working-tree branch is installed (local marketplace / branch
install) or the stack merges.

Until then, a headless run grades a plugin that lacks the skill and will
fail/skip — that is expected. The scenario is built now to **lock the behaviour
going forward**: seed a spec whose §2.3 storage decision is still `Proposed` /
`TODO(eng-approval)` while the branch has shipped it, and assert the guardian
proposes a cited "Decision (shipped)" reconciliation without editing the spec.

To eval it for real, install the working-tree plugin first, then:

```bash
SKILL_EVALS=on scripts/tests/skill-evals/run-evals.sh --only 'reconcile-spec/*' --runs 3
```
