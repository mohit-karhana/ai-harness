#!/usr/bin/env bash
# Integrate the AI Engineering Harness into an existing project.
# Safe to run repeatedly: unchanged files are left alone and developer files
# are never overwritten without approval.
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/setup.sh [options] <project-path>

Installs company AI standards, skills and workflows into a project for
Claude Code and Cursor. The project path may be absolute or relative.

Options:
  --stack <tags>             Comma-separated stack tags instead of auto-detection
                             (python,django,fastapi,flask,javascript,typescript,
                              node,react,nextjs,database,api,devops)
  --tools <list>             AI tools to configure: claude,cursor (default: both)
  --with-skills <list>       Opt-in skills to add (e.g. security-audit)
  --exclude-skills <list>    Skills not to install (e.g. create-api)
  --exclude-workflows <list> Workflows not to install (e.g. deployment)
  --dry-run                  Show what would change without writing anything
  --force                    Replace conflicting files (backups are kept)
  --non-interactive          Never prompt; skip files that would need approval
  -h, --help                 Show this help

Examples:
  scripts/setup.sh ../healthysure-backend
  scripts/setup.sh --dry-run ~/code/web-app
  scripts/setup.sh --stack django,devops --tools claude /srv/projects/api
  scripts/setup.sh --with-skills security-audit ../healthysure-backend
USAGE
}

# shellcheck source=lib/apply.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib/apply.sh"
parse_common_args "$@"
[ "$NO_FETCH" = 0 ] || die "--no-fetch is only valid for update.sh"
[ -n "$PROJECT_ARG" ] || { usage >&2; exit 1; }
harness_apply setup
