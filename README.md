# AI Engineering Harness

One centrally maintained set of AI coding standards, skills and workflows that
every engineer can install into any project, for **Claude Code** and
**Cursor**, with one command.

```bash
git clone https://github.com/company/ai-harness.git
cd ai-harness
./scripts/setup.sh /path/to/my-project
```

---

## Contents

1. [What an AI harness is](#1-what-an-ai-harness-is)
2. [Why we need it](#2-why-we-need-it)
3. [How the repository works](#3-how-the-repository-works)
4. [Integrating it into a project](#4-integrating-it-into-a-project)
5. [Using it in Cursor](#5-using-it-in-cursor)
6. [Using it in Claude Code](#6-using-it-in-claude-code)
7. [Updating](#7-updating)
8. [Adding skills, workflows and standards](#8-adding-skills-workflows-and-standards)
9. [Administering company standards](#9-administering-company-standards)
10. [Troubleshooting](#10-troubleshooting)
11. [Security model](#11-security-model)
12. [Compatibility and limitations](#12-compatibility-and-limitations)

---

## 1. What an AI harness is

An AI coding assistant is only as consistent as the instructions it is given.
Without guidance each assistant falls back on generic habits: it guesses
project structure, rewrites code it does not need to touch, skips tests, and
treats `DROP TABLE` like any other command.

A **harness** is the set of instructions, reusable procedures and guard rails
wrapped around the assistant so that it behaves like a well-onboarded engineer
on *our* team:

| Layer | What it is | Where it lives in a project |
|-------|------------|-----------------------------|
| **Standards** | Always-on and file-type-specific rules (coding, security, testing…) | `.ai-harness/AGENTS.md`, `.ai-harness/instructions/` |
| **Project context** | Architecture, commands and rules of *this* project | `.ai-harness/project-context.md` |
| **Skills** | Step-by-step procedures the AI loads on demand (debugging, reviews, APIs…) | `.claude/skills/<name>/SKILL.md` |
| **Workflows** | End-to-end processes started with a slash command (`/new-feature`, `/bug-fix`…) | `.ai-harness/workflows/` + command stubs |
| **Guard rails** | Tool permissions and ignore lists that keep secrets out and require approval for risky commands | `.claude/settings.json`, `.cursorignore` |

## 2. Why we need it

- **Consistency across teams and tools.** Some engineers use Cursor, others use
  Claude Code, and projects range from Django back ends to React front ends.
  The same company rules now reach every one of them.
- **Safer AI use.** We handle customer PII, health and insurance data. The
  harness makes "never paste customer data into a prompt" and "ask before
  running a migration against a shared database" part of every session,
  rather than something each engineer has to remember to say.
- **Better output.** The AI follows *inspect → plan → implement → test →
  review* instead of generating code blindly, writes tests, and explains its
  decisions.
- **Zero per-project configuration.** `setup.sh` detects the stack and
  installs only what is relevant. `update.sh` keeps projects current.
- **One approved stack.** Back ends use Python with Django + DRF or FastAPI;
  front ends use React + TypeScript; data lives in PostgreSQL and Redis. The
  always-on `tech-stack.md` rule tells the AI what is approved, when to pick
  Django or FastAPI, and that anything else needs human approval.
- **Owned centrally, adapted locally.** The platform team maintains company
  standards in one place. Each project adds its own context, and that context
  wins when the two conflict (except for security rules).

## 3. How the repository works

```
ai-harness/
├── AGENTS.md                 # Core company instructions (canonical source)
├── CLAUDE.md                 # Instructions for working on this repo itself
├── VERSION                   # Harness version (semver), shown on update
├── CHANGELOG.md
├── instructions/             # Stack standards, with Cursor-style frontmatter
│   ├── general.md  tech-stack.md  security.md  testing.md   (always on)
│   ├── python.md  django.md  fastapi.md            (Python stacks)
│   ├── javascript.md  react.md                     (JS/TS stacks)
│   └── database.md  api-development.md  devops.md  (cross-cutting)
├── skills/                   # Native Agent Skills (SKILL.md + resources)
│   ├── implement-feature/  create-api/  debug-issue/  code-review/
│   └── write-tests/  database-optimization/  refactor-code/
├── optional-skills/          # Opt-in skills, installed only when a project asks
│   └── security-audit/       # Cloudflare's audit skill (MIT), pinned + UPSTREAM file
├── workflows/                # Process playbooks → slash commands
│   └── new-feature.md  bug-fix.md  code-review.md  debugging.md  deployment.md
├── templates/
│   ├── project-context.md    # Per-project context (filled in on setup)
│   └── feature-specification.md
├── config/
│   ├── claude-settings.json  # Claude Code permission guard rails
│   └── ai-ignore             # Secret patterns hidden from Cursor
├── scripts/
│   ├── setup.sh  update.sh  uninstall.sh  validate.sh  vendor-skill.sh
│   └── lib/  common.sh detect.sh build.sh reconcile.sh apply.sh
├── tests/run_tests.sh        # Installation/update/uninstall test suite
└── examples/
    ├── django-project/       # Sample Django/DRF service
    ├── fastapi-project/      # Sample FastAPI service
    └── react-project/        # Sample React/TypeScript app
```

### Design principles

- **Single source of truth.** Every standard is written once in this repo.
  Tool-specific files in projects are *generated* from it.
- **Native formats only.** Each tool discovers files it already understands:
  `CLAUDE.md` imports, `.cursor/rules/*.mdc`, `AGENTS.md`, Agent Skills
  (`SKILL.md`), and slash commands. There is no custom loader, plugin or server.
- **Harness-owned vs developer-owned.** Every installed file is either managed
  by the harness (tracked by checksum in `.ai-harness/manifest`) or owned by
  the developer (`project-context.md`, `config`, and everything outside the
  marked blocks). Managed files are updated only while they are unmodified.
- **Install only what is relevant.** A React app does not receive Django rules
  or the database-optimization skill.

### What gets installed in a project

```
my-project/
├── AGENTS.md                      # + short harness block (your content kept)
├── CLAUDE.md                      # + harness block of @imports (your content kept)
├── .cursorignore                  # + harness block of secret patterns
├── .ai-harness/
│   ├── project-context.md         # YOURS: architecture, commands, rules
│   ├── config                     # YOURS: stack/tool selection
│   ├── AGENTS.md                  # core company instructions
│   ├── instructions/*.md          # relevant stack standards
│   ├── workflows/*.md             # process playbooks
│   ├── templates/feature-specification.md
│   ├── claude-settings.json       # recommended Claude permissions
│   ├── README.md  VERSION  manifest
├── .claude/
│   ├── skills/<skill>/SKILL.md    # read by Claude Code AND Cursor
│   ├── commands/<workflow>.md     # /new-feature, /bug-fix, ...
│   └── settings.json              # created only if you don't have one
└── .cursor/
    ├── rules/ai-harness-*.mdc     # core (always) + per-stack (auto-attached by glob)
    └── commands/<workflow>.md     # /new-feature, /bug-fix, ...
```

### How each tool discovers the instructions

| | Claude Code | Cursor |
|---|---|---|
| Core company rules | `CLAUDE.md` block imports `@.ai-harness/AGENTS.md` | `.cursor/rules/ai-harness-core.mdc` (`alwaysApply: true`) |
| Stack standards | `CLAUDE.md` imports `@.ai-harness/instructions/<x>.md` (loaded every session) | `.cursor/rules/ai-harness-<x>.mdc`: always-on rules plus rules auto-attached when matching files (`globs`) are in context |
| Project context | `CLAUDE.md` imports `@.ai-harness/project-context.md` | Core rule tells the agent to read it before every task |
| Existing project instructions | Your `CLAUDE.md` content, plus `@AGENTS.md` | Your `AGENTS.md` (read natively) and your own `.cursor/rules` |
| Skills | `.claude/skills/*/SKILL.md` | Same directory: Cursor reads `.claude/skills/` for compatibility |
| Workflows | `.claude/commands/*.md` → `/new-feature` | `.cursor/commands/*.md` → `/new-feature` |
| Guard rails | `.claude/settings.json` deny/ask permissions | `.cursorignore` block |
| Other agents (Codex, Copilot, …) | — | Root `AGENTS.md` block points to `.ai-harness/` |

### Precedence

The AI is told to resolve conflicts in this order:

1. Security rules and approval requirements (cannot be overridden)
2. The user's explicit request
3. Project context, the project's own instructions, and existing code conventions
4. Company stack standards
5. General defaults

## 4. Integrating it into a project

### Prerequisites

macOS or Linux, `bash` (3.2+ is fine), `git`, and standard Unix tools. Nothing
else: no Python, Node or network access is needed to install.

### Install

```bash
git clone https://github.com/company/ai-harness.git ~/tools/ai-harness
cd ~/tools/ai-harness
./scripts/setup.sh ~/code/healthysure-backend      # absolute path
./scripts/setup.sh ../claims-portal                 # relative paths work too
```

Example output (Django project):

```
ai-harness 1.1.0 setup → /Users/dev/code/healthysure-backend
  stack:  python django database api devops (auto-detected)
  tools:  claude cursor

Changes
  + installed   .ai-harness/AGENTS.md
  + installed   .ai-harness/instructions/general.md
  ...
  = kept        .ai-harness/project-context.md (user-owned)
  + installed   CLAUDE.md (harness block appended; existing content preserved)
  ! skipped     .claude/skills/code-review/SKILL.md
      existing file not created by ai-harness (rerun interactively or with --force to replace)

Summary: 50 installed, 0 updated, 0 removed, 0 unchanged, 1 skipped, 0 conflicts

Components
  instructions: general tech-stack security testing api-development database devops django python
  skills:       code-review create-api database-optimization debug-issue implement-feature refactor-code write-tests
  workflows:    bug-fix code-review debugging deployment new-feature
```

Then:

1. **Fill in `.ai-harness/project-context.md`.** It is pre-filled with the
   project name and detected stack. Add architecture, important modules,
   commands and business rules. This is where most of the quality comes from.
2. **Review and commit** the changes (`git diff`). Committing them means
   teammates get the setup on `git pull` without running anything.
3. Open the project in your AI tool and try `/new-feature`.

### Options

| Option | Purpose |
|--------|---------|
| `--dry-run` | Show what would change; write nothing |
| `--stack django,devops` | Skip auto-detection. Tags: `python django fastapi flask javascript typescript node react nextjs database api devops` |
| `--tools claude` | Configure only some tools (`claude`, `cursor`; default both) |
| `--with-skills security-audit` | Add opt-in skills from `optional-skills/` |
| `--exclude-skills create-api` | Do not install some skills |
| `--exclude-workflows deployment` | Do not install some workflows |
| `--force` | Replace conflicting files (a timestamped backup is kept) |
| `--non-interactive` | Never prompt (CI); files needing approval are skipped |

Selections are saved in `.ai-harness/config` and reused by `update.sh`.

### What detection looks at

Detection only *reads* manifest files, up to three directories deep (so
`backend/` + `frontend/` monorepos work), skipping `node_modules`, virtualenvs
and build output. It never runs project code.

| Signal | Tags |
|--------|------|
| `manage.py`, `django` in requirements/pyproject | `django python database api` |
| `fastapi` / `flask` in Python deps | `fastapi`/`flask python api` |
| `requirements*.txt`, `pyproject.toml`, `Pipfile`, `setup.py` | `python` |
| `package.json` | `javascript` |
| `"react"` / `"next"` dependency | `react` / `nextjs` |
| `express`, `fastify`, `koa`, `@nestjs/core` | `node api` |
| `tsconfig.json` or `typescript` dependency | `typescript` |
| ORM/driver deps, `migrations/`, `*.sql`, `prisma/` | `database` |
| `Dockerfile`, compose files, `.github/workflows`, `*.tf`, `k8s/`, `helm/` | `devops` |

### Safe by design

- **Idempotent**: running setup again changes nothing unless the harness changed.
- **Never overwrites your files silently**: an existing file the harness did
  not create (for example your own `.claude/skills/code-review/SKILL.md`) is
  left alone. In a terminal you are asked first; in CI it is skipped.
- **Preserves your instructions**: in `AGENTS.md`, `CLAUDE.md` and
  `.cursorignore` the harness only adds or refreshes a block between
  `ai-harness:begin` / `ai-harness:end` markers. Everything else is yours.
- **Respects your Claude settings**: `.claude/settings.json` is created only
  if missing. Otherwise the recommended rules are in
  `.ai-harness/claude-settings.json` for you to merge.

## 5. Using it in Cursor

After setup, open the project in Cursor (a recent version with Agent Skills
and custom commands; see [§12](#12-compatibility-and-limitations)).

- **Rules**: *Cursor Settings → Rules* lists `ai-harness-core` (always) and
  `ai-harness-<stack>` rules. Stack rules attach automatically when matching
  files are in context. For example, editing `policies/models.py` attaches the
  Python, Django and database rules.
- **Skills**: listed under *Settings → Skills* (read from `.claude/skills/`).
  The agent picks one when your request matches its description, or you can
  type `/` and choose it.
- **Workflows**: type `/` in the agent chat:

  ```
  /new-feature Add a policy cancellation endpoint with a 14-day cooling-off refund
  /bug-fix Premium calculation rounds 0.5 down for monthly plans (ticket HS-1423)
  /code-review the changes on this branch
  /debugging pytest tests/test_renewals.py::test_grace_period is flaky
  /deployment prepare release 2.14 of the policies service
  ```

- **Secrets**: the `.cursorignore` block keeps `.env`, keys and credential
  files out of Cursor's context and indexing.

## 6. Using it in Claude Code

Start `claude` in the project directory (CLI, desktop app or IDE extension).

- **Instructions**: `CLAUDE.md` imports the project context, your
  `AGENTS.md`, the core rules and the stack standards. Run `/memory` to see
  what is loaded.
- **Skills**: Claude loads a skill automatically when the task matches (for
  example "why is `/api/v1/policies` slow?" → `database-optimization`). You can
  also ask for one by name: *"use the code-review skill on my diff"*.
- **Workflows**: `/new-feature …`, `/bug-fix …`, `/code-review`,
  `/debugging …`, `/deployment …`.
- **Guard rails**: `.claude/settings.json` denies reading `.env`/key files and
  destructive commands (`rm -rf`, `git push --force`, `git reset --hard`,
  `terraform destroy`, `kubectl delete`…) and asks before `git push`,
  migrations, `terraform apply`, `kubectl apply`, `curl` and similar commands.

### Example developer workflow

```text
$ claude
> /new-feature Allow customers to download a PDF certificate for an active policy

● Reading .ai-harness/project-context.md, policies/models.py, policies/views.py,
  policies/urls.py, policies/tests/ …
● Plan (approval needed: new endpoint + new dependency):
  1. PolicyCertificateView (GET /api/v1/policies/{id}/certificate/), owner-only
  2. Render with existing reportlab helper in documents/pdf.py (no new dependency)
  3. Tests: owner can download, other customer gets 404, draft policy gets 409
  Proceed?
> yes
● Implementing … running `pytest policies` … 14 passed
● Self-review with code-review skill: no blockers; one minor (added docstring)
● Summary: files changed, decisions (404 rather than 403 to avoid leaking
  policy existence), how verified, follow-ups (add rate limit in gateway)
```

### Security audits (opt-in `security-audit` skill)

For a deep security review, enable Cloudflare's
[security-audit skill](https://github.com/cloudflare/security-audit-skill),
which the harness ships pinned to a reviewed commit:

```bash
./scripts/setup.sh --with-skills security-audit ~/code/healthysure-backend
```

It works in Claude Code and Cursor and has two modes:

- **Guidance** (default): answers security questions and runs focused reviews,
  such as *"is the policy download endpoint vulnerable to IDOR?"*. Lightweight,
  and writes no files.
- **Full audit**: start it explicitly, e.g. *"run a full security audit of this
  repo"*. It runs six phases (reconnaissance, coverage-led hunting, independent
  verification of every candidate, schema-validated `findings.json`, a second
  verification, then reports) using many sub-agents. Results go to
  `~/security-audit-skill/<repo>/run-<N>/`, outside the repository:
  `REPORT.md`, `FINDINGS-DETAIL.md`, `NEEDS-VALIDATION.md`.

Things to know before running a full audit:

- **Cost**: it launches many sub-agents. Ask for a `quick` profile or a budget
  (*"quick audit of `policies/`, at most 30 agents"*) and run it before releases
  or on a schedule, not on every change.
- **Node.js** must be installed to run its result validators
  (`validate-findings.cjs`, `validate-coverage-ledger.cjs`).
- **No sandbox, no execution**: it runs project code only inside an
  OS-enforced sandbox with no network. Without one, it reports
  `needs_validation` instead of executing anything.
- Triage its `confirmed` findings like any security report: create tickets and
  fix them with `/bug-fix`.

## 7. Updating

```bash
cd ~/tools/ai-harness
./scripts/update.sh ~/code/healthysure-backend
```

`update.sh`:

1. Runs `git pull --ff-only` on your harness clone (skipped with
   `--no-fetch`, or if the clone has local changes or is pinned to a tag), then
   restarts itself so the new installer logic is used.
2. Re-detects the stack (unless `STACK` is pinned in `.ai-harness/config`).
3. Updates every managed file that you have **not** modified, installs newly
   added files, and removes retired ones that you have not modified.
4. **Never overwrites your edits.** If you changed a managed file, it is
   reported as a conflict, your version is kept, and the upstream version is
   written next to it:

   ```
   ✗ conflict    .ai-harness/instructions/python.md
       local edits kept; upstream version written to .ai-harness/instructions/python.md.harness-new
   ```

   Merge what you need, delete the `.harness-new` file, and you're done. To
   accept upstream wholesale, rerun with `--force` (a backup is kept).
5. Leaves developer-owned content untouched: `project-context.md`, `config`,
   and everything outside the marked blocks.

**Tip:** if you need to change a company rule for one project, don't edit the
managed file. Put the override in `project-context.md` under *Important Rules*.
Project context takes precedence and survives every update.

**Pinning a version:** `git -C ~/tools/ai-harness checkout v1.2.0`, then
`./scripts/update.sh --no-fetch <project>`.

**Removing:** `./scripts/uninstall.sh <project>` removes unmodified harness
files and blocks, and keeps your context and anything you modified (`--purge`
also removes the context and config; `--dry-run` previews).

## 8. Adding skills, workflows and standards

All additions go through a pull request to this repository.

### Add a skill

```bash
mkdir skills/write-migration
$EDITOR skills/write-migration/SKILL.md
```

```markdown
---
name: write-migration          # must equal the folder name, kebab-case
description: Create a safe, reversible database migration. Use when the user asks to add/alter/drop columns, tables or indexes.
---
# Write Migration
## Purpose
## When to use
## Required context
## Steps
## Expected output
## Validation checklist
```

- The `description` decides when the AI picks the skill, so name concrete
  trigger phrases.
- Put long reference material in sibling files (`skills/x/reference.md`) and
  link them from `SKILL.md`. They are loaded only when needed.
- New skills are installed in **every** project. To limit one to a stack, add
  it to `skill_requires()` in `scripts/lib/build.sh` (for example
  `write-migration) echo "database" ;;`).

### Change the approved stack

Edit `instructions/tech-stack.md` (CODEOWNERS should require architecture
sign-off), bump the MINOR version, and describe the change in
`CHANGELOG.md`. Projects pick it up on their next `update.sh`.

### Add a third-party skill (vendoring)

Never point engineers at a moving third-party branch. Vendor a reviewed,
pinned copy into `optional-skills/`:

```bash
./scripts/vendor-skill.sh https://github.com/cloudflare/security-audit-skill.git \
  <full-commit-sha> skills/security-audit
```

The script fetches exactly that commit, copies the skill without its test
files, includes the upstream `LICENSE`, and writes an `UPSTREAM` file
(repository, commit, date, license). Before merging:

1. Read every changed file (`git diff`), especially scripts the agent may run.
   Check for network calls, process spawning and instructions that conflict
   with `security.md`.
2. Run `./scripts/validate.sh && ./tests/run_tests.sh`.
3. Bump `VERSION`, add a `CHANGELOG.md` entry, and get platform and security
   review (CODEOWNERS enforces this).

To move to a newer upstream version, run the same command with the new
commit and review the diff. Projects pick it up with `update.sh`.

### Add a workflow

Create `workflows/<name>.md` with `description` and `argument-hint`
frontmatter. Setup generates `/name` commands for both tools that point at the
installed copy.

### Add a stack standard

Create `instructions/<name>.md`:

```markdown
---
description: Go service standards for errors, context, concurrency and testing.
globs: **/*.go,**/go.mod
alwaysApply: false
---
# Go Standards
```

Then teach detection about it: add a tag to `KNOWN_TAGS` and a signal in
`detect_stack()` (`scripts/lib/detect.sh`). The instruction file installs
when the tag with the same name is detected; for a different mapping, edit
`instruction_requires()` in `build.sh`. Add a detection test in
`tests/run_tests.sh`.

### Before opening the PR

```bash
./scripts/validate.sh     # frontmatter, required sections, secret scan
./tests/run_tests.sh      # install/update/uninstall behaviour
```

## 9. Administering company standards

- **Ownership**: `CODEOWNERS` routes every change to the AI platform team, and
  security-relevant files (`instructions/security.md`, `config/`) also to
  Security. Protect `main` and require CI.
- **Releases**: bump `VERSION` (MAJOR: needs manual project migration; MINOR:
  new standards/skills; PATCH: wording) and add a `CHANGELOG.md` entry. Tag
  releases (`git tag v1.1.0`) so teams can pin versions.
- **Rollout**: engineers pick up changes with `update.sh`. For broad changes,
  announce them with the changelog and ask teams to run update and commit the
  result, so the change shows up in a normal reviewable diff.
- **Keep standards lean.** In Claude Code, stack instructions are loaded into
  every session, so each line costs context. Prefer specific, checkable rules
  over general advice, and move long procedures into skills, which load only
  when used.
- **Feedback loop**: when a project repeatedly adds the same override to its
  `project-context.md`, consider promoting it to a company standard (or
  dropping the company rule).
- **Never** add credentials, internal hostnames that grant access, or customer
  data to this repository. `validate.sh` scans for common secret formats.

## 10. Troubleshooting

| Symptom | Cause / fix |
|---------|-------------|
| `error: project path does not exist` | Check the path; relative paths are resolved from your current directory. |
| `refusing to install into your home directory` / `…harness repository itself` | Pass the project directory, not `~` or the harness clone. |
| `no technology detected` | Manifests are deeper than 3 levels or unusual. Use `--stack python,django`. |
| A file shows `skipped` | A file you created already exists at that path. Rename yours, or rerun in a terminal (you'll be asked) or with `--force` (backup kept). |
| A file shows `conflict` on update | You edited a managed file. Merge `<file>.harness-new` and delete it, or use `--force`. Move project-specific tweaks to `project-context.md`. |
| `harness block markers are damaged` | An `ai-harness:begin`/`end` line was edited or deleted. Restore both marker lines (or delete the whole block) and rerun. |
| Cursor doesn't show skills or `/new-feature` | Update Cursor (skills and custom commands need a recent version) and reload the window. Check that `.claude/skills/` exists. |
| Claude Code ignores the standards | Run `/memory` to check `CLAUDE.md` is loaded. Start `claude` from the project root. If `.claude/CLAUDE.md` and `CLAUDE.md` both exist, the block lives in the one that existed first. |
| `could not fast-forward the harness checkout` | Your harness clone has diverged. `git -C <harness> status`, then reset to `origin/main` or run with `--no-fetch`. |
| `.claude/settings.json` was not created | You already had one. Merge rules from `.ai-harness/claude-settings.json`. |
| Want to preview a change | Add `--dry-run` to setup, update or uninstall. |

## 11. Security model

- **No secrets in the repo, no secrets installed.** The harness contains
  instructions only. `validate.sh` (and CI) scan for credential patterns.
- **Installers never execute project content.** Detection uses `find`/`grep`
  only. `.ai-harness/config` is parsed, never `source`d, and its values are
  validated against an allowlist (covered by a test that plants malicious
  `manage.py` and config files).
- **No network access** except the explicit `git pull` of the harness clone
  in `update.sh`, which uses your own Git credentials.
- **Least privilege by default for the AI.** Claude Code is denied reading
  secret files and running destructive commands, and must ask before pushes,
  migrations, infrastructure changes and network calls. Cursor is kept away
  from secret files via `.cursorignore`. Every tool is instructed to stop for
  approval before destructive, production or risky database operations.
- **Developer permissions stay separate.** The harness does not grant,
  store or share any access. Each engineer's tool uses their own credentials
  and project access.
- **Third-party skills are vendored, pinned and reviewed.** They are copied
  at an exact commit with provenance (`UPSTREAM`) and license, are opt-in per
  project, and changes need security review. Nothing is fetched from a third
  party at install time.
- **No customer data in prompts.** Repeated in the core rules, the security
  standard, and the debugging and database skills.

## 12. Compatibility and limitations

| Topic | Claude Code | Cursor |
|-------|-------------|--------|
| Instruction loading | All installed stack standards are imported every session (no path scoping) | Stack rules attach by file glob; the core rule is always on |
| Project context | Imported directly | Read by the agent on instruction (not injected) |
| Skills | Native `.claude/skills/` | Read from `.claude/skills/` (Cursor with Agent Skills support) |
| Commands | `$ARGUMENTS` placeholder, `@file` imports | Text after the command is appended; the stub tells the agent which file to read |
| Permission guard rails | Enforced by `.claude/settings.json` | `.cursorignore` only; command approval is a per-user Cursor setting (keep auto-run/YOLO off or allowlisted) |
| Other agents | — | Root `AGENTS.md` block works for any AGENTS.md-aware tool |

Known limitations of this version:

- Cursor rules embed the instruction text, so each standard exists in the
  project twice (`.ai-harness/instructions/` for Claude, `.cursor/rules/` for
  Cursor). Both are generated and checksummed, so they cannot drift silently.
- Instruction files are always loaded in Claude Code. Very large stacks
  (Django + React + DevOps) add roughly 1,000 lines of context.
- Stack detection is heuristic (file patterns up to depth 3). Use `--stack`
  for unusual layouts.
- Merging conflicts is manual (`.harness-new` files). There is no three-way
  merge.
- Windows is supported only through WSL or Git Bash (untested).
- The vendored `security-audit` skill needs Node.js for its validators and a
  model with sub-agent support. A full audit is expensive and, by its own
  account, a single run finds only part of what repeated runs find.
- Older Cursor versions without Agent Skills/custom commands still get rules
  and `AGENTS.md`, but not skills or `/commands`.
