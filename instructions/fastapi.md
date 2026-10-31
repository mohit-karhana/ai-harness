---
description: FastAPI standards for routers, Pydantic schemas, dependencies, async database access and error handling.
globs: **/*.py
alwaysApply: false
---
# FastAPI Standards

## Structure
- Follow the existing layout. Typical: `routers/` (HTTP), `schemas/` (Pydantic),
  `services/` (business logic), `repositories/` or `crud/` (data access), `core/`
  (config, security), `models/` (ORM).
- Routers stay thin: validate via schemas, call a service, return a response model.
- Group endpoints with `APIRouter(prefix="/v1/claims", tags=["claims"])`.

## Pydantic schemas
- Separate request and response models: `ClaimCreate`, `ClaimUpdate`, `ClaimRead`.
  Never return ORM objects or internal models directly.
- Always set `response_model` (or a return annotation) so sensitive fields are filtered.
- Use constrained types and validators (`Field(gt=0)`, `EmailStr`, `constr`, enums)
  instead of manual checks in handlers.
- Forbid unknown fields on inputs where the project does (`model_config =
  ConfigDict(extra="forbid")`).
- Use the Pydantic major version the project uses; don't mix v1 and v2 APIs.

```python
class ClaimCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    policy_id: UUID
    amount: Decimal = Field(gt=0, max_digits=12, decimal_places=2)
    incident_date: date

@router.post("", response_model=ClaimRead, status_code=status.HTTP_201_CREATED)
async def create_claim(
    payload: ClaimCreate,
    user: User = Depends(get_current_user),
    service: ClaimService = Depends(get_claim_service),
) -> ClaimRead:
    return await service.create(payload, actor=user)
```

## Dependency injection
- Use `Depends` for DB sessions, current user, permissions, settings and services.
- DB session dependencies use `yield` and close/rollback in `finally`.
- Enforce authorization in dependencies or services, never trust IDs from the client
  without checking ownership/tenant.
- Override dependencies in tests via `app.dependency_overrides`.

## Async vs sync
- `async def` endpoints must only use async I/O (async SQLAlchemy/asyncpg, httpx
  AsyncClient). Blocking calls inside them stall the event loop.
- If a library is sync-only, use plain `def` endpoints (run in threadpool) or
  `run_in_threadpool`.
- Set timeouts on all outbound calls; reuse clients via lifespan-managed instances.

## Errors
- Raise `HTTPException` for HTTP concerns in routers; raise domain exceptions in
  services and map them to responses with `@app.exception_handler`.
- Return the company error envelope (see `api-development.md`); never leak stack
  traces, SQL or internal IDs of other tenants.
- Customize `RequestValidationError` handling only if the project already does.

## Status codes
- 201 for creates (with resource body), 204 for deletes with no body, 202 for accepted
  async work, 409 for conflicts, 422 for validation (FastAPI default), 404 when the
  object doesn't exist *or the user may not see it*.

## Background work
- `BackgroundTasks` only for short, non-critical work (e.g. sending a notification).
  Anything that must not be lost, needs retries or is long-running goes to the
  project's task queue (Celery/RQ/Arq).
- Background work must be idempotent.

## Settings
- Use `pydantic-settings` `BaseSettings` with env vars; load once and inject via
  dependency (`get_settings` with `lru_cache`). No secrets in defaults.

## Lifespan
- Use the `lifespan` context manager (not deprecated `on_event`) for startup/shutdown
  of pools and clients.

## OpenAPI
- Provide `summary`, `description`, `tags` and response examples for public endpoints.
- Document error responses via `responses={404: {...}}`.
- Keep the generated schema backward compatible; treat it as the API contract.

## Testing
- Use `TestClient` or `httpx.AsyncClient(transport=ASGITransport(app))`.
- Test validation errors, auth failures and permission denials, not only happy paths.
