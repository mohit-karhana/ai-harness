#!/usr/bin/env bash
# Remove the AI Engineering Harness from a project.
# Only removes files and blocks the harness wrote and that are unmodified.
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/uninstall.sh [options] <project-path>

Removes harness-managed files and the harness blocks inside AGENTS.md,
CLAUDE.md and .cursorignore. Content you wrote is preserved. Files you
modified are kept unless --force is given.

Options:
  --purge            Also delete user-owned .ai-harness/project-context.md and config
  --force            Also remove harness files/blocks that were modified locally
  --dry-run          Show what would be removed without deleting anything
  -h, --help         Show this help
USAGE
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HARNESS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/reconcile.sh
. "$SCRIPT_DIR/lib/reconcile.sh"

PROJECT_ARG=""; FORCE=0; DRY_RUN=0; PURGE=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --purge) PURGE=1 ;;
    --force) FORCE=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --non-interactive|--no-input) INTERACTIVE=0 ;;
    -*) die "unknown option: $1 (see --help)" ;;
    *) [ -z "$PROJECT_ARG" ] || die "only one project path may be given"; PROJECT_ARG="$1" ;;
  esac
  shift
done
[ -n "$PROJECT_ARG" ] || { usage >&2; exit 1; }

PROJECT="$(validate_project_dir "$PROJECT_ARG" "$HARNESS_ROOT")" || exit 1
MANIFEST="$PROJECT/$MANIFEST_REL"
[ -f "$MANIFEST" ] || die "ai-harness is not installed in $PROJECT (no $MANIFEST_REL)"

WORK="$(make_temp_dir)"
# shellcheck disable=SC2064  # expand $WORK now, on purpose
trap "rm -rf '$WORK'" EXIT INT TERM
REPORT="$WORK/report"; : > "$REPORT"

log "${C_BLD}ai-harness uninstall${C_RST} → $PROJECT"
TAB="$(printf '\t')"
while IFS="$TAB" read -r kind rel hash extra; do
  dst="$PROJECT/$rel"
  case "$kind" in
    file)
      [ -e "$dst" ] || continue
      if [ "$(hash_file "$dst")" = "$hash" ] || [ "$FORCE" = 1 ]; then
        [ "$DRY_RUN" = 1 ] || { rm -f "$dst"; prune_empty_dirs "$PROJECT" "$rel"; }
        _report removed "$rel"
      else
        _report kept "$rel" "modified locally (use --force to remove)"
      fi
      # Leftover conflict artefacts from earlier updates.
      if [ -e "$dst.harness-new" ]; then
        [ "$DRY_RUN" = 1 ] || rm -f "$dst.harness-new"
        _report removed "$rel.harness-new"
      fi
      ;;
    block)
      [ -e "$dst" ] || continue
      _remove_block "$rel" "$hash" "$extra" removed
      ;;
  esac
done < "$MANIFEST"

for rel in .ai-harness/project-context.md .ai-harness/config; do
  [ -e "$PROJECT/$rel" ] || continue
  if [ "$PURGE" = 1 ]; then
    [ "$DRY_RUN" = 1 ] || rm -f "$PROJECT/$rel"
    _report removed "$rel" "purged"
  else
    _report kept "$rel" "user-owned (use --purge to delete)"
  fi
done

if [ "$DRY_RUN" != 1 ]; then
  rm -f "$MANIFEST"
  rmdir "$PROJECT/.ai-harness" 2>/dev/null || true
fi
print_report
