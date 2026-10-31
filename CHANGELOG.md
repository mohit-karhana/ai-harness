# Changelog

All notable changes to the harness. Engineers receive these through
`scripts/update.sh`. Versions follow semver: MAJOR for changes that need
manual migration in projects, MINOR for new standards/skills/workflows,
PATCH for wording fixes.

## 1.2.0 (2026-10-31)

- Opt-in skills: a new `optional-skills/` directory, enabled per project with
  `setup.sh --with-skills <name>` or `INCLUDE_SKILLS=` in `.ai-harness/config`.
- Vendored Cloudflare `security-audit` skill (MIT) as an opt-in skill, pinned
  to commit `c1c8a8c1471069fb0e188eeaff69b8e8db6564a8` (2026-09-14). Upstream
  test files are excluded; provenance is recorded in `UPSTREAM`.
- `scripts/vendor-skill.sh` to vendor or re-pin third-party skills at an
  exact commit; `validate.sh` checks the pin and license.

## 1.1.0 (2026-10-30)

- New always-on standard `tech-stack.md`: the approved company stack is
  Django 5.2 LTS + DRF or FastAPI on the back end, React + TypeScript on the
  front end, plus PostgreSQL, Redis and Celery. It includes guidance on
  choosing Django or FastAPI, an OpenAPI-generated typed client as the
  front-end/back-end contract, and an approval rule for new technologies.
- New `examples/fastapi-project` sample, used by the test suite.

## 1.0.0 (2026-10-30)

- Core company instructions (`AGENTS.md`) with inspect → plan → implement →
  test → review workflow, precedence rules, and approval requirements.
- Stack standards: general, python, django, fastapi, javascript, react,
  database, api-development, testing, security, devops.
- Skills: implement-feature, create-api, debug-issue, code-review, write-tests,
  database-optimization, refactor-code.
- Workflows / slash commands: new-feature, bug-fix, code-review, debugging,
  deployment.
- `setup.sh`, `update.sh`, `uninstall.sh`, `validate.sh` with checksum-based
  conflict detection, Claude Code and Cursor integration.
