#!/bin/sh

set -eu

if [ "$#" -ne 0 ]; then
  echo "Usage: sh $0" >&2
  exit 2
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: run this helper inside a git worktree." >&2
  exit 1
fi

current_root="$(git rev-parse --show-toplevel)"
current_root="$(cd "$current_root" && pwd -P)"
common_dir_raw="$(git rev-parse --git-common-dir)"

case "$common_dir_raw" in
  /*) common_dir_path="$common_dir_raw" ;;
  *) common_dir_path="$current_root/$common_dir_raw" ;;
esac

common_dir="$(cd "$common_dir_path" && pwd -P)"
primary_root="$(cd "$common_dir/.." && pwd -P)"
current_branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || printf '%s' '(detached)')"

if [ "$current_root" = "$primary_root" ]; then
  is_primary=true
else
  is_primary=false
fi

printf 'current_root=%s\n' "$current_root"
printf 'primary_root=%s\n' "$primary_root"
printf 'is_primary=%s\n' "$is_primary"
printf 'current_branch=%s\n' "$current_branch"
printf 'base_branch=main\n'
printf 'worktree_root=%s/.worktrees\n' "$primary_root"
