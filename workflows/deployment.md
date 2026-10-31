---
description: Prepare and validate a release — readiness checks, migration review, rollback plan; humans perform the deploy
argument-hint: <release/branch/tag to prepare and the target environment, e.g. "v2.4.0 to staging">
---
# Deployment Workflow

Apply this workflow to the task provided by the user.

> **Hard rule:** the AI **prepares and validates** releases. It does **not** deploy to production,
> run production migrations, change production configuration/secrets, or trigger production
> pipelines. A human performs those steps. For non-production environments (dev/staging), the AI
> may run deploy commands **only** after explicit approval for that specific command and environment.

Supporting skills: code-review, write-tests, database-optimization (migration safety).

## Phase 1 — Inspect

1. Read `.ai-harness/project-context.md` (environments, deploy process, CI/CD) and
   `.ai-harness/instructions/devops.md`.
2. Identify what is being released: `git log --oneline <last-release-tag>..<release-ref>`,
   linked tickets, migrations included (`git diff --name-only <tag>..<ref> | grep -i migration`).
3. Identify the deploy mechanism (CI pipeline, Helm, Terraform, platform CLI) **by reading
   config only**. Do not execute pipeline scripts.

**Exit criteria:** a list of changes, migrations, config/env var changes and dependencies in scope.

## Phase 2 — Plan (release readiness)

Produce a pre-deploy checklist with the status of each item:

- [ ] CI green on the release ref (tests, lint, type checks, security scans)
- [ ] All changes reviewed and approved (PR approvals)
- [ ] Migrations reviewed: backward compatible with the currently running code, non-blocking on large
      tables, reversible or with a documented rollback (**database-optimization** for risky ones)
- [ ] New/changed environment variables and secrets identified (names only — never values) and
      provisioned by a human in the secret manager
- [ ] Feature flags defined with safe defaults (off)
- [ ] Dependency changes reviewed (lockfile diff, known CVEs)
- [ ] Observability: logs/metrics/alerts for new critical paths; dashboards to watch named
- [ ] Release notes / changelog drafted
- [ ] Rollback plan written (below) and owner identified
- [ ] Deploy window and on-call person confirmed

## Phase 3 — Implement (prepare artefacts)

The AI may: draft release notes, bump version files, write the rollback plan, prepare migration
SQL previews (`python manage.py sqlmigrate`, `alembic upgrade <rev> --sql`), validate config
syntax (`docker compose config`, `terraform validate`, `helm template`, `kubectl --dry-run=client`),
and build artefacts locally.

**⏸ Checkpoint — explicit human approval required** for each of: tagging/pushing, triggering any
pipeline, deploying to any shared environment, running migrations outside local, `terraform apply`,
`kubectl apply`, or modifying infrastructure. Production steps are always executed by a human.

## Phase 4 — Test

1. Run the full test suite and build locally against the release ref.
2. Check migrations on a local or disposable DB from the previous release's schema:
   migrate forward, run smoke tests, migrate back (if reversible).
3. Prepare a post-deploy smoke test list (health endpoint, login, key user journeys).

## Phase 5 — Review

Run **code-review** on the release diff focusing on: breaking changes, migrations, config,
security-sensitive code. Any blocker → recommend **no-go**.

## Phase 6 — Hand-off

```markdown
## Release readiness: <version> → <environment>
**Recommendation:** GO | NO-GO (reasons)

### Scope
- <ticket/PR> — <summary>

### Pre-deploy checklist
- [x] / [ ] <item> — <evidence>

### Migrations
- <migration> — locking risk, duration estimate, reversible: yes/no

### Config & secrets (names only)
- <ENV_VAR> — <purpose>, provisioned: yes/no (human)

### Deploy steps (performed by a human)
1. <step>

### Post-deploy verification
- <smoke checks, dashboards, alerts to watch for N minutes>

### Rollback plan
1. Trigger: <conditions, e.g. error rate > X% for 5 min>
2. Steps: <redeploy previous artefact/tag; disable feature flag; migration rollback or forward-fix>
3. Data considerations: <irreversible migrations, backfills>
4. Owner: <name/role>
```
