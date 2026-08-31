---
name: tex-document-editing
description: Edit and verify this repository's TeX document using its real `main.tex` entry point and LuaLaTeX-based `.latexmkrc` configuration.
---

# TeX Document Editing

Use the repository root `main.tex` as the document entry point. The checked-in `.latexmkrc` sets `pdf_mode = 4`, runs LuaLaTeX, writes auxiliary output under `.latexbuild`, and copies `.latexbuild/main.pdf` to the root `main.pdf` after a successful build.

## Workflow

1. Reconfirm the root and build configuration before editing or validating:

   ```sh
   git rev-parse --show-toplevel
   test -f main.tex
   test -f .latexmkrc
   ```

   Run subsequent commands with the repository root as the working directory. If either file is absent or the configuration no longer describes the build above, stop and report the mismatch.
2. Make the smallest requested TeX or configuration change.
3. Use the standard verification command:

   ```sh
   latexmk main.tex
   ```

   If `latexmk` is unavailable, report `latexmk main.tex: skipped (latexmk not installed or not on PATH)` explicitly. Do not substitute an unrelated build command or claim a pass.
4. After a build attempt, inspect:
   - the command exit status;
   - `.latexbuild/main.log` for LaTeX errors, undefined references or citations, package/font warnings, and overfull or underfull boxes;
   - `.latexbuild/main.pdf` and root `main.pdf` as the expected generated PDFs;
   - `git diff` and `git status --short` for source changes and generated-artifact changes.
5. Treat an exit-zero build as necessary but not sufficient: report material warnings, missing or empty PDFs, unexpected artifacts, and any diff outside the requested scope.

## Report

State whether `latexmk main.tex` passed, failed, or was skipped; summarize relevant warnings; identify generated artifacts that changed; and include the final diff/status state. Do not commit generated output unless the user requests it or the repository already tracks that artifact as part of the task.
