---
description: API design standards for REST resources, versioning, errors, pagination, idempotency, auth and documentation.
globs: **/views.py,**/viewsets.py,**/serializers.py,**/urls.py,**/routers/**,**/routes/**,**/api/**,**/controllers/**
alwaysApply: false
---
# API Development Standards

## Before you build
- Find an existing endpoint of the same kind and mirror its structure, auth, error
  handling, pagination and tests.
- Confirm the contract (request/response shapes, status codes, auth) before
  implementing; for public/partner APIs write it down first (OpenAPI or spec).

## Resource design
- Plural nouns, kebab-case paths, no verbs: `GET /v1/policies/{policy_id}/claims`.
- Use HTTP methods semantically: `GET` (safe), `POST` (create/action), `PUT` (full
  replace), `PATCH` (partial), `DELETE`.
- Non-CRUD actions as sub-resources: `POST /v1/claims/{id}/approve`.
- Use opaque, non-sequential public identifiers (UUIDs) for externally exposed IDs.
- JSON field casing follows the existing API (snake_case or camelCase) consistently.

## Versioning and compatibility
- Version in the URL (`/v1/`) or as the project already does.
- Allowed without a new version: adding endpoints, optional request fields, response
  fields. Breaking (needs new version + deprecation period): removing/renaming fields,
  changing types/semantics, making optional fields required, changing status codes.
- Announce deprecations (docs + `Deprecation`/`Sunset` headers where used).

## Status codes
- 200 OK, 201 Created (+ `Location`), 202 Accepted (async), 204 No Content.
- 400 malformed, 401 unauthenticated, 403 authenticated but not allowed, 404 not found
  (also for objects the caller must not know exist), 409 conflict/state violation,
  422 validation error, 429 rate limited.
- 5xx only for server faults; never return 200 with an error body.

## Error envelope
Use the project's existing error format; if none exists, use:
```json
{
  "error": {
    "code": "CLAIM_POLICY_LAPSED",
    "message": "Claims cannot be filed on a lapsed policy.",
    "details": [{"field": "policy_id", "issue": "policy is lapsed"}],
    "request_id": "c0a8012e-..."
  }
}
```
- Stable machine-readable `code`; human `message` without internals (no stack traces,
  SQL, hostnames, other users' data).

## Validation
- Validate every input (body, query, path, headers) with schemas/serializers: types,
  ranges, lengths, formats, enums. Reject unknown fields for write endpoints when the
  framework supports it.
- Normalize inputs (trim, case) deliberately and consistently.

## Authentication and authorization
- Every endpoint is authenticated unless explicitly documented as public.
- Authorize per object: verify the caller owns/may access the resource (tenant,
  policyholder, broker, role). Scope queries by the caller rather than filtering after.
- Never accept user IDs/roles from the request body to decide permissions.
- Return 404 instead of 403 when revealing existence would leak information.

## Pagination, filtering, sorting
- All list endpoints are paginated with a max page size (e.g. 100).
- Prefer cursor pagination for large or frequently changing collections.
- Whitelist filter and sort fields; never pass raw user input into ORM `order_by`/filters.

## Idempotency and reliability
- Accept an `Idempotency-Key` header for `POST` endpoints that create payments,
  policies, claims or send communications; store and replay the result.
- Webhook consumers verify signatures, are idempotent, and respond quickly (queue work).
- Set timeouts and retries with backoff for outbound calls; use circuit breakers where
  the project has them.

## Rate limiting and abuse
- Rate-limit authentication, OTP, quote and search endpoints.
- Limit request body size and file uploads.

## Data exposure
- Response serializers list fields explicitly; never serialize whole models.
- Mask sensitive fields (ID numbers, bank details, medical data) unless the endpoint's
  purpose requires them and the caller is authorized.

## Documentation and testing
- Update OpenAPI/Swagger docs: summary, params, request/response examples, errors.
- Tests per endpoint: success, validation error, unauthenticated, forbidden/other
  tenant, not found, and conflict/state rules. Assert response shape and status code.
