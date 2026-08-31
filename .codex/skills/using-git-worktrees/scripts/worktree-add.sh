#!/bin/sh

set -eu

usage() {
  echo "Usage: sh $0 <branch-name>" >&2
  exit 2
}

[ "$#" -eq 1 ] || usage

branch_name="$1"
base_branch=main

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: run this helper inside the repository." >&2
  exit 1
fi

if ! git check-ref-format --branch "$branch_name" >/dev/null 2>&1; then
  echo "Error: invalid branch name: $branch_name" >&2
  exit 1
fi

if [ "$branch_name" = "$base_branch" ]; then
  echo "Error: use a dedicated task branch, not main." >&2
  exit 1
fi

case "$branch_name" in
  */*) ;;
  *)
    echo "Error: use a dedicated namespaced branch such as docs/<short-slug>." >&2
    exit 1
    ;;
esac

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
context="$(sh "$script_dir/worktree-context.sh")"
primary_root="$(printf '%s\n' "$context" | sed -n 's/^primary_root=//p')"

if [ -z "$primary_root" ]; then
  echo "Error: could not determine the primary checkout." >&2
  exit 1
fi

cd "$primary_root"

if ! git check-ignore -q .worktrees/; then
  echo "Error: .worktrees/ is not ignored; update .gitignore first." >&2
  exit 1
fi

if git show-ref --verify --quiet "refs/heads/$branch_name"; then
  echo "Error: local branch already exists: $branch_name" >&2
  exit 1
fi

if git show-ref --verify --quiet "refs/remotes/origin/$branch_name"; then
  echo "Error: remote branch already exists: $branch_name" >&2
  exit 1
fi

branch_ref="refs/heads/$branch_name"
if git worktree list --porcelain | awk -v branch="$branch_ref" '$1 == "branch" && $2 == branch { found = 1 } END { exit !found }'; then
  echo "Error: branch is already registered to a worktree: $branch_name" >&2
  exit 1
fi

branch_slug="$(printf '%s' "$branch_name" | tr '/' '-')"
worktree_root="$primary_root/.worktrees"
target_path="$worktree_root/$branch_slug"

if git worktree list --porcelain | awk -v path="$target_path" '$1 == "worktree" && substr($0, 10) == path { found = 1 } END { exit !found }'; then
  echo "Error: target path is already a registered worktree: $target_path" >&2
  exit 1
fi

if [ -e "$target_path" ] || [ -L "$target_path" ]; then
  echo "Error: target path already exists: $target_path" >&2
  exit 1
fi

if ! git show-ref --verify --quiet "refs/heads/$base_branch"; then
  echo "Error: local main is unavailable." >&2
  exit 1
fi

primary_branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
if [ "$primary_branch" != "$base_branch" ]; then
  echo "Error: the primary checkout must have main checked out." >&2
  exit 1
fi

if ! primary_status="$(git status --porcelain --untracked-files=normal)"; then
  echo "Error: could not inspect the primary checkout status." >&2
  exit 1
fi

if [ -n "$primary_status" ]; then
  echo "Error: the primary checkout must be clean before updating main." >&2
  exit 1
fi

if ! git pull --ff-only origin "$base_branch" >&2; then
  echo "Error: could not fast-forward local main from origin/main." >&2
  exit 1
fi

if ! primary_status="$(git status --porcelain --untracked-files=normal)"; then
  echo "Error: could not inspect the primary checkout status after updating main." >&2
  exit 1
fi

if [ -n "$primary_status" ]; then
  echo "Error: the primary checkout is not clean after updating main." >&2
  exit 1
fi

local_main="$(git rev-parse --verify "refs/heads/$base_branch")"
if ! remote_main="$(git rev-parse --verify "refs/remotes/origin/$base_branch")"; then
  echo "Error: origin/main is unavailable after the pull." >&2
  exit 1
fi

if [ "$local_main" != "$remote_main" ]; then
  echo "Error: local main does not match origin/main after the pull." >&2
  exit 1
fi

mkdir -p "$worktree_root"
git worktree add -b "$branch_name" "$target_path" "$base_branch" >&2

printf '%s\n' "$target_path"
