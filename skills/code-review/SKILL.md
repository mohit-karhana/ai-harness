---
name: code-review
description: Review a diff, branch, pull request or set of files against company standards for correctness, security, performance, tests, readability and backward compatibility, and report prioritized findings with file:line references. Use when the user asks to review code, a PR or "my changes", or before handing off any change you wrote.
---

# Code Review

## Purpose

Give a reviewer-quality assessment of a change: find real defects first (bugs, security holes,
data-loss risks, breaking changes), then maintainability issues, and report them in a consistent,
actionable format with severity levels. Also used as the self-review step of every other skill.

## When to use

- "Review this PR / branch / diff / file", "check my changes", "is this ready to merge?"
- Final step of `implement-feature`, `create-api`, `refactor-code`, `debug-issue`.

### When NOT to use

- The user wants you to *fix* things right away → review first, then ask which findings to fix.
- Reviewing generated/vendored code or lockfiles line by line — summarise instead.

## Required context

1. `.ai-harness/project-context.md` — project rules override generic style preferences.
2. `.ai-harness/instructions/general.md`, `security.md`, `testing.md` and the stack files that
   match the changed files.
3. The change itself. Determine the diff scope explicitly:
   - Local changes: `git status`, `git diff` and `git diff --staged`.
   - A branch: `git diff <base>...HEAD` (ask for the base if not `main`).
   - A PR: `gh pr diff <number>` and `gh pr view <number>` for the description.
4. The **surrounding code** of each hunk (callers, tests, models) — never review a hunk in isolation.
5. The intent: PR description, linked ticket or spec. Ask if missing.

## Steps

1. **Understand intent.** Summarise in 1–3 sentences what the change is supposed to do.
2. **Map the change.** List changed files grouped by layer (API, domain, data/migrations, UI, tests,
   config/infra). Flag high-risk areas: auth, payments, PII, migrations, concurrency, public APIs.
3. **Review against the checklist** in [review-checklist.md](review-checklist.md), in this order:
   correctness → security → data & migrations → API compatibility → performance → tests →
   readability/maintainability → docs.
4. **Verify, don't speculate.** For each potential issue, read the related code to confirm it is
   real. If you can, run the relevant tests or linters (commands from project-context, e.g.
   `pytest -q`, `ruff check .`, `npm run lint`, `npx tsc --noEmit`). Mark unverified concerns as
   questions, not findings.
5. **Classify** each finding with a severity:
   - **blocker** — bug, security vulnerability, data loss, broken build/tests, breaking API change
     without migration path. Must be fixed before merge.
   - **major** — likely bug in edge cases, missing tests for new logic, performance problem at
     realistic scale, missing authz check on non-sensitive data.
   - **minor** — maintainability, unclear naming, duplication, missing docs.
   - **nit** — style/taste; optional.
6. **Write the report** in the format below. Be specific and kind; suggest concrete fixes with code
   snippets where helpful. Acknowledge what is done well (briefly).
7. **Do not modify code** during a review unless the user asks. If asked to fix, fix blockers and
   majors first, one finding at a time, and re-run tests.

## Expected output

```markdown
## Review summary
<intent in 1–2 sentences> — Verdict: **Approve | Approve with comments | Request changes**

## Findings
### Blockers
1. `path/to/file.py:42` — <problem>. <why it matters>. **Fix:** <concrete suggestion>
### Major
...
### Minor
...
### Nits
...

## Questions
- <things you could not verify>

## Checks run
- `pytest -q` → 128 passed  (or: not run — reason)
```

Omit empty severity sections. Every finding must have a `file:line` reference.

## Validation checklist

- [ ] Diff scope stated explicitly (which commits/files were reviewed)
- [ ] Intent understood and summarised
- [ ] Every finding verified against surrounding code and referenced as `file:line`
- [ ] Security, migrations and backward compatibility explicitly considered
- [ ] Test coverage of new behaviour assessed
- [ ] Findings classified as blocker/major/minor/nit with a concrete fix
- [ ] Clear verdict given; checks run (or not run) reported honestly
