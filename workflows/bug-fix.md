---
description: Fix a bug safely — reproduce with a failing test, find the root cause, minimal fix, verify, report
argument-hint: <bug description, error message, stack trace or ticket>
---
# Bug Fix Workflow

Apply this workflow to the task provided by the user.
Primary skill: **debug-issue**. Supporting skills: write-tests, code-review, database-optimization.

## Phase 1 — Inspect

1. Read `.ai-harness/project-context.md` (commands, environments, known pitfalls).
2. Restate the bug: symptom, expected vs actual behaviour, scope (who/what is affected), since when.
3. Collect evidence: stack trace, logs (sanitized), recent commits in the affected area
   (`git log --oneline -20 -- <path>`).
4. If information is missing (steps to reproduce, environment, error text), ask for it.

**Data safety:** never query production, never request raw customer data or secrets. Ask a human
for sanitized samples if the bug only appears with production data.

**Exit criteria:** the bug is reproduced locally — ideally as a failing automated test — or you
have reported exactly why it cannot be reproduced and what you need.

## Phase 2 — Plan

1. Run the **debug-issue** hypothesis loop until the root cause is confirmed with evidence.
2. Propose the minimal fix and list alternatives you rejected.
3. Assess blast radius: other call sites with the same defect, data already corrupted, need for a
   data repair, compatibility impact.

**⏸ Checkpoint — human approval required** if the fix needs a migration, a data repair/backfill,
a change in a public contract, configuration changes in shared environments, or is a hotfix for
production. Otherwise proceed and state that you did.

## Phase 3 — Implement

1. Write the regression test first (**write-tests**) and confirm it fails.
2. Apply the minimal fix following existing conventions. No unrelated refactors.
3. Do not suppress the error (no blanket `try/except`, no disabling tests, no `# type: ignore`
   without reason).

**Exit criteria:** the regression test passes with the fix and fails without it.

## Phase 4 — Test

1. Run the regression test, the affected module's tests and the full suite if reasonably fast.
2. Run lint/type checks from project-context.
3. Manually verify the original reproduction steps locally if they were not fully automated.

**Exit criteria:** all relevant tests pass.

## Phase 5 — Review

1. **code-review** your diff. Check especially: root cause addressed, no new edge-case bugs,
   error handling, backward compatibility.
2. Remove debugging artefacts (print statements, breakpoints, temporary logging).

## Phase 6 — Hand-off

```markdown
## Bug fix: <short title>

### Root cause
<explanation with `file:line` references>

### Evidence
- Reproduction: <steps or test name>
- Hypotheses tested: <h1 — rejected because...>, <h2 — confirmed by...>

### Fix
- `path/file` — <change and why it is minimal and correct>

### Verification
- `<command>` → <result>  (regression test failed before fix: yes)

### Impact & follow-ups
- Affected data/users: <...>; data repair needed: <yes/no — requires human approval>
- Same pattern elsewhere: <locations or "none found">
```

Never commit, push or deploy unless the user explicitly asks.
