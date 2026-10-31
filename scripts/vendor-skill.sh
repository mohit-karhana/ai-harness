#!/usr/bin/env bash
# Vendor (or re-pin) a third-party Agent Skill into optional-skills/.
# Admin tool: fetches an exact commit, copies the skill without its test
# files, and records provenance in UPSTREAM. Review the diff before committing.
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/vendor-skill.sh <git-url> <commit-sha> <path-in-repo> [name]

  git-url       Repository to fetch, e.g. https://github.com/cloudflare/security-audit-skill.git
  commit-sha    Full 40-character commit to pin (never a branch or tag)
  path-in-repo  Directory containing SKILL.md, e.g. skills/security-audit
  name          Destination name under optional-skills/ (default: basename of path)

Example (re-pin the Cloudflare security audit skill):
  scripts/vendor-skill.sh https://github.com/cloudflare/security-audit-skill.git \
    <new-sha> skills/security-audit
USAGE
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=lib/common.sh
. "$ROOT/scripts/lib/common.sh"

[ $# -ge 3 ] || { usage >&2; exit 1; }
case "$1" in -h|--help) usage; exit 0 ;; esac
URL="$1"; SHA="$2"; SUB="${3%/}"; NAME="${4:-$(basename "$SUB")}"
printf '%s' "$SHA" | grep -Eq '^[0-9a-f]{40}$' || die "commit must be a full 40-character SHA"
printf '%s' "$NAME" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' || die "name must be kebab-case"
[ ! -d "$ROOT/skills/$NAME" ] || die "skills/$NAME already exists as a core skill"
require_cmds git

WORK="$(make_temp_dir)"
# shellcheck disable=SC2064
trap "rm -rf '$WORK'" EXIT INT TERM
info "fetching $URL @ $SHA"
git -C "$WORK" init -q repo
git -C "$WORK/repo" fetch -q --depth 1 "$URL" "$SHA"
git -C "$WORK/repo" -c advice.detachedHead=false checkout -q FETCH_HEAD
SRC="$WORK/repo/$SUB"
[ -f "$SRC/SKILL.md" ] || die "$SUB/SKILL.md not found at that commit"
[ "$(fm_get "$SRC/SKILL.md" name)" = "$NAME" ] || die "SKILL.md name does not match '$NAME'"
LICENSE_FILE=""
for f in "$SRC/LICENSE" "$SRC/LICENSE.md" "$WORK/repo/LICENSE" "$WORK/repo/LICENSE.md" "$WORK/repo/LICENSE.txt"; do
  [ -f "$f" ] && { LICENSE_FILE="$f"; break; }
done
[ -n "$LICENSE_FILE" ] || die "no LICENSE file found; do not vendor unlicensed code"

DEST="$ROOT/optional-skills/$NAME"
rm -rf "$DEST"; mkdir -p "$DEST"
EXCLUDED=""
for f in "$SRC"/*; do
  b="$(basename "$f")"
  case "$b" in
    *.test.*|*.spec.*|__tests__|test|tests) EXCLUDED="${EXCLUDED:+$EXCLUDED, }$b"; continue ;;
  esac
  cp -R "$f" "$DEST/"
done
cp "$LICENSE_FILE" "$DEST/LICENSE"

cat > "$DEST/UPSTREAM" <<META
# Third-party skill vendored by ai-harness. Do not edit files in this
# directory by hand; re-pin with scripts/vendor-skill.sh instead.
repository: $URL
commit: $SHA
commit_date: $(git -C "$WORK/repo" log -1 --format=%cd --date=short)
path: $SUB
license: $(head -n 1 "$LICENSE_FILE" | sed 's/^[[:space:]]*//')
excluded: ${EXCLUDED:-none}
vendored_on: $(date +%Y-%m-%d)
META

ok "vendored optional-skills/$NAME @ ${SHA:0:12}"
log "Next: review 'git diff', run scripts/validate.sh and tests/run_tests.sh,"
log "update CHANGELOG.md and VERSION, then open a pull request."
