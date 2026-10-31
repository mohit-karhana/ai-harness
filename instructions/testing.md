---
description: Testing standards for writing, structuring and running unit and integration tests.
globs:
alwaysApply: true
---
# Testing Standards

## Principles
- Every new behaviour ships with tests. Every bug fix ships with a regression test that
  fails before the fix and passes after it.
- Follow the test pyramid: many fast unit tests, fewer integration tests, a small number
  of end-to-end tests for critical journeys (quote → buy policy, file claim, payments).
- Tests document behaviour: a reader should understand the business rule from the test.
- Follow the project's existing test framework, layout and helpers (pytest vs unittest,
  Jest vs Vitest, factories, fixtures). Do not introduce a second framework.

## Finding how to run tests
- Read `.ai-harness/project-context.md` → "Development Commands" first.
- Otherwise check `Makefile`, `pyproject.toml`/`pytest.ini`/`setup.cfg`, `package.json`
  scripts, `tox.ini`, and CI workflow files. Use the same command CI uses.
- Run the narrowest relevant subset while iterating, then the full affected suite.

## Unit vs integration
- **Unit:** one unit of behaviour, no network, no real DB where avoidable, milliseconds.
- **Integration:** real collaborators inside our boundary (DB, ORM, serializers, HTTP
  layer via test client). Use the test database the framework provides.
- **External services** (payment gateways, SMS, insurers' APIs, LLMs): never call real
  ones. Mock at the boundary (the client wrapper), or use recorded fakes.
- Never point tests at staging or production systems or real customer data.

## Structure
- Arrange–Act–Assert, separated by blank lines. One behaviour per test.
- Name tests after behaviour: `test_claim_rejected_when_policy_lapsed`, not `test_claim_2`.
- Prefer factories (factory_boy, test data builders) over large shared fixtures; build
  only the data the test needs.
- Keep assertions specific: assert on values and status codes, not just "truthy".

```python
def test_premium_includes_gst_for_individual_policy(policy_factory):
    policy = policy_factory(plan__base_premium=Decimal("1000.00"), holder_type="individual")

    premium = calculate_premium(policy)

    assert premium.total == Decimal("1180.00")
    assert premium.tax == Decimal("180.00")
```

## Determinism
- No dependence on test order, wall-clock time, randomness, timezone or locale.
  Freeze time (`freezegun`, `time-machine`, `jest.useFakeTimers`); seed randomness.
- No `sleep` to wait for async work; await the result or use the framework's helpers.
- Clean up created files, env vars and global state.
- A flaky test is a bug: fix it or quarantine it with a ticket, never just re-run.

## Mocking
- Mock only at boundaries you own wrappers for (HTTP clients, queues, clocks, storage).
- Do not mock the code under test or ORM internals.
- Assert on behaviour/outcomes rather than on how many times internals were called,
  unless the call itself is the contract (e.g. "email sent once").

## What to cover
- Happy path, validation failures, permission denials (authenticated but not
  authorized, other tenant's object), not-found, boundary values (0, max, empty,
  None/null, unicode), and error paths from dependencies (timeouts, 5xx).
- Money: rounding and currency precision with `Decimal`, never floats.
- Dates: month ends, leap years, timezone boundaries, policy start/end inclusive rules.
- Idempotency of retries for tasks and webhooks.

## Test data
- Synthetic only. Never copy production records, real names, phone numbers, emails,
  policy numbers or medical details into tests or fixtures.
- Use obviously fake values (`example.com`, `+91-00000-00000`).

## Coverage
- Coverage is a signal, not a target. Changed lines should be covered; critical modules
  (payments, claims adjudication, auth, permissions) need branch coverage of their rules.
- Do not write assertion-free tests to inflate coverage.

## Before declaring done
- Run the relevant tests and report the exact command and result.
- If tests cannot be run (missing services, credentials), say so explicitly and explain
  what was verified instead. Never claim tests pass without running them.
