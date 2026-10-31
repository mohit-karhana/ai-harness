---
name: implement-feature
description: Implement a new feature end to end — clarify requirements, inspect the existing architecture, plan, implement in small steps, test and self-review — following company and project standards. Use when the user asks to build, add or implement a feature, user story, ticket or spec that spans more than a trivial edit.
---

# Implement Feature

## Purpose

Deliver a feature that fits the existing architecture, meets explicit acceptance criteria, is
covered by tests and is safe to release. The AI inspects and plans before writing code, and
pauses for human approval at the points where mistakes are expensive.

## When to use

- "Implement / build / add <feature>", a ticket, user story or a spec from
  `.ai-harness/templates/feature-specification.md`
- Changes that touch several layers (model + API + UI) or several modules

### When NOT to use

- A single new endpoint only → `create-api`.
- A bug → `debug-issue`. Pure restructuring → `refactor-code`.
- Tiny edits (copy change, one-line config) — just make the change and test it.

## Required context

1. `.ai-harness/project-context.md` — architecture, modules, commands, business rules.
2. `.ai-harness/instructions/general.md`, `security.md`, `testing.md`, plus every stack file that
   matches the layers touched (`django.md`, `fastapi.md`, `react.md`, `database.md`, ...).
3. The requirement: ticket/spec text with acceptance criteria. If there are none, draft them and
   confirm with the user.
4. The existing code of the area: entry points, similar features already implemented (use them as
   the template), models, services, tests, feature-flag mechanism.
5. Unknowns to ask about: target users/roles, edge cases, data volume, rollout (flag? migration?),
   analytics/audit needs, deadlines that affect scope.

## Steps

1. **Clarify.** Restate the feature as acceptance criteria (Given/When/Then or bullet list). List
   assumptions and open questions. Ask the user to resolve blocking questions before coding.
2. **Inspect.** Map how a similar existing feature flows through the system (route → view/handler →
   service → model → template/component → tests). Note conventions to follow. Never assume
   structure; confirm by reading files.
3. **Plan.** Produce a concise plan:
   - Components to add/change per layer, with file paths.
   - Data model changes and migration strategy (expand/contract for live tables).
   - API contract changes (new fields only; no breaking changes without approval).
   - Security: authz rules, input validation, PII handling.
   - Test plan (unit, integration, UI) and rollout (feature flag, config, backfill).
4. **Approval checkpoint — stop and ask** for confirmation of the plan when the feature is
   non-trivial, and always before: migrations, new dependencies, breaking API changes, changes to
   auth/payments/PII handling, or deleting/rewriting existing modules.
5. **Implement incrementally**, bottom-up, keeping the code runnable after each step:
   data model → domain/service logic → API (use `create-api` for endpoints) → UI → wiring/config.
   - Reuse existing utilities, base classes, components and hooks instead of creating parallel ones.
   - Validate inputs at boundaries; handle errors explicitly; keep functions small and typed.
   - Backend hints: Django services/managers as the project uses them, DRF serializers, Celery
     tasks scheduled with `transaction.on_commit`; FastAPI routers + Pydantic schemas + service layer.
   - Frontend hints (React): follow the existing state/data-fetching approach (React Query, Redux,
     context), co-locate component tests, handle loading/empty/error states, accessible markup.
6. **Test** with the `write-tests` skill: every acceptance criterion maps to at least one test.
   Run the project's test, lint and type-check commands from project-context.
7. **Self-review** with the `code-review` skill and fix blockers/majors before reporting.
8. **Document**: update README/API docs/changelog/env var examples as the project does; fill in or
   update the feature spec if one exists.

## Expected output

- Acceptance criteria and how each is satisfied (with test names).
- Summary of the design and important decisions (alternatives considered, trade-offs).
- Files added/changed grouped by layer.
- Commands run (tests, lint, type check) and results.
- Required manual steps: migrations to apply, env vars to set, flags to enable — none executed
  against shared/production environments by the AI.
- Known limitations and follow-ups.

## Validation checklist

- [ ] Acceptance criteria explicit and agreed; each covered by a test
- [ ] Existing architecture and conventions followed; no parallel abstractions introduced
- [ ] Plan approved for non-trivial work; migrations/dependencies/breaking changes approved
- [ ] Inputs validated, authz enforced, errors handled, no secrets/PII leaked
- [ ] Backward compatible (API, DB during rolling deploy, events)
- [ ] Tests, linters, type checks pass
- [ ] Self-review done; docs and examples updated
- [ ] Rollout and rollback steps described
