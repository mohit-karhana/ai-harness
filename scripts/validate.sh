#!/usr/bin/env bash
# Validate harness content before a release (run by admins and CI).
# Checks frontmatter of instructions, skills and workflows, template
# placeholders, VERSION format, and scans for committed secrets.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=lib/common.sh
. "$ROOT/scripts/lib/common.sh"

ERRORS=0
fail() { err "$*"; ERRORS=$((ERRORS + 1)); }

grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' "$ROOT/VERSION" || fail "VERSION must be semver (X.Y.Z)"

for f in "$ROOT"/instructions/*.md; do
  n="instructions/$(basename "$f")"
  has_frontmatter "$f" || { fail "$n: missing frontmatter"; continue; }
  [ -n "$(fm_get "$f" description)" ] || fail "$n: missing description"
  grep -q '^globs:' "$f" || fail "$n: missing globs key (may be empty)"
  case "$(fm_get "$f" alwaysApply)" in true|false) ;; *) fail "$n: alwaysApply must be true or false" ;; esac
  [ "$(fm_get "$f" alwaysApply)" = true ] || [ -n "$(fm_get "$f" globs)" ] ||
    fail "$n: alwaysApply is false and globs is empty, so Cursor would never auto-attach it"
done

for d in "$ROOT"/skills/*/; do
  name="$(basename "$d")"; f="$d/SKILL.md"
  [ -f "$f" ] || { fail "skills/$name: missing SKILL.md"; continue; }
  has_frontmatter "$f" || { fail "skills/$name/SKILL.md: missing frontmatter"; continue; }
  [ "$(fm_get "$f" name)" = "$name" ] || fail "skills/$name: frontmatter name must equal folder name"
  printf '%s' "$name" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' || fail "skills/$name: name must be kebab-case"
  [ "${#name}" -le 64 ] || fail "skills/$name: name longer than 64 characters"
  desc="$(fm_get "$f" description)"
  [ -n "$desc" ] || fail "skills/$name: missing description"
  [ "${#desc}" -le 1024 ] || fail "skills/$name: description longer than 1024 characters"
  for section in "## Purpose" "## When to use" "## Required context" "## Steps" "## Expected output" "## Validation checklist"; do
    grep -q "^$section" "$f" || fail "skills/$name: missing section '$section'"
  done
done

# Opt-in skills: native SKILL.md frontmatter plus provenance and license.
# Vendored third-party skills keep their own section layout.
for d in "$ROOT"/optional-skills/*/; do
  [ -d "$d" ] || continue
  name="$(basename "$d")"; f="$d/SKILL.md"
  [ -f "$f" ] || { fail "optional-skills/$name: missing SKILL.md"; continue; }
  [ "$(fm_get "$f" name)" = "$name" ] || fail "optional-skills/$name: frontmatter name must equal folder name"
  [ -n "$(fm_get "$f" description)" ] || fail "optional-skills/$name: missing description"
  [ ! -d "$ROOT/skills/$name" ] || fail "optional-skills/$name: same name as a core skill"
  if [ -f "$d/UPSTREAM" ]; then
    grep -Eq '^commit: [0-9a-f]{40}$' "$d/UPSTREAM" || fail "optional-skills/$name/UPSTREAM: commit must be a pinned 40-character SHA"
    grep -Eq '^repository: ' "$d/UPSTREAM" || fail "optional-skills/$name/UPSTREAM: missing repository"
    [ -f "$d/LICENSE" ] || fail "optional-skills/$name: vendored skill must include its LICENSE"
  fi
done

for f in "$ROOT"/workflows/*.md; do
  n="workflows/$(basename "$f")"
  has_frontmatter "$f" || { fail "$n: missing frontmatter"; continue; }
  [ -n "$(fm_get "$f" description)" ] || fail "$n: missing description"
done

t="$ROOT/templates/project-context.md"
[ -f "$t" ] || fail "templates/project-context.md is required"
for p in '{{PROJECT_NAME}}' '{{TECHNOLOGY}}'; do
  grep -qF "$p" "$t" || fail "templates/project-context.md: missing placeholder $p"
done

# Secret scan: committed credentials must never reach engineers' projects.
if grep -rIEn --exclude-dir=.git --exclude-dir=tests \
     -e 'AKIA[0-9A-Z]{16}' -e '-----BEGIN [A-Z ]*PRIVATE KEY-----' \
     -e 'xox[baprs]-[0-9A-Za-z-]{10,}' -e 'ghp_[0-9A-Za-z]{36}' -e 'sk-[A-Za-z0-9]{32,}' \
     "$ROOT" ; then
  fail "possible secret found (see above)"
fi

if [ "$ERRORS" -gt 0 ]; then
  err "$ERRORS validation error(s)"; exit 1
fi
ok "harness content is valid ($(ls "$ROOT"/instructions/*.md | wc -l | tr -d ' ') instructions, $(ls -d "$ROOT"/skills/*/ | wc -l | tr -d ' ') skills, $(ls -d "$ROOT"/optional-skills/*/ 2>/dev/null | wc -l | tr -d ' ') opt-in skills, $(ls "$ROOT"/workflows/*.md | wc -l | tr -d ' ') workflows)"
