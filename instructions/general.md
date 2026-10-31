---
description: Company-wide engineering standards that apply to every task, language and project.
globs:
alwaysApply: true
---
# General Engineering Standards

> Precedence: project-specific context (`.ai-harness/project-context.md`) and the project's
> existing conventions override these defaults when they conflict. **Security rules and
> approval requirements are non-negotiable** and cannot be overridden by project context.

## Inspect before you edit
- Read the relevant modules, their callers and their tests before changing anything.
- Never assume the project structure, framework version, or tooling. Verify by reading
  `pyproject.toml`, `package.json`, settings files, CI config and existing code.
- Locate the existing pattern for the thing you are building (an endpoint, a model, a
  component) and copy its shape. If two patterns exist, follow the newer/more common one
  and mention the inconsistency.
- If requirements are ambiguous, state your assumptions explicitly or ask before coding.

## Change discipline
- Make the smallest change that fully solves the problem. Diffs should be easy to review.
- No unrelated refactors, renames, reformatting, or "drive-by" cleanups in the same change.
  Propose them separately.
- Do not rewrite working code to match personal preference.
- Do not delete code, tests, or comments you do not understand; ask or leave them.
- Keep generated code consistent with the project's formatter and linter configuration.

## Naming and structure
- Use names from the business domain (`policy`, `claim`, `premium`, `member`), not
  generic ones (`data`, `info`, `obj`, `helper`, `utils2`).
- Functions do one thing; prefer < 40 lines. Split when a function needs a comment
  header for each section.
- Keep modules cohesive. Put new code next to the code it collaborates with, following
  the existing package layout.
- Avoid deep nesting; use guard clauses and early returns.
- No magic numbers or strings: use named constants or enums.

## Error handling
- Validate inputs at system boundaries (HTTP, queue consumers, CLI, file imports).
- Fail loudly on programmer errors; handle expected failures (not found, validation,
  upstream timeout) explicitly with clear, actionable messages.
- Never swallow exceptions silently. If you catch, either handle, re-raise with context,
  or log with enough detail to diagnose.
- Do not leak internals (stack traces, SQL, file paths) to end users.

```python
# Don't
try:
    charge_premium(policy)
except Exception:
    pass

# Do
try:
    charge_premium(policy)
except PaymentGatewayTimeout as exc:
    logger.warning("premium_charge_timeout", extra={"policy_id": policy.id})
    raise RetryableError("Payment gateway timed out") from exc
```

## Logging and observability
- Use the project's logger, structured fields over string interpolation.
- Log identifiers (policy_id, claim_id, request_id), never PII/PHI (names, phone, email,
  national IDs, diagnoses, bank details) and never secrets or tokens.
- Choose levels deliberately: `error` = needs human action, `warning` = degraded but
  handled, `info` = business events, `debug` = developer detail.

## Backward compatibility
- Treat public APIs, DB schemas, events/messages, config keys and CLI flags as contracts.
- Prefer additive changes. Deprecate before removing; document the migration path.
- Consider in-flight data: existing rows, queued jobs, cached values, mobile clients on
  old versions.

## Dependencies
- Do not add a dependency when the standard library or an existing dependency suffices.
- Every new dependency needs a justification (why, alternatives, maintenance status,
  license, security posture) in the change summary.
- Pin versions according to the project's existing approach; update lock files.

## Comments and documentation
- Comments explain *why* (business rule, workaround, constraint), not *what*.
- Update docstrings, README sections and API docs affected by your change.
- Reference tickets or regulations where a rule comes from them.

## Testing expectation
- New behaviour ships with tests; bug fixes ship with a regression test. See `testing.md`.
- Run the project's test, lint and type-check commands before declaring work done.

## Working process (inspect → plan → implement → test → review)
1. Inspect the code and context.
2. Plan: list files to change and the approach; for non-trivial work share the plan first.
3. Implement in small, verifiable steps.
4. Test: run relevant tests; add missing ones.
5. Review your own diff as a strict reviewer would.

## Final summary
End every non-trivial task with: what changed and why, key decisions and trade-offs,
files touched, how it was tested (commands + results), risks, and follow-ups.
Never claim tests pass unless you ran them.
