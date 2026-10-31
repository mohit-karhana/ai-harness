---
name: database-optimization
description: Diagnose and fix slow database access — N+1 queries, missing indexes, inefficient ORM usage, heavy migrations — using measurements (EXPLAIN, query counts) before and after. Use when the user reports slow endpoints, slow queries, high DB load, timeouts, or asks to optimize queries or add indexes.
---

# Database Optimization

## Purpose

Make data access measurably faster without changing behaviour: find the expensive queries,
understand *why* they are expensive, apply the smallest effective fix (query shape, ORM
prefetching, index, caching), and prove the improvement with before/after numbers.

## When to use

- "This endpoint/page/report is slow", timeouts, high DB CPU, lock contention
- "Optimize this query", "add an index", "fix N+1"
- Reviewing a migration on a large table for locking/downtime risk

### When NOT to use

- The slowness is not in the database (CPU-bound code, external API) — measure first; if the DB
  is not the bottleneck, report that and switch to `debug-issue`/`refactor-code`.
- Schema redesigns — write a spec with `implement-feature` and get approval.

## Required context

1. `.ai-harness/project-context.md` — DB engine/version, table sizes if known, environments.
2. `.ai-harness/instructions/database.md` and the stack file (`django.md`, `fastapi.md`, ...).
3. The slow code path (view/handler/serializer/repository) and the models involved.
4. Evidence: slow query log entry, APM trace, `pg_stat_statements` output **provided by a human**,
   or a local reproduction. Approximate production row counts help — ask for them.
5. Read [query-analysis.md](query-analysis.md) for EXPLAIN, N+1 detection and index design.

**Safety:** do not connect to production databases. Do not run `EXPLAIN ANALYZE` on production for
write statements (it executes them). Ask a human with access to run read-only diagnostics there
and share sanitized output.

## Steps

1. **Measure the baseline** locally or on staging with realistic data volume:
   - Query count and total DB time per request (django-debug-toolbar, `assertNumQueries`,
     `CaptureQueriesContext`, SQLAlchemy `echo=True` / event listeners, Prisma/knex query logs).
   - `EXPLAIN (ANALYZE, BUFFERS)` for the heaviest SELECTs (PostgreSQL), `EXPLAIN ANALYZE` (MySQL 8).
2. **Classify the problem:**
   - N+1 / chatty access → prefetching or joins.
   - Sequential scan on large table with selective filter → index.
   - Fetching too much → `only()`/`values()`/explicit column lists, pagination.
   - Expensive aggregation recomputed per request → denormalised column, materialised view, cache.
   - Lock contention / long transactions → shorter transactions, `SKIP LOCKED` queues, batching.
3. **Plan the fix** and present it with the evidence. Prefer, in order: query shape fixes → ORM
   prefetching → indexes → caching → schema changes.
4. **Approval checkpoint — stop and ask** before: adding/removing indexes on large tables, any
   migration, schema/denormalisation changes, cache invalidation strategy changes, or anything run
   against shared or production databases.
5. **Implement:**
   - Django: `select_related` (FK/one-to-one), `prefetch_related` + `Prefetch(queryset=...)`,
     `annotate`/`Subquery`/`Exists` instead of Python loops, `bulk_create`/`bulk_update`/`update()`,
     `iterator(chunk_size=...)` for large scans, `Meta.indexes` with `AddIndexConcurrently` in an
     `atomic = False` migration on PostgreSQL.
   - SQLAlchemy: `selectinload`/`joinedload`, `load_only`, Core for bulk ops, Alembic
     `op.create_index(..., postgresql_concurrently=True)` outside a transaction.
   - Node ORMs: `include`/`with` relations, batched loaders (DataLoader), raw parameterised SQL
     only when the ORM cannot express it.
6. **Re-measure** with the same method; record query count, time and plan before/after.
7. **Test** behaviour unchanged (existing tests pass) and add a query-count regression test where
   the project supports it (`assertNumQueries`, `django_assert_max_num_queries`).
8. **Review** with the `code-review` skill, paying attention to migration safety.

## Expected output

- Diagnosis: the slow query/path, the plan node or pattern responsible, with evidence.
- Fix and rationale; migration details (locking behaviour, estimated build time, rollback).
- Before/after metrics table (query count, DB time, plan type, rows scanned).
- Tests run and results; follow-ups (e.g. monitor index usage, drop unused indexes later).

## Validation checklist

- [ ] Baseline measured before changing code; improvement measured after
- [ ] Behaviour unchanged; existing tests pass
- [ ] No production DB accessed by the AI; production diagnostics done by a human
- [ ] Indexes justified by actual query predicates/ordering; write overhead considered
- [ ] Migrations non-blocking on large tables (concurrent index, batched backfill) and reversible
- [ ] Query-count regression test added where possible
- [ ] Caching (if added) has correct invalidation and does not leak data across users/tenants
