# Example: FastAPI project

A minimal FastAPI claims-intake service (async SQLAlchemy 2.x, Alembic,
Pydantic v2) used to demonstrate and test the AI harness. It follows the
layout in `instructions/fastapi.md`: thin routers, Pydantic schemas, services
for business logic, and ORM models. It has no existing AI instruction files,
so setup creates `AGENTS.md`, `CLAUDE.md` and a project context from the
template.

```bash
cp -R examples/fastapi-project /tmp/fastapi-demo
./scripts/setup.sh /tmp/fastapi-demo
```
