---
name: remove-unused-git-worktrees
description: Inspect and safely remove only clean, merged, unlocked, non-current, non-primary git worktrees, without force removal.
---

# Remove Unused Git Worktrees

Use this skill only when worktree cleanup is requested. The comparison base is `main`.

## Inventory And Classification

1. Run the context helper from a worktree that will be kept, then inventory all registered entries:

   ```sh
   sh .codex/skills/using-git-worktrees/scripts/worktree-context.sh
   git worktree list --porcelain
   ```

2. For every candidate, verify all of the following:
   - **primary:** its path differs from `primary_root`; always keep the primary checkout;
   - **current:** its path differs from `current_root`; always keep the current worktree;
   - **locked:** its porcelain record has no `locked` line; keep locked worktrees;
   - **clean:** with that worktree as the command working directory, `git status --short` is empty;
   - **merged:** its attached branch tip is an ancestor of local `main`, or of `origin/main` only when local `main` is unavailable. Use `git merge-base --is-ancestor <branch> <base-ref>`. Keep detached, unknown, or unmerged entries.
3. Summarize candidates as `remove` or `keep`, including the evidence for clean, merged, locked, current, and primary checks. Missing paths or stale metadata require separate inspection; do not treat them as safe removals automatically.

## Removal

Remove candidates one at a time only when every safety check passed:

```sh
git worktree remove <exact-worktree-path>
git worktree list --porcelain
```

Never use `--force` or `-f`. If Git reports a dirty or locked worktree, stop and keep it. Do not delete its branch unless the user separately requests branch cleanup; then use `git branch -d`, never `-D` without explicit discard approval.

Report each removed path and the final worktree inventory. If nothing qualifies, report that no worktrees were removed.
