---
description: Company-approved technology stack (Django or FastAPI back ends, React + TypeScript front ends) and the rules for introducing anything else.
globs:
alwaysApply: true
---
# Approved Technology Stack

The company standard stack is **Python on the back end (Django or FastAPI)**
and **React + TypeScript on the front end**, with PostgreSQL and Redis.
Use it for all new code. In an existing project, its established choices win
(see `.ai-harness/project-context.md`). Do not migrate a project to the
approved stack as a side effect of another task.

## Back end

| Concern | Approved |
|---------|----------|
| Language | Python 3.12+ |
| Framework | **Django 5.2 LTS + Django REST Framework**, or **FastAPI** (see "Choosing" below) |
| Database | PostgreSQL |
| Cache / broker | Redis |
| Background jobs | Celery (both frameworks); FastAPI `BackgroundTasks` only for short, losable work |
| Django extras | django-filter, drf-spectacular (OpenAPI), django-environ or env-based settings |
| FastAPI extras | Pydantic v2, pydantic-settings, SQLAlchemy 2.x (async, asyncpg), Alembic, Uvicorn/Gunicorn |
| HTTP client | httpx (with timeouts) |
| Tests | pytest, pytest-django / httpx `AsyncClient`, factory_boy, Faker |
| Quality | ruff (lint + format), mypy where the project already uses it |

Django 4.2 LTS reached end of support in April 2026. Do not start new work on
it. Flag any project still on it as an upgrade follow-up instead of upgrading
it inside an unrelated task.

### Choosing between Django and FastAPI

| Choose **Django + DRF** when | Choose **FastAPI** when |
|------------------------------|-------------------------|
| The service owns core business data (policies, customers, claims) | It is a focused service: integrations, webhooks, gateways, ML/pricing model serving |
| You need the admin site, built-in auth/permissions, or many CRUD resources | High concurrency or I/O-heavy async work is the main requirement |
| Background jobs and complex relational models dominate | The service is small, stateless or read-heavy, with a narrow API |

- Never mix both frameworks in one service. Extend whichever the project uses.
- Choosing the framework for a **new** service is an architecture decision.
  Propose it with the reasons above and wait for human approval.

## Front end

| Concern | Approved |
|---------|----------|
| Language | TypeScript, `strict: true` |
| Framework | React (function components + hooks) with Vite |
| Routing | React Router |
| Server data | TanStack Query (React Query) |
| Forms / validation | React Hook Form + Zod |
| API client | Generated from the back end's OpenAPI schema (`openapi-typescript` or `orval`) |
| Tests | Vitest + Testing Library; Playwright for end-to-end |
| Quality | ESLint + Prettier |
| Styling | Keep whatever the project already uses; ask before introducing a new approach |

Existing projects keep their established libraries (for example SWR or Redux)
until a planned migration replaces them.

## Contract between front end and back end

- The back end's **OpenAPI schema is the contract**: drf-spectacular for Django,
  the built-in schema for FastAPI. Keep it accurate and backward compatible.
- The front end uses a typed client **generated** from that schema. Don't
  hand-write request/response types that the schema already describes.
- When you change an endpoint, regenerate the client in the same change, or
  call out that the front end must be regenerated.
- Both frameworks return the company error envelope and pagination format
  from `api-development.md`.
- Authentication goes through the company identity provider (OIDC/JWT).
  Never build ad-hoc auth or session schemes.

## Introducing anything else

Each of the following needs explicit human approval (from a tech lead or an
architecture review) before you add it. Explain why the approved stack is
not enough:

- A new language or runtime (Node.js server, Go, Java, …) or web framework
  (Flask, Express, NestJS, Next.js server features, …).
- A new datastore (MongoDB, DynamoDB, Elasticsearch, …) or message broker.
- GraphQL, gRPC, or WebSockets where REST is the norm.
- A new front-end state, styling or component library.
- Any dependency that duplicates something already installed.

If a task seems to need a non-approved technology, stop and propose options.
Do not add it on your own initiative.
