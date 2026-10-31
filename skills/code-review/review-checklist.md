# Code Review Checklist

Use as a thinking aid, not a form to fill in. Skip categories that do not apply to the diff.

## 1. Correctness

- [ ] The change does what the ticket/spec says — including edge cases in the acceptance criteria
- [ ] Null/None/undefined, empty collections, zero, negative numbers, very large inputs handled
- [ ] Off-by-one, boundary and timezone issues (naive vs aware datetimes, DST, UTC storage)
- [ ] Error paths: exceptions are caught at the right level, not swallowed (`except Exception: pass`)
- [ ] Return types and shapes are consistent on all branches
- [ ] Concurrency: race conditions on read-modify-write (use `select_for_update`, atomic updates,
      unique constraints, optimistic locking); idempotency of retried jobs/webhooks
- [ ] Transactions: multi-write operations atomic; side effects (emails, events, tasks) run after
      commit (`transaction.on_commit`) where the project does so
- [ ] Async code: no blocking I/O in async handlers; promises awaited; no unhandled rejections
- [ ] React: hooks rules respected, effect dependencies correct, no state updates after unmount,
      keys stable in lists

## 2. Security

- [ ] AuthN required on new endpoints/pages unless intentionally public
- [ ] AuthZ: object-level and tenant checks (no IDOR — user A cannot access user B's object by ID)
- [ ] All external input validated (body, query, headers, files, webhooks)
- [ ] No SQL built by string concatenation; raw SQL uses parameters
- [ ] No `eval`, unsafe deserialization (`pickle`, `yaml.load`), shell injection (`shell=True`)
- [ ] Output encoding: no `dangerouslySetInnerHTML`/`|safe`/`mark_safe` on user data
- [ ] Secrets not hard-coded, not logged, not returned; config read from env/secret manager
- [ ] PII minimised in logs, analytics and error reports
- [ ] File uploads: type/size validated, stored outside web root, names sanitised
- [ ] SSRF/redirects: outbound URLs and redirect targets validated against allow-lists
- [ ] New dependencies: maintained, licensed acceptably, no known CVEs, pinned

## 3. Data & migrations

- [ ] Migration is reversible or has a documented rollback
- [ ] Safe on large tables: no long locks (add nullable column, backfill in batches, then constrain)
- [ ] Indexes created concurrently where the DB supports it (`AddIndexConcurrently`, `CREATE INDEX CONCURRENTLY`)
- [ ] Data migrations separated from schema migrations; idempotent
- [ ] Code is compatible with both old and new schema during rolling deploys
- [ ] Constraints (unique, FK, not-null, check) enforce invariants in the DB, not only in code

## 4. API & backward compatibility

- [ ] No removed/renamed fields, endpoints, enum values or changed types without versioning
- [ ] New required request fields have defaults or a deprecation path
- [ ] Status codes and error envelope match project conventions
- [ ] Events/messages/queue payload schemas remain compatible with consumers
- [ ] Feature flag for risky behaviour changes

## 5. Performance

- [ ] No N+1 queries (`select_related`/`prefetch_related`, joins, DataLoader)
- [ ] List endpoints paginated; no unbounded queries or in-memory loads of whole tables
- [ ] Queries filter on indexed columns; new filters have indexes where needed
- [ ] Expensive work moved to background jobs; caching invalidated correctly
- [ ] Frontend: no unnecessary re-renders of large lists; bundle size impact of new deps

## 6. Tests

- [ ] New logic has unit tests; integration tests for API/DB boundaries
- [ ] Bug fixes include a regression test that failed before the fix
- [ ] Tests assert behaviour, not implementation details; no sleeping/time-dependent flakiness
- [ ] Error and permission paths tested, not only the happy path
- [ ] Tests use factories/fixtures, never real customer data or real external services

## 7. Readability & maintainability

- [ ] Follows existing project conventions (structure, naming, patterns) over personal preference
- [ ] Functions small and single-purpose; no deep nesting; no dead code or commented-out code
- [ ] Names reveal intent; magic numbers extracted to named constants
- [ ] No duplication of existing utilities — reuse what the project already has
- [ ] Comments explain *why*, not *what*; TODOs reference a ticket
- [ ] Type hints / TypeScript types accurate (no `any` without reason)

## 8. Docs & operations

- [ ] README/API docs/changelog updated when behaviour or setup changes
- [ ] New env vars documented and added to example config (without real values)
- [ ] Logging/metrics sufficient to operate the feature; alerts considered for critical paths
