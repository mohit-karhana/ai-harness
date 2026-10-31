---
description: Review local changes, a branch or a PR against company standards and report prioritized findings
argument-hint: <optional: PR number, branch name, base branch or file paths; defaults to local changes>
---
# Code Review Workflow

Apply this workflow to the task provided by the user. If no target was given, review the current
local changes (staged and unstaged). Primary skill: **code-review**.
Supporting skills: write-tests (to assess coverage), database-optimization (for query/migration
concerns), debug-issue (to confirm a suspected bug).

This workflow is **read-only by default**: do not modify files, commit, push or post comments
unless the user explicitly asks.

## Phase 1 — Inspect

1. Determine the review scope and state it explicitly:
   - Local: `git status`, `git diff`, `git diff --staged`
   - Branch: `git diff <base>...<branch>` and `git log --oneline <base>..<branch>`
   - PR: `gh pr view <n>` and `gh pr diff <n>` (if `gh` is available and authenticated)
2. Read `.ai-harness/project-context.md` and the instruction files matching the changed files.
3. Find the intent: PR description, linked ticket, commit messages. Ask if unclear.

**Exit criteria:** you know exactly which changes are in scope and what they are meant to do.

## Phase 2 — Plan

1. Group changed files by layer and rank by risk (auth, payments, PII, migrations, public APIs,
   concurrency first).
2. Decide what to verify by running: tests touching the change, linters, type checks, migration SQL
   (`python manage.py sqlmigrate app 0042`).

## Phase 3 — Review (Implement phase of this workflow)

1. Walk the diff with the **code-review** skill checklist, reading surrounding code for context.
2. For each potential issue, confirm it by reading code or running a check; otherwise phrase it as
   a question.
3. Classify findings: **blocker / major / minor / nit**.

## Phase 4 — Test

1. Run the checks chosen in Phase 2 (commands from project-context). Do not run anything against
   shared or production environments.
2. Assess test coverage of the new behaviour; list missing test cases as findings.

**Exit criteria:** every finding is verified or explicitly marked as a question; checks run are
recorded with results.

## Phase 5 — Verdict

- **Request changes** if any blocker exists.
- **Approve with comments** if only major/minor/nit findings that the author can address later.
- **Approve** if nothing significant was found.

**⏸ Checkpoint:** if the user wants fixes applied, confirm which findings to fix before editing.
If the user wants comments posted to the PR, show the comment text and get approval before posting.

## Phase 6 — Hand-off

```markdown
## Review: <scope, e.g. PR 123 / branch feature/x vs main>
**Intent:** <1–2 sentences>
**Verdict:** Approve | Approve with comments | Request changes

### Blockers
1. `path:line` — <issue>. <impact>. **Fix:** <suggestion>
### Major
### Minor
### Nits
### Questions
### Checks run
- `<command>` → <result>
### What's good
- <brief positive notes>
```

Omit empty sections.
