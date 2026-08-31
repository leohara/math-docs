# Repository Workflow

These instructions apply to the whole repository.

## Workspaces

- Treat the primary checkout as investigation-only. Do not create, edit, move, rename, or delete repository files there unless the user explicitly grants a primary-edit exception for the current task.
- Use an up-to-date local `main` as the base branch for task worktrees.
- Put task worktrees at `.worktrees/<branch-slug>`, where `<branch-slug>` is the dedicated branch name with `/` replaced by `-`.
- Use a dedicated task branch such as `docs/<short-slug>` or `fix/<short-slug>`; never reuse `main` as the task branch.
- Before the first normal repository write, run `sh .codex/skills/using-git-worktrees/scripts/worktree-context.sh`, then create the isolated checkout with `sh .codex/skills/using-git-worktrees/scripts/worktree-add.sh <branch-name>`. The creation helper requires the primary checkout to be clean and on `main`, updates local `main` with `git pull --ff-only origin main`, and stops before worktree creation if the preflight or pull fails or the resulting local `main` does not match `origin/main`.
- Continue in an existing task worktree only when its path, branch, and task all match the requested work.

## TeX Verification

- For TeX or build-related changes, follow `.codex/skills/tex-document-editing/SKILL.md` and run `latexmk main.tex` from the repository root.
- Inspect the build result, log warnings, generated artifacts, repository diff, and status. If `latexmk` is unavailable, report the verification as skipped with that reason; do not claim it passed.

## Reporting

- Report the worktree path, task branch, base branch, changed files, and verification commands with pass, fail, or skipped status.
- Mention relevant TeX warnings and whether generated artifacts changed.
- Do not commit, push, or open a pull request unless the user explicitly requests it.

## Safe Cleanup

- Remove worktrees only when cleanup is requested and `.codex/skills/remove-unused-git-worktrees/SKILL.md` has been followed.
- Never remove the primary or current worktree, a dirty or locked worktree, or an unmerged branch worktree. Never force-remove a worktree.
