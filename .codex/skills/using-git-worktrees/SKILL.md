---
name: using-git-worktrees
description: Create an isolated task checkout under `.worktrees/` from `main` before repository writes, while protecting the primary checkout and rejecting branch or worktree collisions.
---

# Using Git Worktrees

Use this skill before creating, editing, moving, renaming, or deleting files in this repository. If the user explicitly grants a primary-edit exception for the current task, that exception controls only that task.

## Workflow

1. From anywhere in this repository, inspect the current context:

   ```sh
   sh .codex/skills/using-git-worktrees/scripts/worktree-context.sh
   git status --short --branch
   git worktree list --porcelain
   ```

2. Normally, if `is_primary=true`, do not write repository files there. If already in the correct dedicated worktree, continue there.
3. Confirm `.worktrees/` is ignored. The repository convention is:
   - base branch: `main`
   - task branch: a dedicated name such as `docs/<short-slug>` or `fix/<short-slug>`
   - path: `.worktrees/<branch-slug>`, replacing `/` with `-`
4. Create a new branch and worktree with the checked helper:

   ```sh
   sh .codex/skills/using-git-worktrees/scripts/worktree-add.sh docs/example-task
   ```

   The helper refuses `main`, invalid names, existing local or remote branches, registered worktree conflicts, and occupied target paths. It never falls back to the current branch as its base.
5. Change the execution working directory to the printed path and keep implementation and verification there.
6. For TeX changes, use the `tex-document-editing` skill and run its standard verification.

## Report

Report the absolute worktree path, dedicated branch, `main` base ref, implementation status, and each verification result. Mark unavailable verification as skipped with the exact reason.

Do not commit, push, open a pull request, or remove a worktree unless the user requests that action. For requested cleanup, use the `remove-unused-git-worktrees` skill.
