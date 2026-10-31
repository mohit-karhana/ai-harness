<!-- User-owned file. The ai-harness updater never overwrites it. -->
# Project Context

## Project Name
Healthysure Policies Service (example)

## Technology
Python 3.12, Django 4.2, Django REST Framework, PostgreSQL 16, Redis, Celery

## Architecture
Monolithic Django service exposing a versioned REST API under `/api/v1/`.
Views are thin DRF viewsets; validation lives in serializers and business
rules in `policies/services/`. Celery workers handle renewals and reminders.

## Important Modules
- `config/`: settings (env-driven), root URLs.
- `policies/models.py`: `Customer`, `Policy` (status lifecycle draft → active → lapsed).
- `policies/serializers.py`: API contracts and validation.
- `policies/views.py`: read-only policy API.

## Development Commands
```bash
pip install -r requirements.txt
python manage.py runserver          # run the API locally
pytest                              # run tests
python manage.py makemigrations     # create migrations (review before committing)
```

## Environments & Data Access
local (docker compose), staging, production. The AI must never connect to
staging or production databases and must never use real customer data.

## Important Rules
- Customer PII (name, email) must never appear in logs.
- `Policy.policy_number` is immutable once a policy is active.
- Money is always `Decimal`, rounded with `ROUND_HALF_UP`.
