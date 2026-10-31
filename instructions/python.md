---
description: Python language standards for typing, style, errors, async and dependencies.
globs: **/*.py,**/*.pyi,**/pyproject.toml,**/requirements*.txt
alwaysApply: false
---
# Python Standards

## Style and tooling
- Use the formatter/linter the project already uses (check `pyproject.toml`,
  `setup.cfg`, `.pre-commit-config.yaml`): ruff, black, isort, flake8. Never mix.
- Match the project's minimum Python version; do not use syntax it doesn't support.
- Imports: stdlib, third-party, local — absolute imports preferred; no wildcard imports.
- PEP 8 naming: `snake_case` functions/vars, `PascalCase` classes, `UPPER_CASE` constants.

## Typing
- Type-annotate all new public functions, methods and module-level constants.
- Prefer precise types: `list[Policy]`, `Mapping[str, Decimal]`, `Literal["active", "lapsed"]`.
- Use `X | None` (3.10+) or `Optional[X]` per project version; never leave implicit None.
- Avoid `Any`; if unavoidable, contain it at the boundary with a comment.
- Run the project's type checker (mypy/pyright) on changed files if configured.

## Data modelling
- Use `@dataclass(frozen=True)` or the project's choice (pydantic, attrs) for value
  objects instead of dicts passed around.
- Use `Enum`/`StrEnum` for fixed sets of states.
- Use `Decimal` for money; never `float`. Quantize explicitly with a rounding mode.
- Use timezone-aware datetimes (`datetime.now(tz=UTC)` / framework `timezone.now()`).

## Functions
- No mutable default arguments.
- Keyword-only arguments (`*`) for functions with several optional params or booleans.

```python
# Don't
def add_rider(policy, riders=[], notify=True): ...

# Do
def add_rider(policy: Policy, riders: Sequence[Rider] | None = None, *, notify: bool = True) -> Policy: ...
```

## Exceptions
- Raise specific exceptions; define domain exceptions in the module's `exceptions.py`
  if the project does so (`PolicyLapsedError(DomainError)`).
- Catch the narrowest exception. Never bare `except:`; avoid `except Exception` except
  at top-level boundaries where you log and re-raise or convert.
- Chain with `raise ... from exc` to preserve context.
- Use context managers (`with`) for files, locks, connections, transactions.

## Files and paths
- Use `pathlib.Path`; never build paths with string concatenation.
- Always pass `encoding="utf-8"` when opening text files.
- Validate any user-influenced path stays within an allowed base directory.

## Logging
- `logger = logging.getLogger(__name__)` per module; no `print` in application code.
- Use lazy formatting / structured `extra`, not f-strings in log calls:
  `logger.info("claim_submitted", extra={"claim_id": claim.id})`.
- Never log PII, health data, tokens or full request bodies.

## Async
- Never call blocking I/O (requests, sync DB drivers, `time.sleep`, heavy CPU) inside
  `async def`; use async clients or `run_in_executor`/`asyncio.to_thread`.
- Always await coroutines; keep references to created tasks; handle cancellation.
- Set timeouts on every network call (`httpx.AsyncClient(timeout=...)`).
- Don't mix sync and async ORM access paths without the framework's adapters.

## Performance and correctness
- Prefer comprehensions and generators for clarity; avoid premature micro-optimisation.
- Avoid loading whole tables/files into memory; iterate or stream.
- Be explicit about equality vs identity (`is None`, `==` for values).

## Dependencies
- Add dependencies only via the project's tool (poetry, uv, pip-tools, pipenv) and
  update the lock file. Do not hand-edit lock files.
- Pin according to project policy; prefer well-maintained, permissively licensed packages.
- Run `pip-audit` (or the project equivalent) when adding/upgrading packages.

## Security reminders
- No `eval`, `exec`, `pickle.loads` or `yaml.load` on untrusted data.
- `subprocess.run([...], check=True)` with argument lists; never `shell=True` with input.
- Use `secrets` (not `random`) for tokens, OTPs and identifiers.
