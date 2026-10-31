---
name: write-tests
description: Write or extend unit and integration tests that follow the project's existing test framework, layout, fixtures and naming, covering happy paths, edge cases, error and permission paths. Use when the user asks to add tests, improve coverage, write a regression test, or when new code needs tests.
---

# Write Tests

## Purpose

Produce reliable, readable tests that prove behaviour and protect against regressions, written
in the project's existing style so they are maintained rather than deleted. Tests must be
deterministic, isolated and free of real customer data and real external services.

## When to use

- "Write tests for X", "add coverage", "add a regression test"
- As the Test phase of `implement-feature`, `create-api`, `debug-issue`, `refactor-code`
- Before refactoring untested code (characterisation tests)

### When NOT to use

- End-to-end/browser suites the project does not already have — propose them instead of adding
  a new framework.
- Load/performance testing — discuss tooling with the user first.

## Required context

1. `.ai-harness/project-context.md` — test commands, test database setup, CI constraints.
2. `.ai-harness/instructions/testing.md` and the stack file(s) for the code under test.
3. The existing test setup — **never introduce a second test framework**:
   - Python: `pytest.ini`/`pyproject.toml [tool.pytest]`, `conftest.py`, factories (`factory_boy`,
     `model_bakery`), Django `TestCase` vs `pytest-django`.
   - JS/TS: `jest.config.*`/`vitest.config.*`, `setupTests`, React Testing Library, MSW handlers.
4. Two existing tests closest to the code under test; copy their structure, fixtures and naming.
5. The code under test and its public contract (inputs, outputs, side effects, errors).

## Steps

1. **Identify behaviours to test.** List them before writing code:
   - Happy path(s) for each public function/endpoint/component.
   - Edge cases: empty, None/null, boundaries, large inputs, unicode, timezones.
   - Error paths: invalid input, not found, conflicts, downstream failures.
   - Permissions: unauthenticated, wrong role, other tenant's data.
   - For bug fixes: the exact failing scenario.
2. **Choose the level.** Unit test pure logic; integration test across DB/API boundaries; mock only
   at system boundaries (HTTP clients, payment gateways, email, clock, randomness) — not the code
   under test.
3. **Write the tests** in the project's style. Stack hints:
   - **pytest:** `def test_<behaviour>_<condition>()`, fixtures in `conftest.py`, `pytest.mark.parametrize`
     for input tables, `pytest.raises` for errors, `freezegun`/`time-machine` for time if already used.
   - **Django:** `APIClient`/`client.force_login`, factories over fixtures JSON, `assertNumQueries` on
     list endpoints, `@override_settings` for settings, `django_capture_on_commit_callbacks` for
     `on_commit` side effects.
   - **FastAPI:** `TestClient`/`httpx.AsyncClient`, override dependencies via
     `app.dependency_overrides`, transactional test DB session fixture.
   - **Jest/Vitest + RTL:** query by role/label (`getByRole`), `userEvent` for interactions,
     `findBy*` for async UI, MSW for network, assert what the user sees — not component internals.
   - **Express:** `supertest(app)` against the app instance, test DB or repository fakes.
4. **Arrange–Act–Assert.** One behaviour per test; descriptive names; no logic (loops/ifs) in tests
   beyond parametrisation; assert specific values, not just "truthy".
5. **Determinism.** No real network, no `sleep`, fixed seeds and frozen time, no dependence on test
   order or on data created by other tests.
6. **Data safety.** Use factories and obviously fake data (`user@example.com`). Never copy production
   records, real names, phone numbers, policy numbers or tokens into tests.
7. **Run** the new tests, then the surrounding module, using the project's command
   (e.g. `pytest tests/orders -q`, `python manage.py test orders`, `npm test -- orders`).
   For bug fixes, confirm the test fails without the fix.
8. **Check coverage of the change** if the project uses coverage (`pytest --cov=app --cov-report=term-missing`,
   `npx vitest run --coverage`) and fill meaningful gaps — do not chase 100% with trivial tests.

## Expected output

- List of test files added/changed and the behaviours each test covers.
- Commands run and results (passed/failed counts); for regressions, proof the test failed before.
- Any behaviours intentionally left untested and why; flaky or slow areas noticed.

## Validation checklist

- [ ] Uses the existing framework, fixtures, factories and file layout
- [ ] Happy path, edge cases, error paths and permission paths covered
- [ ] Mocks only at system boundaries; no real external calls
- [ ] Deterministic: no sleeps, frozen time/seeds, order-independent
- [ ] Test names describe behaviour; one behaviour per test
- [ ] No real customer data, secrets or production identifiers
- [ ] All new and surrounding tests pass locally
