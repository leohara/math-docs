#!/bin/sh

set -eu

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
project_root="$(CDPATH= cd -- "$script_dir/../../../.." && pwd -P)"
helper="$project_root/.codex/skills/using-git-worktrees/scripts/worktree-add.sh"

test_root="$(mktemp -d "${TMPDIR:-/tmp}/worktree-add-test.XXXXXX")"
test_root="$(CDPATH= cd -- "$test_root" && pwd -P)"
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_TERMINAL_PROMPT=0
export GIT_AUTHOR_NAME='Worktree Helper Test'
export GIT_AUTHOR_EMAIL='worktree-helper@example.invalid'
export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_equal() {
  actual="$1"
  expected="$2"
  message="$3"
  [ "$actual" = "$expected" ] || fail "$message (expected '$expected', got '$actual')"
}

assert_contains() {
  file="$1"
  expected="$2"
  message="$3"
  if ! grep -F "$expected" "$file" >/dev/null 2>&1; then
    sed -n '1,160p' "$file" >&2
    fail "$message"
  fi
}

setup_fixture() {
  fixture_name="$1"
  fixture_root="$test_root/$fixture_name"
  fixture_origin="$fixture_root/origin.git"
  fixture_seed="$fixture_root/seed"
  fixture_primary="$fixture_root/primary"
  fixture_publisher="$fixture_root/publisher"

  mkdir -p "$fixture_root"
  git init --bare "$fixture_origin" >/dev/null 2>&1
  git init "$fixture_seed" >/dev/null 2>&1
  git -C "$fixture_seed" checkout -b main >/dev/null 2>&1
  printf '.worktrees/\n' >"$fixture_seed/.gitignore"
  printf 'initial\n' >"$fixture_seed/document.txt"
  git -C "$fixture_seed" add .gitignore document.txt
  git -C "$fixture_seed" commit -m initial >/dev/null
  git -C "$fixture_seed" remote add origin "$fixture_origin"
  git -C "$fixture_seed" push -u origin main >/dev/null 2>&1
  git --git-dir="$fixture_origin" symbolic-ref HEAD refs/heads/main
  git clone "$fixture_origin" "$fixture_primary" >/dev/null 2>&1
  git clone "$fixture_origin" "$fixture_publisher" >/dev/null 2>&1
}

publish_main_change() {
  change_name="$1"
  printf '%s\n' "$change_name" >"$fixture_publisher/$change_name.txt"
  git -C "$fixture_publisher" add "$change_name.txt"
  git -C "$fixture_publisher" commit -m "$change_name" >/dev/null
  git -C "$fixture_publisher" push origin main >/dev/null 2>&1
  published_tip="$(git -C "$fixture_publisher" rev-parse HEAD)"
}

assert_no_task_worktree() {
  branch_name="$1"
  target_path="$2"
  if git -C "$fixture_primary" show-ref --verify --quiet "refs/heads/$branch_name"; then
    fail "task branch was created after a rejected preflight"
  fi
  [ ! -e "$target_path" ] && [ ! -L "$target_path" ] || fail "task worktree path was created after a rejected preflight"
}

test_fast_forwards_main_before_creation() (
  setup_fixture success
  initial_tip="$(git -C "$fixture_primary" rev-parse main)"
  publish_main_change remote-update
  [ "$initial_tip" != "$published_tip" ] || fail "fixture did not advance origin/main"

  branch_name=docs/latest-main
  target_path="$fixture_primary/.worktrees/docs-latest-main"
  stdout_file="$fixture_root/stdout"
  stderr_file="$fixture_root/stderr"
  (cd "$fixture_primary" && sh "$helper" "$branch_name") >"$stdout_file" 2>"$stderr_file"

  helper_output="$(sed -n '1p' "$stdout_file")"
  assert_equal "$helper_output" "$target_path" "helper did not print the created worktree path"
  assert_equal "$(git -C "$fixture_primary" rev-parse main)" "$published_tip" "local main was not fast-forwarded"
  assert_equal "$(git -C "$target_path" rev-parse HEAD)" "$published_tip" "task worktree was not based on updated main"
)

test_rejects_dirty_primary_before_pull() (
  setup_fixture dirty-primary
  initial_tip="$(git -C "$fixture_primary" rev-parse main)"
  publish_main_change remote-update
  printf 'local change\n' >"$fixture_primary/untracked.txt"

  branch_name=docs/dirty-primary
  target_path="$fixture_primary/.worktrees/docs-dirty-primary"
  stdout_file="$fixture_root/stdout"
  stderr_file="$fixture_root/stderr"
  if (cd "$fixture_primary" && sh "$helper" "$branch_name") >"$stdout_file" 2>"$stderr_file"; then
    fail "helper accepted a dirty primary checkout"
  fi

  assert_contains "$stderr_file" "Error: the primary checkout must be clean before updating main." "missing dirty-primary error"
  assert_equal "$(git -C "$fixture_primary" rev-parse main)" "$initial_tip" "helper pulled before rejecting dirty primary state"
  assert_no_task_worktree "$branch_name" "$target_path"
)

test_stops_before_creation_when_pull_cannot_fast_forward() (
  setup_fixture diverged-main
  printf 'local commit\n' >"$fixture_primary/local.txt"
  git -C "$fixture_primary" add local.txt
  git -C "$fixture_primary" commit -m local-divergence >/dev/null
  local_tip="$(git -C "$fixture_primary" rev-parse main)"
  publish_main_change remote-divergence

  branch_name=docs/diverged-main
  target_path="$fixture_primary/.worktrees/docs-diverged-main"
  stdout_file="$fixture_root/stdout"
  stderr_file="$fixture_root/stderr"
  if (cd "$fixture_primary" && sh "$helper" "$branch_name") >"$stdout_file" 2>"$stderr_file"; then
    fail "helper accepted a diverged local main"
  fi

  assert_contains "$stderr_file" "Error: could not fast-forward local main from origin/main." "missing fast-forward failure error"
  assert_equal "$(git -C "$fixture_primary" rev-parse main)" "$local_tip" "failed pull changed local main"
  assert_no_task_worktree "$branch_name" "$target_path"
)

test_rejects_local_main_ahead_of_origin() (
  setup_fixture ahead-main
  printf 'local commit\n' >"$fixture_primary/local.txt"
  git -C "$fixture_primary" add local.txt
  git -C "$fixture_primary" commit -m local-ahead >/dev/null
  local_tip="$(git -C "$fixture_primary" rev-parse main)"

  branch_name=docs/ahead-main
  target_path="$fixture_primary/.worktrees/docs-ahead-main"
  stdout_file="$fixture_root/stdout"
  stderr_file="$fixture_root/stderr"
  if (cd "$fixture_primary" && sh "$helper" "$branch_name") >"$stdout_file" 2>"$stderr_file"; then
    fail "helper accepted a local main ahead of origin/main"
  fi

  assert_contains "$stderr_file" "Error: local main does not match origin/main after the pull." "missing ahead-main error"
  assert_equal "$(git -C "$fixture_primary" rev-parse main)" "$local_tip" "ahead-main rejection changed local main"
  assert_no_task_worktree "$branch_name" "$target_path"
)

test_preserves_collision_preflight() (
  setup_fixture branch-collision
  initial_tip="$(git -C "$fixture_primary" rev-parse main)"
  publish_main_change remote-update
  branch_name=docs/existing
  git -C "$fixture_primary" branch "$branch_name"
  target_path="$fixture_primary/.worktrees/docs-existing"
  stdout_file="$fixture_root/stdout"
  stderr_file="$fixture_root/stderr"
  if (cd "$fixture_primary" && sh "$helper" "$branch_name") >"$stdout_file" 2>"$stderr_file"; then
    fail "helper accepted an existing local branch"
  fi

  assert_contains "$stderr_file" "Error: local branch already exists: $branch_name" "missing branch-collision error"
  assert_equal "$(git -C "$fixture_primary" rev-parse main)" "$initial_tip" "helper pulled before rejecting a branch collision"
  [ ! -e "$target_path" ] && [ ! -L "$target_path" ] || fail "collision preflight created a target path"
)

test_fast_forwards_main_before_creation
test_rejects_dirty_primary_before_pull
test_stops_before_creation_when_pull_cannot_fast_forward
test_rejects_local_main_ahead_of_origin
test_preserves_collision_preflight

printf 'PASS: worktree-add helper tests\n'
