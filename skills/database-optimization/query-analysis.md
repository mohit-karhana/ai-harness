# Query Analysis Reference

## 1. Reading PostgreSQL EXPLAIN

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT ... ;
```

`ANALYZE` executes the statement. For `INSERT/UPDATE/DELETE` wrap it:
`BEGIN; EXPLAIN ANALYZE ...; ROLLBACK;` — and never do this on production.

Read the plan **inside-out, bottom-up**; each node shows
`(cost=startup..total rows=estimated width=bytes) (actual time=first..last rows=actual loops=N)`.

| Signal | Meaning | Typical fix |
|---|---|---|
| `Seq Scan` on a large table with a selective `Filter` | No usable index | Index on the filtered column(s) |
| `Rows Removed by Filter` ≫ rows returned | Scanning far more than needed | Index or more selective predicate |
| Estimated `rows` off by 10×+ from actual | Stale/insufficient statistics | `ANALYZE table`; extended statistics for correlated columns |
| `Nested Loop` with high `loops=` on inner side | Per-row lookups (often ORM N+1 in SQL form) | Index on join key, or hash join via better estimates |
| `Sort` with `external merge Disk:` | Sort spilled to disk | Index matching `ORDER BY`, or reduce rows, `work_mem` (DBA decision) |
| `Bitmap Heap Scan` with many `Recheck` / lossy blocks | Many matching rows | Fine for medium selectivity; consider covering index |
| `Index Scan` but high `Buffers: shared read` | Data not cached, random I/O | Covering index (`INCLUDE`), `Index Only Scan`, cluster/partition |
| `Limit` above a big `Sort` | Sorting everything to return few rows | Index on `ORDER BY` columns (+ filter columns first) |

Also check `pg_stat_statements` (human-provided) for `total_exec_time` and `calls` — a fast query
called 100k times can matter more than one slow query.

## 2. Detecting N+1 in Django

- **django-debug-toolbar** (dev only): SQL panel shows duplicated/similar queries per request.
- **Tests:**
  ```python
  def test_order_list_query_count(self):
      OrderFactory.create_batch(20, items=3)
      with self.assertNumQueries(4):
          self.client.get("/api/orders/")
  ```
  pytest-django: `django_assert_num_queries(4)` / `django_assert_max_num_queries(6)`.
- **Ad-hoc:**
  ```python
  from django.db import connection
  from django.test.utils import CaptureQueriesContext
  with CaptureQueriesContext(connection) as ctx:
      list(serializer.data)
  print(len(ctx.captured_queries))
  ```
- Usual culprits: serializer fields traversing relations (`source="customer.name"`),
  `SerializerMethodField` running queries, `__str__` touching FKs in admin, `.count()` in loops.
- Fixes: `select_related("customer")`, `prefetch_related(Prefetch("items", queryset=Item.objects.only(...)))`,
  `annotate(item_count=Count("items"))`. Put them in `get_queryset()` so every action benefits.

## 3. SQLAlchemy

- Log SQL: `create_engine(url, echo=True)` locally, or an `before_cursor_execute` event listener
  that counts statements in tests.
- Eager loading: `select(Order).options(selectinload(Order.items), joinedload(Order.customer))`.
  Use `selectinload` for collections, `joinedload` for many-to-one.
- `raiseload("*")` in tests to make accidental lazy loads fail loudly.
- Async sessions cannot lazy-load — missing eager loads surface as `MissingGreenlet` errors.

## 4. Node ORMs

- Prisma: `log: ["query"]`; use `include`/`select`; avoid per-item `findUnique` in loops — use
  `findMany({ where: { id: { in: ids } } })`.
- Sequelize/TypeORM: `include`/`relations`; enable `logging`. GraphQL: DataLoader per request.

## 5. Index design

1. Index for the **query**, not the column: take the `WHERE` equality columns first, then range
   columns, then `ORDER BY` columns: `(tenant_id, status, created_at DESC)`.
2. Leftmost-prefix rule: `(a, b, c)` serves `a`, `a,b`, `a,b,c` — not `b` alone.
3. Partial indexes for hot subsets: `CREATE INDEX ... WHERE status = 'pending'`.
4. Covering indexes (`INCLUDE (col)`) enable index-only scans for read-heavy paths.
5. Expression indexes for `lower(email)` or JSONB keys; GIN for JSONB containment/full-text/arrays.
6. Every index slows writes and uses disk — check for duplicates/unused indexes
   (`pg_stat_user_indexes.idx_scan = 0`, human-provided) before adding more.
7. Low-cardinality columns alone (booleans) rarely deserve an index — combine or use partial.

## 6. Safe migrations on large tables (PostgreSQL)

- Indexes: `CREATE INDEX CONCURRENTLY` (Django `AddIndexConcurrently`, migration `atomic = False`).
- New column: add nullable without default (or with constant default on PG 11+), backfill in
  batches, then add `NOT NULL` via `CHECK ... NOT VALID` + `VALIDATE CONSTRAINT`.
- Foreign keys: add `NOT VALID`, then `VALIDATE` separately.
- Never rename/drop columns still read by running code — expand, migrate, contract over releases.
- Set `lock_timeout` for migrations so they fail fast instead of blocking traffic.
