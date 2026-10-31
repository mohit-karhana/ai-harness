<!-- User-owned file: created once by ai-harness setup and never overwritten by the harness updater. Keep it accurate; AI assistants read it before every task. -->
# Project Context

<!-- Guidance: text inside HTML comments is a hint for humans and AI. Replace the hints with real
     project information. Keep it concise and factual — this file is loaded into the AI's context
     on every task, so prefer bullet points over prose. Never put secrets, credentials, connection
     strings or customer data in this file. -->

## Project Name

{{PROJECT_NAME}}

<!-- One sentence on what the product does and who uses it. -->

## Technology

{{TECHNOLOGY}}

<!-- Correct/extend the detected stack with versions, e.g. "Python 3.12, Django 5.1, DRF 3.15,
     PostgreSQL 16, Redis 7, Celery 5, React 18 + TypeScript, Vite". -->

## Architecture

<!-- Describe the existing architecture so the AI does not have to guess:
     - Monolith / services, how the repo is laid out (e.g. backend/, frontend/, infra/)
     - Layering rules (e.g. views → services → models; no business logic in views/serializers)
     - Async processing (Celery queues, cron jobs), caching, external integrations
     - Multi-tenancy model and how tenant isolation is enforced
     - Authentication/authorization approach -->

## Important Modules

<!-- List the modules/directories that matter most and what they own, e.g.:
     - `apps/policies/` — policy lifecycle, premium calculation (business-critical)
     - `apps/claims/` — claims intake and adjudication
     - `core/permissions.py` — shared permission classes; use these, do not write new ones
     - `frontend/src/api/` — typed API client; all HTTP calls go through here -->

## Development Commands

<!-- Replace with the real commands. The AI uses these instead of guessing. -->

```bash
# Install dependencies
# e.g. pip install -r requirements/dev.txt   |   npm ci

# Run the application locally
# e.g. python manage.py runserver   |   uvicorn app.main:app --reload   |   npm run dev

# Run all tests
# e.g. pytest -q   |   python manage.py test   |   npm test

# Run a single test file / test
# e.g. pytest tests/test_orders.py::test_create_order -vv   |   npx vitest run src/x.test.tsx

# Lint and type-check
# e.g. ruff check . && mypy .   |   npm run lint && npx tsc --noEmit

# Format
# e.g. ruff format .   |   npx prettier --write .

# Database migrations (local only)
# e.g. python manage.py makemigrations && python manage.py migrate   |   alembic upgrade head
```

## Environments & Data Access

<!-- List environments and how they are used, e.g.:
     - local: docker compose up; seeded with `python manage.py seed_demo` (synthetic data)
     - staging: deployed from main by CI; shared — ask before changing anything
     - production: deployed by release managers only -->

- The AI must **never** access production systems, production databases or production logs,
  and must never request or use real customer data. Use local/synthetic data only.
- Changes to shared environments (staging, shared dev) require explicit human approval.

## Important Rules

<!-- Project-specific coding and business rules the AI must follow, e.g.:
     - Money is stored as integer paise/cents; never use float for amounts
     - All dates stored in UTC; display in Asia/Kolkata
     - Every model change needs a migration reviewed by the backend lead
     - Public API v1 is frozen; add new fields only in v2
     - Audit log entry required for any change to policy or claim status -->

## Domain Glossary

<!-- Business terms and their meaning in code, e.g.:
     - Policy holder — `Customer` model
     - Sum insured — `Policy.coverage_amount` (integer, paise)
     - Endorsement — a change to an active policy; see `apps/policies/endorsements.py` -->

## Known Pitfalls / Gotchas

<!-- Things that commonly trip people (and AI) up, e.g.:
     - `Order.save()` triggers a signal that sends emails — use `update()` for bulk changes
     - Tests require Redis running (`docker compose up redis`)
     - Legacy module `apps/legacy_billing/` is scheduled for removal; do not extend it -->

## Precedence

This file and other project-specific instructions **override** company-wide defaults from
`.ai-harness/` where they conflict (architecture, conventions, commands, business rules).
They **cannot** relax company security rules, data-protection rules, or the requirement to ask for
human approval before destructive, production or risky database operations.
