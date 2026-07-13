#!/usr/bin/env bash
# Test harness for the Specto vcs helpers. Builds throwaway git repos in temp
# dirs at runtime and pins the jj behaviour with a mock `jj` binary on PATH —
# no real jj is required (or trusted: a no-op mock shadows any installed jj so
# the plain-git assertions stay deterministic on jj-equipped machines).

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/.."

# Shared assertion helpers + PASS/FAIL counters.
source "$HERE/../../tests/lib/assert.sh"

# These override the helpers' resolution order; a stray value from the calling
# shell would poison every assertion below.
unset SOURCE_BRANCH TRUNK

# Throwaway git repo with one commit on `main`; prints its canonicalized path
# (`cd && pwd`, so macOS /var -> /private/var never breaks string matches).
make_repo() {
  local d
  d="$(cd "$(mktemp -d -t specto-vcs-test.XXXXXX)" && pwd)"
  git -C "$d" init -q -b main
  git -C "$d" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  printf '%s\n' "$d"
}

# Mock jj: canned answers driven by MOCK_JJ_* env vars, argv appended to
# $MOCK_JJ_LOG. Covers exactly the invocations _lib.sh makes (root/log/config/diff).
MOCK_JJ="$(mktemp -d -t specto-vcs-mockjj.XXXXXX)"
cat > "$MOCK_JJ/jj" <<'EOF'
#!/usr/bin/env bash
[[ -n "${MOCK_JJ_LOG:-}" ]] && echo "$@" >> "$MOCK_JJ_LOG"
cmd="${1:-}"; shift || true
case "$cmd" in
  root)   [[ "${MOCK_JJ_ROOT_OK:-1}" == "1" ]] || exit 1; pwd ;;
  log)    # jj log --no-graph -r <rev> -T <template>  -> rev is $3
          if [[ "${3:-}" == "@" ]]; then printf '%s\n' "${MOCK_JJ_BOOKMARK_AT:-}"
          else printf '%s\n' "${MOCK_JJ_BOOKMARK_PARENT:-}"; fi ;;
  config) printf '%s\n' "${MOCK_JJ_TRUNK_ALIAS:-}" ;;
  diff)   [[ "${MOCK_JJ_DIFF_OK:-1}" == "1" ]] || exit 1
          printf '%s\n' "${MOCK_JJ_DIFF_OUT:-MOCKDIFF}" ;;
  *)      exit 1 ;;
esac
EOF
chmod +x "$MOCK_JJ/jj"
# Not-a-jj-workspace variant: every jj call fails, like real jj outside a repo.
MOCK_NOJJ="$(mktemp -d -t specto-vcs-nojj.XXXXXX)"
printf '#!/usr/bin/env bash\nexit 1\n' > "$MOCK_NOJJ/jj"
chmod +x "$MOCK_NOJJ/jj"

CLEANUP=("$MOCK_JJ" "$MOCK_NOJJ")
trap 'rm -rf "${CLEANUP[@]}"' EXIT

# --------------------------------------------------------------------------------
# source-branch.sh
# --------------------------------------------------------------------------------
echo "== source-branch.sh =="
R="$(make_repo)"; CLEANUP+=("$R")

out="$(cd "$R" && PATH="$MOCK_NOJJ:$PATH" "$DIR/source-branch.sh" 2>/dev/null)"; rc=$?
assert_exit 0 "$rc" "plain-git: exit code 0"
assert "plain-git" "current branch via symbolic-ref" "$out" "main"

out="$(cd "$R" && SOURCE_BRANCH=override "$DIR/source-branch.sh" 2>/dev/null)"
assert "override" "\$SOURCE_BRANCH wins over the checkout" "$out" "override"

# Detached HEAD on a commit only feature-x points at -> for-each-ref fallback.
git -C "$R" checkout -q -b feature-x
git -C "$R" -c user.email=t@t -c user.name=t commit -q --allow-empty -m work
git -C "$R" checkout -q --detach
out="$(cd "$R" && PATH="$MOCK_NOJJ:$PATH" "$DIR/source-branch.sh" 2>/dev/null)"; rc=$?
assert_exit 0 "$rc" "detached: exit code 0"
assert "detached" "local branch pointing at HEAD found" "$out" "feature-x"

# Same detached repo, jj workspace: the bookmark on @ wins before for-each-ref.
out="$(cd "$R" && PATH="$MOCK_JJ:$PATH" MOCK_JJ_BOOKMARK_AT=wip-bookmark "$DIR/source-branch.sh" 2>/dev/null)"
assert "jj-detached" "bookmark on @ wins" "$out" "wip-bookmark"
# No bookmark on @ (jj's usual post-push state) -> the one on @- is taken.
out="$(cd "$R" && PATH="$MOCK_JJ:$PATH" MOCK_JJ_BOOKMARK_PARENT=parent-bookmark "$DIR/source-branch.sh" 2>/dev/null)"
assert "jj-detached" "empty @ falls through to the @- bookmark" "$out" "parent-bookmark"

"$DIR/source-branch.sh" extra-arg >/dev/null 2>&1; rc=$?
assert_exit 2 "$rc" "bad usage: unexpected argument -> exit 2"

# --------------------------------------------------------------------------------
# trunk.sh
# --------------------------------------------------------------------------------
echo
echo "== trunk.sh =="
T="$(make_repo)"; CLEANUP+=("$T")

out="$(cd "$T" && TRUNK=release "$DIR/trunk.sh" 2>/dev/null)"
assert "trunk-override" "\$TRUNK wins over everything" "$out" "release"

out="$(cd "$T" && PATH="$MOCK_NOJJ:$PATH" "$DIR/trunk.sh" 2>/dev/null)"; rc=$?
assert_exit 3 "$rc" "no origin refs at all -> exit 3"
assert "trunk-none" "prints nothing when unresolvable" "$out" ""

# origin/HEAD unset but origin/master exists -> the existence probe finds it.
git -C "$T" update-ref refs/remotes/origin/master HEAD
out="$(cd "$T" && PATH="$MOCK_NOJJ:$PATH" "$DIR/trunk.sh" 2>/dev/null)"; rc=$?
assert_exit 0 "$rc" "origin probe: exit code 0"
assert "trunk-probe" "origin/master found without origin/HEAD" "$out" "master"

# origin/HEAD set -> it wins over the probe (and over jj).
git -C "$T" update-ref refs/remotes/origin/main HEAD
git -C "$T" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
out="$(cd "$T" && PATH="$MOCK_JJ:$PATH" MOCK_JJ_TRUNK_ALIAS='dev@origin' "$DIR/trunk.sh" 2>/dev/null)"
assert "trunk-origin-head" "origin/HEAD symbolic ref wins" "$out" "main"

# jj workspace, no origin/HEAD: a plain <branch>@<remote> trunk() alias names it.
J="$(make_repo)"; CLEANUP+=("$J")
out="$(cd "$J" && PATH="$MOCK_JJ:$PATH" MOCK_JJ_TRUNK_ALIAS='dev@origin' "$DIR/trunk.sh" 2>/dev/null)"; rc=$?
assert_exit 0 "$rc" "jj alias: exit code 0"
assert "trunk-jj" "branch parsed from the trunk() alias" "$out" "dev"
# jj's shipped composite default names no single branch -> fall to the probe.
git -C "$J" update-ref refs/remotes/origin/master HEAD
out="$(cd "$J" && PATH="$MOCK_JJ:$PATH" MOCK_JJ_TRUNK_ALIAS='latest((present(main) | present(master))@origin)' "$DIR/trunk.sh" 2>/dev/null)"
assert "trunk-jj-composite" "composite alias falls through to the origin probe" "$out" "master"

"$DIR/trunk.sh" extra-arg >/dev/null 2>&1; rc=$?
assert_exit 2 "$rc" "bad usage: unexpected argument -> exit 2"

# --------------------------------------------------------------------------------
# branch-diff.sh
# --------------------------------------------------------------------------------
echo
echo "== branch-diff.sh =="
D="$(make_repo)"; CLEANUP+=("$D")
git -C "$D" update-ref refs/remotes/origin/main HEAD   # trunk resolves to "main"
git -C "$D" checkout -q -b f-change                    # local main stays at the base commit
echo "new line" > "$D/f.txt"
git -C "$D" add f.txt
git -C "$D" -c user.email=t@t -c user.name=t commit -q -m change

out="$(cd "$D" && PATH="$MOCK_NOJJ:$PATH" "$DIR/branch-diff.sh" 2>/dev/null)"; rc=$?
assert_exit 0 "$rc" "plain-git diff: exit code 0"
assert "diff-git" "diff contains the added line" "$(printf '%s' "$out" | grep -c '^+new line$')" "1"

# jj workspace -> jj renders the diff; assert the exact revset + --git argv.
JLOG="$(mktemp -t specto-vcs-jjlog.XXXXXX)"; CLEANUP+=("$JLOG")
out="$(cd "$D" && PATH="$MOCK_JJ:$PATH" MOCK_JJ_LOG="$JLOG" MOCK_JJ_DIFF_OUT=MOCKDIFF "$DIR/branch-diff.sh" 2>/dev/null)"; rc=$?
assert_exit 0 "$rc" "jj diff: exit code 0"
assert "diff-jj" "jj output passed through" "$out" "MOCKDIFF"
assert "diff-jj" "asks jj for --git -r trunk()..@" "$(grep -c -- '^diff --git -r trunk()\.\.@$' "$JLOG")" "1"

# jj workspace but the jj diff fails -> git fallback still produces the diff.
out="$(cd "$D" && PATH="$MOCK_JJ:$PATH" MOCK_JJ_DIFF_OK=0 "$DIR/branch-diff.sh" 2>/dev/null)"; rc=$?
assert_exit 0 "$rc" "jj-diff failure: exit code 0 via git fallback"
assert "diff-jj-fallback" "git fallback contains the added line" "$(printf '%s' "$out" | grep -c '^+new line$')" "1"

# No trunk resolvable -> exit 3.
N="$(make_repo)"; CLEANUP+=("$N")
(cd "$N" && PATH="$MOCK_NOJJ:$PATH" "$DIR/branch-diff.sh" >/dev/null 2>&1); rc=$?
assert_exit 3 "$rc" "no trunk -> exit 3"

"$DIR/branch-diff.sh" extra-arg >/dev/null 2>&1; rc=$?
assert_exit 2 "$rc" "bad usage: unexpected argument -> exit 2"

# --------------------------------------------------------------------------------
# --from-fixture mode (shared shape across the three wrappers)
# --------------------------------------------------------------------------------
echo
echo "== --from-fixture =="
FIX="$(mktemp -d -t specto-vcs-fix.XXXXXX)"; CLEANUP+=("$FIX")
printf 'f-fixture-branch\n' > "$FIX/source-branch.txt"
printf 'main\n' > "$FIX/trunk.txt"

out="$("$DIR/source-branch.sh" --from-fixture "$FIX" 2>/dev/null)"; rc=$?
assert_exit 0 "$rc" "fixture source-branch: exit code 0"
assert "fixture" "prints the canned branch" "$out" "f-fixture-branch"
out="$("$DIR/trunk.sh" --from-fixture "$FIX" 2>/dev/null)"
assert "fixture" "prints the canned trunk" "$out" "main"
"$DIR/branch-diff.sh" --from-fixture "$FIX" >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "fixture dir without branch-diff.txt -> exit 1"
"$DIR/branch-diff.sh" --from-fixture "$FIX/nope" >/dev/null 2>&1; rc=$?
assert_exit 3 "$rc" "missing fixture dir -> exit 3"
"$DIR/trunk.sh" --from-fixture >/dev/null 2>&1; rc=$?
assert_exit 2 "$rc" "bare --from-fixture -> exit 2"

assert_summary
