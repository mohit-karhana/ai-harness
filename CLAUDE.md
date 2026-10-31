# AI Engineering Harness: repository instructions

@AGENTS.md

## Working on this repository

This repository *is* the harness. `AGENTS.md` above is the company standard
that gets installed into projects; it also applies to work here. There is no
`.ai-harness/project-context.md` in this repo, so use this section as the
project context.

- **Layout**: canonical content lives in `instructions/`, `skills/`,
  `workflows/`, `templates/` and `config/`. The installer engine is in
  `scripts/lib/` (`detect.sh` → `build.sh` → `reconcile.sh`, orchestrated by
  `apply.sh`). Tests are in `tests/run_tests.sh`.
- **Shell rules**: scripts must run on macOS bash 3.2 and Linux bash 5. No
  associative arrays, `mapfile`, `${var,,}`, `sed -i` without a suffix, or
  GNU-only flags. Never `source` or execute files from target projects.
- **Frontmatter is an interface**: instruction files need
  `description`/`globs`/`alwaysApply`; skills need `name` (equal to the folder)
  and `description`; workflows need `description`/`argument-hint`.
- **Before committing** run:
  ```bash
  ./scripts/validate.sh && ./tests/run_tests.sh
  ```
- **Releases**: bump `VERSION` (semver) and add a `CHANGELOG.md` entry for any
  change engineers will receive through `update.sh`.
