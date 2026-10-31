---
description: Build a new feature end to end — inspect, plan (with approval), implement, test, review, hand off
argument-hint: <feature description, ticket text or path to a feature spec>
---
# New Feature Workflow

Apply this workflow to the task provided by the user. If the task is a path to a spec file
(e.g. based on `.ai-harness/templates/feature-specification.md`), read it first.
Primary skill: **implement-feature**. Supporting skills: create-api, write-tests, code-review,
database-optimization, refactor-code.

## Phase 1 — Inspect

1. Read `.ai-harness/project-context.md` and the relevant `.ai-harness/instructions/*.md`.
2. Find the closest existing feature and trace its flow through the codebase
   (routing → handler/view → service → model → UI → tests).
3. Identify affected modules, contracts (APIs, events, DB schema) and the test setup.

**Exit criteria:** you can name the files/modules you will change and the conventions you will
follow, citing concrete existing examples. Do not write code in this phase.

## Phase 2 — Plan

1. Restate the task as acceptance criteria; list assumptions and open questions.
2. Produce a plan: changes per layer with file paths, data model + migration strategy, API changes,
   security considerations, test plan, rollout/rollback (feature flag?).
3. Estimate risk: low (local, additive) / medium (cross-module, migration) / high (auth, payments,
   PII, breaking contracts).

**⏸ Checkpoint — human approval required** when the change is medium/high risk, touches more than
a handful of files, adds a dependency, includes a migration, or changes a public contract. Present
the plan and open questions and wait. For low-risk, additive changes you may proceed and state that
you did.

## Phase 3 — Implement

1. Work in small, runnable increments: data → domain logic → API (**create-api**) → UI → wiring.
2. Refactor only what the feature requires; if a larger cleanup is needed, propose it separately
   (**refactor-code**).
3. Follow existing patterns; validate inputs; handle errors; no secrets or PII in code or logs.
4. Migrations: generate them, review the SQL (`sqlmigrate`, `alembic upgrade --sql`), apply only to
   your local database.

**⏸ Checkpoint:** stop and ask before destructive operations, data backfills, or anything touching
shared/staging/production environments.

**Exit criteria:** all planned changes are implemented and the app runs locally.

## Phase 4 — Test

1. Use **write-tests**: every acceptance criterion maps to at least one test; include error and
   permission paths.
2. Run the project's test, lint and type-check commands from project-context.
3. If performance-sensitive (lists, reports), check query counts (**database-optimization**).

**Exit criteria:** new and existing relevant tests pass; failures are fixed, not skipped.

## Phase 5 — Review

1. Run **code-review** on your own diff (`git diff` against the base branch).
2. Fix all blockers and majors; list remaining minors as follow-ups.
3. Re-run tests after fixes.

**Exit criteria:** self-review verdict is "Approve" or "Approve with comments".

## Phase 6 — Hand-off

Report in this format:

```markdown
## Feature: <name>
**Status:** Ready for review | Partially done (reason)

### Acceptance criteria
- [x] <criterion> — covered by `tests/...::test_name`

### Changes
- `path/file.py` — <what and why>

### Decisions
- <decision> — <reason, alternatives considered>

### Verification
- `<test command>` → <result>
- `<lint/type command>` → <result>

### Manual steps for humans
- <migrations to apply, env vars, feature flags, deploy notes>

### Follow-ups / limitations
- <item>
```

Never commit, push, merge or deploy unless the user explicitly asks.
