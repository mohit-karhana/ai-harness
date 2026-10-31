---
description: Investigate unexplained behaviour, errors or slowness with a hypothesis-driven loop — diagnose before changing code
argument-hint: <symptom, error message, failing test or "why does X happen?">
---
# Debugging Workflow

Apply this workflow to the task provided by the user. This workflow is about **understanding**
a problem. It ends with a diagnosis and a recommended fix; switch to the bug-fix workflow (or ask
the user) before changing production code.
Primary skill: **debug-issue**. Supporting skills: database-optimization (slowness, DB load),
write-tests (reproduction tests).

## Phase 1 — Inspect

1. Read `.ai-harness/project-context.md`: how to run the app/tests, environments, known pitfalls.
2. Restate the symptom precisely: what happens, what should happen, where (env), since when,
   how often (always / intermittent / under load).
3. Gather evidence without touching production: stack traces, sanitized logs, failing CI output,
   recent changes (`git log --since=... -- <path>`), dependency changes (lockfile diff).

**Data safety:** do not connect to production systems or request customer data, tokens or full
production logs. Ask a human for sanitized excerpts.

**Exit criteria:** a precise problem statement and an inventory of evidence.

## Phase 2 — Plan

1. Reproduce locally — preferably as a failing test, otherwise a minimal script/request.
2. List 2–5 candidate hypotheses ranked by likelihood × cheapness to test.
3. For each, define an experiment that could **disprove** it.

**Exit criteria:** a reproduction (or a clear statement that one is not possible yet and what is
needed) and a ranked hypothesis list.

## Phase 3 — Investigate (Implement phase of this workflow)

Loop until the root cause is confirmed:

1. Pick the top hypothesis; run its experiment (targeted logging, debugger, `git bisect`,
   inspecting SQL/EXPLAIN, isolating config, toggling a dependency version locally).
2. Record: hypothesis → experiment → observation → confirmed/rejected.
3. Update the hypothesis list with what you learned.

Techniques by symptom:
- **Intermittent/flaky:** look for shared state, ordering, time, concurrency, network; run the test
  in a loop (`pytest -x --count=50` with pytest-repeat, `npx jest --runInBand` repeatedly).
- **Slow:** measure first (query counts, profiler like `py-spy`/`cProfile`, Chrome performance
  tab, `EXPLAIN ANALYZE` locally) → **database-optimization**.
- **Works locally, fails in CI/staging:** diff environment: versions, env vars (names), settings,
  data volume, timezone, locale, file system case sensitivity.
- **Regression:** `git bisect` between a known-good and known-bad commit with an automated check.

**⏸ Checkpoint:** ask before any experiment that writes to shared databases, changes shared
configuration, restarts services in shared environments, or needs elevated access.

## Phase 4 — Test

1. Confirm the root cause explains **all** observed symptoms, not just one.
2. If a fix is obvious and the user agreed, write the failing regression test (**write-tests**);
   otherwise leave the reproduction test or script for the bug-fix workflow.
3. Remove temporary instrumentation you added.

## Phase 5 — Review

Sanity-check the diagnosis: could an alternative explanation produce the same evidence? Note
remaining uncertainty honestly.

## Phase 6 — Hand-off

```markdown
## Diagnosis: <short title>
**Confidence:** High | Medium | Low

### Symptom
<precise statement>

### Root cause
<explanation with `file:line` references>

### Investigation log
| # | Hypothesis | Experiment | Result |
|---|---|---|---|
| 1 | ... | ... | Rejected — ... |

### Reproduction
<test name or steps>

### Recommended fix
<minimal change, alternatives, risks> — apply via the bug-fix workflow after approval

### Open questions / data needed
- <item>
```
