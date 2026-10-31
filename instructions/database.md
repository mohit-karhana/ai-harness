---
description: Database standards for schema design, safe migrations, indexing, query performance and data safety.
globs: **/models.py,**/models/**,**/migrations/**,**/*.sql,**/prisma/**,**/alembic/**,**/repositories/**
alwaysApply: false
---
# Database Standards

## Safety first (approval required)
- **Never run destructive SQL without explicit user approval:** `DROP`, `TRUNCATE`,
  `DELETE`/`UPDATE` without a tight `WHERE`, `ALTER` on large tables, irreversible
  migrations.
- Never connect to production or shared databases from an AI session. Work against the
  local/dev database. Ask before touching staging.
- Never paste production rows, customer data or query results containing PII into
  prompts, tickets or tests.
- Before any data fix: show the `SELECT` that identifies affected rows (count only),
  the change, a backup/rollback plan, and wrap in a transaction.

## Schema design
- Follow the existing naming conventions (table/column case, FK naming).
- Every table has a primary key; use the project's ID strategy (bigint/UUID).
- Enforce integrity in the database: `NOT NULL`, `UNIQUE`, `FOREIGN KEY`, `CHECK`
  constraints — not only in application code.
- Use proper types: `NUMERIC` for money, `TIMESTAMPTZ` for timestamps, `JSONB` only for
  genuinely schemaless data.
- Store PII/PHI only when needed; mark sensitive columns and use encryption/masking
  mechanisms the project provides.
- Prefer soft delete only where the domain requires history/audit; follow the project.

## Migrations (zero-downtime)
- Migrations must be reviewed, reversible where possible, and small.
- Separate schema migrations from data migrations.
- Never modify a migration already applied to a shared environment; add a new one.
- Expand → migrate → contract for breaking changes:
  1. Add new nullable column / new table (no default rewrite on large tables).
  2. Deploy code writing both old and new.
  3. Backfill in batches (e.g. 1–10k rows per transaction), outside the deploy migration.
  4. Add `NOT NULL` / constraints (use `NOT VALID` + `VALIDATE CONSTRAINT` in Postgres).
  5. Remove old column in a later release.
- Create indexes on large tables concurrently (`CREATE INDEX CONCURRENTLY`; in Django
  `AddIndexConcurrently` with `atomic = False`).
- Avoid long locks: no column type changes or renames on hot tables without a plan.

## Indexing
- Index columns used in `WHERE`, `JOIN`, `ORDER BY` of frequent queries; FK columns.
- Composite index column order follows selectivity and query shape (equality first,
  then range/sort).
- Don't over-index write-heavy tables; each index costs writes and storage.
- Consider partial indexes for common filters (`WHERE status = 'active'`).

## Query performance
- Measure before optimizing: `EXPLAIN (ANALYZE, BUFFERS)` on representative data in a
  non-production environment. Look for sequential scans on large tables, bad row
  estimates, nested loops over large sets.
- Eliminate N+1 queries (eager loading / joins / batching).
- Select only needed columns; avoid `SELECT *` in hot paths.
- Paginate all list queries; prefer keyset (cursor) pagination for large/real-time
  datasets over large `OFFSET`s.
- Batch writes; avoid per-row round trips in loops.
- Cache only with a clear invalidation strategy.

## Queries and injection
- Use the ORM or parameterized queries. Never interpolate user input into SQL.

```python
# Don't
db.execute(f"SELECT * FROM member WHERE email = '{email}'")
# Do
db.execute("SELECT id, status FROM member WHERE email = %s", [email])
```

## Transactions and concurrency
- Keep transactions short; no network calls inside a transaction.
- Use row locks (`SELECT ... FOR UPDATE`) or optimistic locking (version column) for
  read-modify-write on balances, claim status, counters.
- Use `ON CONFLICT`/upserts or unique constraints to make writes idempotent.
- Be aware of isolation level defaults and deadlock risks; access rows in consistent order.

## Operations
- Long-running backfills run as resumable, idempotent batch jobs with progress logging.
- Monitor slow query logs after deploying query changes.
