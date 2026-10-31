---
name: debug-issue
description: Systematically find the root cause of a bug, error, failing test or unexpected behaviour using a hypothesis-driven loop, reproduce it with a failing test, then apply the smallest correct fix. Use when the user reports an error, stack trace, crash, regression, flaky test or "it doesn't work".
---

# Debug Issue

## Purpose

Replace guess-and-patch debugging with an evidence-driven loop: reproduce → hypothesise → test
the hypothesis → fix the root cause → prove the fix with a test. The goal is a minimal, explained
fix and a regression test, not a pile of speculative changes.

## When to use

- Exceptions, stack traces, 500 errors, failing CI jobs, failing or flaky tests
- "This used to work", wrong results, data not saved, UI not updating
- Performance regressions with a clear trigger (otherwise see `database-optimization`)

### When NOT to use

- The user wants a new behaviour, not a fix → `implement-feature`.
- Incident on production happening *right now* → help the human on-call follow the incident
  runbook; do not attempt live fixes on production yourself.

## Required context

1. `.ai-harness/project-context.md` — how to run the app and tests, environments, known pitfalls.
2. `.ai-harness/instructions/general.md`, `testing.md` and the stack file for the affected code.
3. From the user (ask if missing): exact error message/stack trace, steps to reproduce, expected
   vs actual behaviour, environment (local/staging/prod), when it started, recent deploys/changes.
4. `git log -p --since=<when it started> -- <suspect paths>` to see recent changes.

**Data safety:** never debug against production databases, never ask the user to paste customer
data, tokens or full production logs. Use redacted samples, fixtures or synthetic data. If a
production-only symptom exists, ask a human to extract a sanitized reproduction.

## Steps

1. **Restate the problem** in one or two sentences: symptom, scope, expected behaviour.
2. **Reproduce locally.** Prefer the narrowest reproduction:
   - A failing automated test (best): `pytest tests/x/test_y.py::test_case -x -vv`,
     `python manage.py test app.tests.TestX`, `npx jest path -t "name"`, `npx vitest run path`.
   - Otherwise a minimal script or request (`curl`, shell, REPL) against a local/dev environment.
   If you cannot reproduce, say so and gather more evidence instead of guessing.
3. **Read the evidence.** Read the full stack trace bottom-up to the first frame in project code.
   Read the code paths involved — callers and callees — not just the line that raised.
4. **Hypothesis loop.** For each hypothesis:
   - State it explicitly ("`order.total` is None because the signal runs before items are saved").
   - Design the cheapest experiment that can *disprove* it: a targeted assertion, a log line,
     a debugger breakpoint (`breakpoint()`, `node --inspect`), `git bisect`, inspecting SQL.
   - Run it, record the result, and keep or discard the hypothesis.
   Keep a short log of hypotheses and results; share it in the final report.
5. **Identify the root cause**, not just the trigger. Ask "why" until you reach the defect in code,
   configuration, data assumptions or concurrency. Check whether the same defect exists elsewhere.
6. **Write the regression test first** (it must fail before the fix). Use the `write-tests` skill.
7. **Fix minimally.** Change only what the root cause requires; follow existing conventions; no
   opportunistic refactors in the same change (note them as follow-ups).
   **Stop and ask for approval** before: data fixes/backfills, migrations, deleting data, changing
   configuration of shared environments, or anything touching production.
8. **Verify.** Run the regression test, the surrounding test module and the full suite if fast.
   Remove temporary debug logging and breakpoints.
9. **Review** the diff with the `code-review` checklist.

## Expected output

- **Root cause:** what was wrong and why, with `file:line` references.
- **Evidence:** reproduction steps and the hypotheses tested (confirmed / rejected).
- **Fix:** summary of the change and why it is the minimal correct fix.
- **Tests:** the regression test name, commands run and results.
- **Impact & follow-ups:** affected users/data, whether a data repair is needed (requires human
  approval), related places that may have the same bug.

## Validation checklist

- [ ] Problem reproduced (or clearly stated why reproduction was impossible)
- [ ] Root cause identified and explained, not just the symptom suppressed
- [ ] No production data accessed; no secrets or PII copied into prompts or code
- [ ] Regression test fails before the fix and passes after
- [ ] Fix is minimal; no unrelated changes; exceptions not silently swallowed
- [ ] Temporary logging/breakpoints removed
- [ ] Relevant test suites pass
- [ ] Data repair / migration needs flagged and approved by a human
