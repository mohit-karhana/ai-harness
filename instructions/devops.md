---
description: DevOps standards for Docker, CI/CD, infrastructure as code, Kubernetes, observability and releases.
globs: **/Dockerfile*,**/docker-compose*.yml,**/compose*.yml,**/*.tf,.github/workflows/**,**/k8s/**,**/helm/**,**/Jenkinsfile,.gitlab-ci.yml
alwaysApply: false
---
# DevOps Standards

## Approval required
- **Never deploy, apply infrastructure, or change production configuration without
  explicit user approval.** This includes `terraform apply`, `kubectl apply/delete`,
  `helm upgrade`, cloud CLI mutations, DNS changes and secret rotation.
- Present the plan (`terraform plan`, `kubectl diff`, `helm diff`) and a rollback
  procedure before asking.
- Read-only inspection (`get`, `describe`, `logs`, `plan`) against non-prod is fine;
  ask before touching production even read-only if it may expose customer data.

## Docker
- Pin base images to a specific version (and digest for production images); prefer
  slim/distroless official images.
- Multi-stage builds: build tools in the builder stage, only runtime artifacts in final.
- Run as a non-root user (`USER app`); read-only filesystem where possible.
- Never bake secrets into images (no `ENV SECRET=`, no copying `.env`); use build
  secrets (`--mount=type=secret`) or runtime injection.
- Maintain `.dockerignore` (exclude `.git`, `.env*`, `node_modules`, tests data).
- Order layers for caching: dependency manifests first, then source.
- Add `HEALTHCHECK` or rely on orchestrator probes.

```dockerfile
FROM python:3.12.4-slim AS runtime
RUN useradd --create-home --uid 10001 app
WORKDIR /app
COPY --from=builder /app/.venv /app/.venv
COPY --chown=app:app src/ ./src/
USER app
CMD ["/app/.venv/bin/gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:8000"]
```

## CI/CD
- CI runs lint, type checks, tests, dependency/vulnerability scan and image scan on
  every PR. Don't skip or weaken checks to make a pipeline pass.
- Pin third-party actions/orbs to a version or SHA; grant least-privilege tokens
  (`permissions:` in GitHub Actions).
- Secrets come from the CI secret store; never echo them; mask outputs.
- Build once, promote the same artifact through environments.
- Production deploys require approval gates and run migrations as an explicit step.

## Infrastructure as Code
- All infrastructure changes go through IaC (Terraform/Helm/etc.) and code review;
  no click-ops for persistent resources.
- Run `fmt`/`validate`/`plan` and include the plan summary in the PR.
- Watch plans for `destroy`/`replace` actions and call them out explicitly.
- Remote state with locking; never commit state files or `.tfvars` with secrets.
- Tag resources (owner, environment, cost-center); least-privilege IAM; encrypt
  storage and enforce TLS; no public buckets/databases.

## Kubernetes
- Set resource `requests` and `limits` for every container.
- Define `readinessProbe` and `livenessProbe` (and `startupProbe` for slow starts).
- Run as non-root, drop capabilities, `readOnlyRootFilesystem: true` where possible.
- Secrets via the cluster secret mechanism / external secrets operator, not ConfigMaps.
- Use `PodDisruptionBudget` and multiple replicas for user-facing services.
- Rolling updates with `maxUnavailable` that preserves capacity.

## Configuration
- Twelve-factor: config via env vars; separate config per environment; no environment
  branching in code beyond config.
- Feature flags for risky releases; clean them up afterwards.

## Observability
- Structured JSON logs with request/trace IDs; no PII or secrets in logs.
- Expose metrics (latency, error rate, throughput, saturation) and health endpoints.
- Alerts are actionable and linked to a runbook.

## Releases and rollback
- Every deploy has a documented rollback (previous image tag, `helm rollback`,
  feature flag off). DB migrations must be backward compatible with the previous app
  version so rollback is possible.
- Prefer canary/blue-green for high-risk changes; monitor error rates after release.
