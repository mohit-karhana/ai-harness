---
description: Django and Django REST Framework standards for models, ORM, migrations, views, tasks and settings.
globs: **/*.py,**/templates/**/*.html
alwaysApply: false
---
# Django Standards

## Project structure
- Follow the existing app layout and where business logic lives. If the project uses a
  service layer (`services.py`), put logic there; if it uses fat models/managers, follow
  that. Do not introduce a new layer without agreement.
- Keep views thin: parse input → call domain logic → serialize output.
- One concern per app; avoid circular imports between apps (use `apps.get_model` or
  move shared code into a common app).

## Models
- Every model: `__str__`, explicit `Meta.ordering` only when needed, `db_index`/
  `Meta.indexes` for fields used in filters and joins.
- Use `TextChoices`/`IntegerChoices` for enumerations.
- Money in `DecimalField(max_digits=..., decimal_places=2)`; never `FloatField`.
- Use `null=True` on string fields only when the project already does so.
- Add `created_at`/`updated_at` via the project's base model if one exists.
- Encapsulate reusable queries in custom `QuerySet`/`Manager` methods.

## ORM performance
- Prevent N+1: use `select_related` for FK/one-to-one, `prefetch_related` (with
  `Prefetch` querysets) for reverse/M2M relations.
- Use `.only()`/`.values()` for large read paths; `.exists()` instead of `count() > 0`;
  `.iterator(chunk_size=...)` for batch jobs.
- Use `bulk_create`/`bulk_update` for batches; `F()` expressions for atomic increments.
- Verify query counts in tests (`django_assert_num_queries` / `assertNumQueries`) for
  list endpoints.

```python
# Don't: one query per claim for policy and holder
for claim in Claim.objects.filter(status="open"):
    print(claim.policy.holder.id)

# Do
claims = Claim.objects.filter(status="open").select_related("policy__holder")
```

## Transactions and concurrency
- Wrap multi-write operations in `transaction.atomic()`.
- Use `select_for_update()` for read-modify-write on balances, counters, statuses.
- Trigger side effects (emails, tasks, webhooks) with `transaction.on_commit`.

## Migrations
- Generate with `makemigrations`; review the generated file; name it meaningfully.
- Never edit or delete a migration that has been applied to any shared environment.
- Keep schema and data migrations separate; data migrations use `apps.get_model` and
  provide `reverse_code` (or `RunPython.noop` with justification).
- Follow zero-downtime patterns for large tables (see `database.md`).
- **Ask before running `migrate` against any shared, staging or production database.**
  Running it against the local dev DB is fine.

## DRF / APIs
- Validate in serializers (`validate_<field>`, `validate`), not in views.
- Use explicit `fields` in serializers; never `fields = "__all__"` for models with
  sensitive data. Mark server-controlled fields `read_only`.
- Set `permission_classes` explicitly on every view; scope `get_queryset()` to the
  requesting user/tenant to prevent IDOR.
- Paginate list endpoints; use `django-filter` if the project does.
- Follow `api-development.md` for status codes and error format.

## Settings and configuration
- Read configuration from environment variables via the project's settings mechanism
  (django-environ, os.environ). Never hardcode secrets or hostnames.
- `DEBUG=False`, `ALLOWED_HOSTS`, secure cookie and CSRF settings in deployed envs.
- Never weaken `CSRF`, `SECURE_*` or password validators to make something work.

## Signals
- Use signals sparingly; prefer explicit calls in services. If used, keep handlers
  small, idempotent and documented where they're connected.

## Admin
- Register models with `list_display`, `search_fields`, `list_select_related`; use
  `raw_id_fields`/`autocomplete_fields` for large FKs.
- Mask or exclude sensitive fields (IDs, health data); restrict by permission.

## Celery / background tasks
- Tasks must be idempotent and safe to retry; pass IDs, not model instances.
- Set `max_retries`, backoff and time limits; handle `DoesNotExist` gracefully.
- Enqueue with `transaction.on_commit` when the task reads data just written.

## Templates
- Rely on auto-escaping; never use `|safe` / `mark_safe` on user-controlled content.
- Always include `{% csrf_token %}` in POST forms.

## Testing
- Use `pytest-django` or `TestCase` per project; factories for models; the DRF
  `APIClient` for endpoint tests including permission-denied cases.
