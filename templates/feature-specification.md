# Feature Specification: <feature name>

<!-- Copy this file to your project's docs (e.g. docs/specs/<feature>.md), fill it in, and pass
     its path to the /new-feature workflow. Delete hints as you go. Never include real customer
     data, secrets or production identifiers. -->

| Field | Value |
|---|---|
| Author | <name> |
| Status | Draft / In review / Approved / Implemented |
| Ticket | <link or ID> |
| Reviewers | <names> |
| Target release | <version or date> |

## Summary

<!-- 2–3 sentences: what we are building and the outcome for users. -->

## Problem

<!-- What problem exists today, who has it, and evidence (support tickets, metrics). -->

## Goals

- <!-- Measurable outcome, e.g. "Agents can issue an endorsement in under 2 minutes" -->

## Non-goals

- <!-- Explicitly out of scope, to prevent scope creep -->

## User stories

- As a <role>, I want <capability> so that <benefit>.

## Acceptance criteria

<!-- Testable statements. Each one should map to at least one automated test. -->

1. Given <context>, when <action>, then <observable result>.
2. Given <unauthorized user>, when <action>, then <403/404 and no data leaked>.
3. Given <invalid input>, when <action>, then <validation error with message>.

## API changes

<!-- New/changed endpoints with method, path, auth, request/response examples, status codes.
     Mark any breaking change explicitly and describe the versioning/deprecation path. -->

| Method | Path | Auth | Description |
|---|---|---|---|
| | | | |

```json
// Example request / response
```

## UI changes

<!-- Screens/components affected, states (loading, empty, error), accessibility notes. -->

## Data model changes & migration plan

<!-- Tables/columns/indexes added or changed. For each migration:
     - Is it backward compatible with the currently deployed code?
     - Locking risk on large tables; expected duration
     - Backfill strategy (batched? idempotent?)
     - Reversibility / rollback approach
     Use expand → migrate → contract for renames and removals. -->

## Security & privacy considerations

<!-- AuthN/AuthZ rules (including tenant/object-level), input validation, PII collected/stored/
     logged, retention, audit logging, rate limiting, third-party data sharing, threat scenarios. -->

## Dependencies & integrations

<!-- New libraries (with justification), external services, other teams' APIs, feature flags. -->

## Testing plan

<!-- Unit, integration, end-to-end and manual tests; test data (synthetic only); performance
     checks (query counts, load); how acceptance criteria are verified. -->

## Rollout & rollback

<!-- Feature flag name and default, staged rollout (internal → % of users → all), monitoring
     (metrics, dashboards, alerts), success criteria, rollback trigger and steps, data cleanup. -->

## Open questions

- [ ] <!-- Question — owner — due date -->
