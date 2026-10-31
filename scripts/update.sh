#!/usr/bin/env bash
# Update a project's harness files to the latest harness version.
# Local edits to harness-managed files are never overwritten silently.
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/update.sh [options] <project-path>

Pulls the latest harness (git pull --ff-only on this checkout), then refreshes
centrally managed instructions, skills and workflows in the project.
Project context, config and all developer-owned content are preserved;
locally modified harness files are reported as conflicts.

Options:
  --no-fetch                 Do not pull; apply this checkout as it is
  --stack/--tools/--with-skills/--exclude-skills/--exclude-workflows
                             Override .ai-harness/config for this run
  --dry-run                  Show what would change without writing anything
  --force                    Replace locally modified files (backups are kept)
  --non-interactive          Never prompt
  -h, --help                 Show this help

To pin a version, check out a tag in the harness clone
(git checkout v1.2.0) and run with --no-fetch.
USAGE
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/apply.sh
. "$SCRIPT_DIR/lib/apply.sh"
parse_common_args "$@"
[ -n "$PROJECT_ARG" ] || { usage >&2; exit 1; }

fetch_harness() {
  local top before after
  if ! command -v git >/dev/null 2>&1; then
    warn "git not found; using the local harness copy"; return 0
  fi
  top="$(git -C "$HARNESS_ROOT" rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -z "$top" ] || [ "$(resolve_dir "$top")" != "$HARNESS_ROOT" ]; then
    warn "harness at $HARNESS_ROOT is not a git clone; using it as-is"; return 0
  fi
  if ! git -C "$HARNESS_ROOT" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    info "harness checkout has no upstream branch (pinned tag?); using it as-is"; return 0
  fi
  if [ -n "$(git -C "$HARNESS_ROOT" status --porcelain)" ]; then
    warn "harness checkout has uncommitted changes; skipping pull (commit/stash them, or use --no-fetch)"
    return 0
  fi
  before="$(git -C "$HARNESS_ROOT" rev-parse HEAD)"
  info "fetching latest harness ($(git -C "$HARNESS_ROOT" rev-parse --abbrev-ref '@{u}'))"
  git -C "$HARNESS_ROOT" pull --ff-only --quiet ||
    die "could not fast-forward the harness checkout; resolve it manually or rerun with --no-fetch"
  after="$(git -C "$HARNESS_ROOT" rev-parse HEAD)"
  if [ "$before" != "$after" ]; then
    info "harness updated ${before:0:8} → ${after:0:8}; restarting with the new scripts"
    exec bash "$SCRIPT_DIR/update.sh" --no-fetch "$@"
  fi
}

[ "$NO_FETCH" = 1 ] || fetch_harness "$@"
harness_apply update
