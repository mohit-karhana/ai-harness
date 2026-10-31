---
name: create-api
description: Design and implement a new API endpoint (REST or RPC) that matches the project's existing API conventions, with validation, auth, error handling, tests and docs. Use when the user asks to add, expose or create an endpoint, route, view, serializer, controller or API resource.
---

# Create API

## Purpose

Add a production-quality API endpoint that looks like it was written by the team that owns the
codebase: same routing style, same auth, same error envelope, same pagination, same test layout.
The endpoint must validate every input, enforce authorization, return stable response shapes and
ship with tests.

## When to use

- "Add an endpoint / route / API for ..."
- "Expose X over the API", "create a CRUD API for model Y"
- Adding a new action to an existing resource (e.g. `POST /orders/{id}/cancel`)

### When NOT to use

- Changing the behaviour of an existing endpoint used by clients → treat as a breaking-change
  discussion first, then use `refactor-code` or `implement-feature`.
- Pure frontend work that only *consumes* an API → use `implement-feature`.
- Performance problems in an existing endpoint → use `database-optimization`.

## Required context

Read before writing any code:

1. `.ai-harness/project-context.md` — architecture, commands, project rules (takes precedence).
2. `.ai-harness/instructions/api-development.md`, `security.md`, `testing.md`, plus the stack file
   (`django.md`, `fastapi.md`, `javascript.md`) and `database.md` if a model changes.
3. Two or three **existing endpoints** that are closest to the new one (same app/module). Note:
   URL naming, versioning (`/api/v1/`), auth/permission classes or dependencies, serializer/schema
   style, error format, pagination, filtering, logging.
4. The existing tests for those endpoints — copy their structure and fixtures.

Ask the user if any of these are unknown: who may call the endpoint (roles/tenancy), expected
request/response shape, idempotency needs, rate limits, and whether the API is public or internal.

## Steps

1. **Inspect.** Locate the routing entry point (`urls.py` / `APIRouter` / `express.Router()`),
   the closest existing endpoints and their tests. Do not assume a structure — confirm it.
2. **Plan.** Write a short plan and show it to the user before implementing when the endpoint is
   non-trivial:
   - Method + path, request schema, response schema, status codes (200/201/204/400/401/403/404/409/422).
   - AuthN/AuthZ rule, including object-level/tenant checks.
   - Data access (queries, transactions) and side effects (emails, events, jobs).
   - Files to add/modify, and any migration.
3. **Approval checkpoint.** If a database migration, a change to an existing public contract, or a
   new external dependency is required — **stop and ask for approval**.
4. **Implement**, following the project's patterns. Stack hints (use only if the project already
   works this way):
   - **Django/DRF:** `Serializer`/`ModelSerializer` for validation, `ViewSet` or `APIView` with explicit
     `permission_classes`, `get_queryset()` scoped to the requesting user/tenant, `select_related`/
     `prefetch_related` for nested data, register in the router or `urls.py`.
   - **FastAPI:** Pydantic request/response models (`response_model=`), dependencies for auth
     (`Depends(get_current_user)`) and DB sessions, `HTTPException` with the project's error shape,
     `status_code=` on the decorator, router included in the app.
   - **Node/Express:** validate with the project's validator (zod/joi/express-validator), auth
     middleware on the route, `async` handlers with the project's error-forwarding pattern
     (`next(err)` or wrapper), never leak stack traces in responses.
   - Validate and normalise all input; reject unknown fields if the project does.
   - Never return internal fields (password hashes, tokens, internal IDs the API does not expose).
   - Wrap multi-write operations in a transaction; make retries safe (idempotency key) where needed.
   - Log meaningful events without logging secrets or PII.
5. **Test** (use the `write-tests` skill). Minimum:
   - Happy path with response shape assertion.
   - Validation errors (missing/invalid fields) → 400/422.
   - Unauthenticated → 401; authenticated but forbidden / other tenant's object → 403/404.
   - Not found, conflict/duplicate where relevant.
   - Query count assertion for list endpoints (e.g. `assertNumQueries` in Django).
   Run with the project's test command from project-context (e.g. `pytest path/to/test_x.py`,
   `python manage.py test app`, `npm test -- route.test.ts`).
6. **Document.** Update OpenAPI/schema annotations, API docs or the changelog the way the project
   already does. FastAPI/DRF-spectacular generate schemas — check they render correctly.
7. **Review** your diff with the `code-review` skill checklist before handing off.

## Expected output

- Summary of the endpoint: method, path, auth rule, request/response example (JSON).
- List of files created/modified with one-line reasons.
- Test command run and its result (pass/fail counts). If tests could not be run, say so and why.
- Important decisions (e.g. 404 vs 403 for foreign objects, pagination choice) and any follow-ups
  (migration to apply, client update, feature flag).

## Validation checklist

- [ ] Matches existing URL, naming, versioning and error-format conventions
- [ ] Every input validated; unknown/oversized input handled
- [ ] Authentication required unless explicitly public; object-level/tenant authorization enforced
- [ ] No secrets, tokens or unnecessary PII in responses or logs
- [ ] Correct status codes for success and each error path
- [ ] No N+1 queries; list endpoints paginated
- [ ] Writes are transactional; side effects happen after commit where the project does so
- [ ] Backward compatible with existing clients (no renamed/removed fields)
- [ ] Tests cover happy path, validation, authz, not-found; all tests pass
- [ ] API docs / schema updated
- [ ] Migration (if any) reviewed and approved by the user
