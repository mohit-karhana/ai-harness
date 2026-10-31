#!/usr/bin/env bash
# Installation / update / uninstall tests for ai-harness.
# Dependency-free (bash + coreutils + git). Works on macOS (bash 3.2) and Linux.
#
#   tests/run_tests.sh            run all tests
#   tests/run_tests.sh update     run tests whose name contains "update"
set -uo pipefail

HARNESS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
FILTER="${1:-}"
export NO_COLOR=1
PASSED=0; FAILED=0; FAILED_NAMES=""

# ---------------------------------------------------------------- helpers ---
fail() { printf '    FAIL: %s\n' "$*"; CURRENT_OK=0; }
assert_file()        { [ -f "$1" ] || fail "expected file: ${1#"$T"/}"; }
assert_no_path()     { [ ! -e "$1" ] || fail "expected no path: ${1#"$T"/}"; }
assert_contains()    { grep -qF -- "$2" "$1" 2>/dev/null || fail "${1#"$T"/} should contain: $2"; }
assert_not_contains(){ ! grep -qF -- "$2" "$1" 2>/dev/null || fail "${1#"$T"/} should not contain: $2"; }
assert_eq()          { [ "$1" = "$2" ] || fail "${3:-values differ}: expected '$2', got '$1'"; }
assert_count()       { local n; n="$(grep -cF -- "$2" "$1" 2>/dev/null || true)"; assert_eq "$n" "$3" "occurrences of '$2' in ${1#"$T"/}"; }

if command -v sha256sum >/dev/null 2>&1; then H() { sha256sum "$@"; }; else H() { shasum -a 256 "$@"; }; fi
snapshot() { (cd "$1" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 cat | H | awk '{print $1}'; find . | LC_ALL=C sort | H | awk '{print $1}'); }

new_project() { # new_project django|react|empty NAME -> path
  local p="$T/$2"
  case "$1" in
    empty) mkdir -p "$p" ;;
    *) cp -R "$HARNESS/examples/$1-project" "$p" ;;
  esac
  printf '%s' "$p"
}

# Run a harness script; output in $T/out, exit status in $RC.
run() { local script="$1"; shift; bash "$HARNESS/scripts/$script" --non-interactive "$@" > "$T/out" 2>&1; RC=$?; }
run_with() { local h="$1" script="$2"; shift 2; bash "$h/scripts/$script" --non-interactive "$@" > "$T/out" 2>&1; RC=$?; }

copy_harness() { # independent harness copy (not a git repo) at $T/harness
  mkdir -p "$T/harness"
  (cd "$HARNESS" && tar cf - --exclude .git --exclude tests . ) | (cd "$T/harness" && tar xf -)
}

detect() { (. "$HARNESS/scripts/lib/common.sh"; . "$HARNESS/scripts/lib/detect.sh"; detect_stack "$1"); }

# ------------------------------------------------------------- detection ---
test_detect_django() {
  local p; p="$(new_project django dj)"
  local tags; tags=" $(detect "$p") "
  for t in python django database api devops; do
    case "$tags" in *" $t "*) ;; *) fail "missing tag $t in:$tags" ;; esac
  done
  case "$tags" in *" react "*) fail "unexpected react tag" ;; esac
}

test_detect_react() {
  local p; p="$(new_project react rx)"
  assert_eq "$(detect "$p")" "javascript typescript react" "react tags"
}

test_detect_fastapi_example() {
  local p; p="$(new_project fastapi fa)"
  assert_eq "$(detect "$p")" "python fastapi database api devops" "fastapi tags"
}

test_detect_fastapi_and_express_monorepo() {
  local p; p="$(new_project empty mono)"
  mkdir -p "$p/backend" "$p/web"
  printf '[project]\ndependencies = ["fastapi>=0.110", "sqlalchemy>=2"]\n' > "$p/backend/pyproject.toml"
  printf '{"dependencies":{"express":"^4.19.0"}}\n' > "$p/web/package.json"
  local tags; tags=" $(detect "$p") "
  for t in python fastapi javascript node database api; do
    case "$tags" in *" $t "*) ;; *) fail "missing tag $t in:$tags" ;; esac
  done
  case "$tags" in *" django "*) fail "unexpected django tag" ;; esac
}

test_detect_ignores_node_modules() {
  local p; p="$(new_project empty nm)"
  mkdir -p "$p/node_modules/x"; printf '{"dependencies":{"react":"1"}}' > "$p/node_modules/x/package.json"
  assert_eq "$(detect "$p")" "" "tags for project with only node_modules"
}

# ----------------------------------------------------------------- setup ---
test_setup_django_installs_expected_components() {
  local p; p="$(new_project django dj)"
  run setup.sh "$p"
  assert_eq "$RC" 0 "exit code"
  for f in .ai-harness/AGENTS.md .ai-harness/VERSION .ai-harness/manifest .ai-harness/config \
           .ai-harness/instructions/django.md .ai-harness/instructions/python.md \
           .ai-harness/instructions/database.md .ai-harness/instructions/security.md \
           .ai-harness/workflows/new-feature.md .ai-harness/templates/feature-specification.md \
           .claude/skills/code-review/SKILL.md .claude/skills/code-review/review-checklist.md \
           .claude/skills/create-api/SKILL.md .claude/skills/database-optimization/SKILL.md \
           .claude/commands/new-feature.md .claude/settings.json \
           .cursor/rules/ai-harness-core.mdc .cursor/rules/ai-harness-django.mdc \
           .cursor/commands/bug-fix.md .cursorignore; do
    assert_file "$p/$f"
  done
  assert_no_path "$p/.ai-harness/instructions/react.md"
  assert_no_path "$p/.cursor/rules/ai-harness-react.mdc"
  # Instruction frontmatter is stripped for Claude, kept for Cursor.
  assert_not_contains "$p/.ai-harness/instructions/django.md" "alwaysApply:"
  assert_contains "$p/.cursor/rules/ai-harness-django.mdc" "globs: **/*.py"
  assert_contains "$p/.cursor/rules/ai-harness-security.mdc" "alwaysApply: true"
  assert_contains "$p/CLAUDE.md" "@.ai-harness/instructions/django.md"
  assert_contains "$p/CLAUDE.md" "@.ai-harness/project-context.md"
  assert_contains "$p/.claude/commands/new-feature.md" '$ARGUMENTS'
  assert_contains "$T/out" "Summary:"
}

test_setup_react_installs_only_relevant_components() {
  local p; p="$(new_project react rx)"
  run setup.sh "$p"
  assert_eq "$RC" 0 "exit code"
  assert_file "$p/.ai-harness/instructions/react.md"
  assert_file "$p/.ai-harness/instructions/javascript.md"
  assert_no_path "$p/.ai-harness/instructions/python.md"
  assert_no_path "$p/.ai-harness/instructions/django.md"
  assert_no_path "$p/.claude/skills/database-optimization"
  assert_no_path "$p/.claude/skills/create-api"
  assert_file "$p/.claude/skills/write-tests/SKILL.md"
  # Project context created from the template with detected values.
  assert_contains "$p/.ai-harness/project-context.md" "rx"
  assert_contains "$p/.ai-harness/project-context.md" "TypeScript, React"
  assert_not_contains "$p/.ai-harness/project-context.md" "{{PROJECT_NAME}}"
}

test_setup_fastapi_installs_expected_components() {
  local p; p="$(new_project fastapi fa)"
  run setup.sh "$p"
  assert_eq "$RC" 0 "exit code"
  for f in fastapi python api-development database devops tech-stack general security testing; do
    assert_file "$p/.ai-harness/instructions/$f.md"
    assert_file "$p/.cursor/rules/ai-harness-$f.mdc"
  done
  assert_no_path "$p/.ai-harness/instructions/django.md"
  assert_no_path "$p/.ai-harness/instructions/react.md"
  assert_file "$p/.claude/skills/create-api/SKILL.md"
  assert_file "$p/.claude/skills/database-optimization/SKILL.md"
  assert_contains "$p/CLAUDE.md" "@.ai-harness/instructions/fastapi.md"
  assert_contains "$p/.ai-harness/project-context.md" "Python, FastAPI"
}

test_setup_installs_approved_stack_everywhere() {
  local p; p="$(new_project react rx)"
  run setup.sh "$p"
  assert_file "$p/.ai-harness/instructions/tech-stack.md"
  assert_contains "$p/.cursor/rules/ai-harness-tech-stack.mdc" "alwaysApply: true"
  assert_contains "$p/.ai-harness/instructions/tech-stack.md" "Choosing between Django and FastAPI"
  # Always-on standards load first, in a fixed order.
  assert_eq "$(grep '^@.ai-harness/instructions/' "$p/CLAUDE.md" | head -4 | tr '\n' ' ')" \
    "@.ai-harness/instructions/general.md @.ai-harness/instructions/tech-stack.md @.ai-harness/instructions/security.md @.ai-harness/instructions/testing.md " "import order"
  local e; e="$(new_project empty bare)"
  run setup.sh "$e"
  assert_file "$e/.ai-harness/instructions/tech-stack.md"
}

test_setup_preserves_existing_instructions() {
  local p; p="$(new_project django dj)"
  local before; before="$(cat "$p/CLAUDE.md")"
  run setup.sh "$p"
  # Original content is still at the top, untouched.
  assert_eq "$(head -n "$(printf '%s\n' "$before" | wc -l)" "$p/CLAUDE.md")" "$before" "CLAUDE.md prefix"
  assert_count "$p/CLAUDE.md" "ai-harness:begin" 1
  # User-filled project context is never replaced.
  assert_contains "$p/.ai-harness/project-context.md" "Healthysure Policies Service (example)"
  local rp; rp="$(new_project react rx)"
  run setup.sh "$rp"
  assert_contains "$rp/AGENTS.md" "Never display a full policy number"
  assert_contains "$rp/AGENTS.md" "Company AI standards (ai-harness)"
  # React project has no CLAUDE.md: one is created importing AGENTS.md.
  assert_contains "$rp/CLAUDE.md" "@AGENTS.md"
}

test_setup_is_idempotent() {
  local p; p="$(new_project django dj)"
  run setup.sh "$p"; local s1; s1="$(snapshot "$p")"
  run setup.sh "$p"; local s2; s2="$(snapshot "$p")"
  assert_eq "$RC" 0 "second run exit code"
  assert_eq "$s2" "$s1" "project snapshot after second run"
  assert_contains "$T/out" "0 installed, 0 updated, 0 removed"
  assert_count "$p/CLAUDE.md" "ai-harness:begin" 1
  assert_count "$p/AGENTS.md" "ai-harness:begin" 1
  assert_count "$p/.cursorignore" "ai-harness:begin" 1
}

test_setup_never_overwrites_user_created_files() {
  local p; p="$(new_project react rx)"
  mkdir -p "$p/.claude/skills/code-review" "$p/.cursor/commands"
  printf 'my own review skill\n' > "$p/.claude/skills/code-review/SKILL.md"
  printf 'my bug-fix command\n' > "$p/.cursor/commands/bug-fix.md"
  printf '{"permissions":{"allow":["Bash(npm test)"]}}\n' > "$p/.claude/settings.json" ; mkdir -p "$p/.claude"
  run setup.sh "$p"
  assert_eq "$RC" 0 "exit code"
  assert_eq "$(cat "$p/.claude/skills/code-review/SKILL.md")" "my own review skill" "user skill"
  assert_eq "$(cat "$p/.cursor/commands/bug-fix.md")" "my bug-fix command" "user command"
  assert_contains "$p/.claude/settings.json" "npm test"
  assert_contains "$T/out" "skipped     .claude/skills/code-review/SKILL.md"
  assert_not_contains "$p/.ai-harness/manifest" ".claude/skills/code-review/SKILL.md"
  # Recommended settings are still delivered for manual merging.
  assert_file "$p/.ai-harness/claude-settings.json"
}

test_setup_force_replaces_user_files_with_backup() {
  local p; p="$(new_project react rx)"
  mkdir -p "$p/.cursor/commands"; printf 'mine\n' > "$p/.cursor/commands/bug-fix.md"
  run setup.sh --force "$p"
  assert_contains "$p/.cursor/commands/bug-fix.md" ".ai-harness/workflows/bug-fix.md"
  ls "$p/.cursor/commands/" | grep -q 'bug-fix.md.harness-backup-' || fail "backup not created"
}

test_setup_accepts_relative_path() {
  new_project react rel >/dev/null
  (cd "$T" && bash "$HARNESS/scripts/setup.sh" --non-interactive ./rel > "$T/out" 2>&1); RC=$?
  assert_eq "$RC" 0 "exit code"
  assert_file "$T/rel/.ai-harness/manifest"
  (cd "$T/rel" && bash "$HARNESS/scripts/setup.sh" --non-interactive . > "$T/out" 2>&1); RC=$?
  assert_eq "$RC" 0 "exit code for '.'"
}

test_setup_rejects_invalid_paths() {
  run setup.sh "$T/does-not-exist"; [ "$RC" -ne 0 ] || fail "missing dir accepted"
  assert_contains "$T/out" "does not exist"
  : > "$T/a-file"
  run setup.sh "$T/a-file"; [ "$RC" -ne 0 ] || fail "file accepted"
  run setup.sh "$HARNESS"; [ "$RC" -ne 0 ] || fail "harness itself accepted"
  run setup.sh "$HARNESS/examples/react-project"; [ "$RC" -ne 0 ] || fail "path inside harness accepted"
  run setup.sh /; [ "$RC" -ne 0 ] || fail "root accepted"
  run setup.sh; [ "$RC" -ne 0 ] || fail "no path accepted"
  run setup.sh --bogus "$T"; [ "$RC" -ne 0 ] || fail "unknown flag accepted"
  run setup.sh --stack cobol "$T"; [ "$RC" -ne 0 ] || fail "unknown stack accepted"
  run setup.sh --tools 'claude;rm' "$T"; [ "$RC" -ne 0 ] || fail "unsafe tools value accepted"
}

test_setup_dry_run_writes_nothing() {
  local p; p="$(new_project django dj)"; local s1; s1="$(snapshot "$p")"
  run setup.sh --dry-run "$p"
  assert_eq "$RC" 0 "exit code"
  assert_eq "$(snapshot "$p")" "$s1" "snapshot after dry run"
  assert_contains "$T/out" "would be installed"
}

test_setup_stack_and_tools_overrides() {
  local p; p="$(new_project empty ov)"
  run setup.sh --stack fastapi --tools claude "$p"
  assert_eq "$RC" 0 "exit code"
  assert_file "$p/.ai-harness/instructions/fastapi.md"
  assert_file "$p/.ai-harness/instructions/api-development.md"
  assert_no_path "$p/.cursor"
  assert_no_path "$p/.cursorignore"
  assert_file "$p/.claude/skills/create-api/SKILL.md"
  assert_contains "$p/.ai-harness/config" "STACK=fastapi"
  assert_contains "$p/.ai-harness/config" "TOOLS=claude"
}

test_setup_uses_existing_dot_claude_claude_md() {
  local p; p="$(new_project empty dc)"
  mkdir -p "$p/.claude"; printf '# team notes\n' > "$p/.claude/CLAUDE.md"
  run setup.sh "$p"
  assert_contains "$p/.claude/CLAUDE.md" "@.ai-harness/AGENTS.md"
  assert_no_path "$p/CLAUDE.md"
}

test_optional_skills_are_opt_in() {
  local p; p="$(new_project django dj)"
  run setup.sh "$p"
  assert_no_path "$p/.claude/skills/security-audit"
  assert_contains "$p/.ai-harness/config" "INCLUDE_SKILLS="
  assert_contains "$p/.ai-harness/config" "security-audit"   # listed as available
}

test_setup_with_optional_skill_and_lifecycle() {
  local p; p="$(new_project django dj)"
  run setup.sh --with-skills security-audit "$p"
  assert_eq "$RC" 0 "exit code"
  local d="$p/.claude/skills/security-audit"
  for f in SKILL.md LICENSE UPSTREAM HUNTING.md report-schema.json validate-findings.cjs validate-coverage-ledger.cjs; do
    assert_file "$d/$f"
  done
  assert_no_path "$d/validate-findings.test.cjs"
  assert_contains "$d/UPSTREAM" "commit: c1c8a8c1471069fb0e188eeaff69b8e8db6564a8"
  assert_contains "$d/LICENSE" "Cloudflare"
  assert_contains "$p/.ai-harness/config" "INCLUDE_SKILLS=security-audit"
  # Persisted: a plain update keeps it and changes nothing.
  run update.sh --no-fetch "$p"
  assert_file "$d/SKILL.md"
  assert_contains "$T/out" "0 installed, 0 updated, 0 removed"
  # Removing it from config removes the unmodified files on update.
  sed -i.bak 's/^INCLUDE_SKILLS=.*/INCLUDE_SKILLS=/' "$p/.ai-harness/config" && rm -f "$p/.ai-harness/config.bak"
  run update.sh --no-fetch "$p"
  assert_no_path "$d"
  assert_file "$p/.claude/skills/code-review/SKILL.md"
}

test_unknown_optional_skill_rejected() {
  local p; p="$(new_project react rx)"
  run setup.sh --with-skills does-not-exist "$p"
  [ "$RC" -ne 0 ] || fail "unknown optional skill accepted"
  assert_contains "$T/out" "unknown optional skill"
  assert_no_path "$p/.ai-harness"
}

test_validate_requires_pinned_vendored_skill() {
  copy_harness
  sed -i.bak 's/^commit: .*/commit: main/' "$T/harness/optional-skills/security-audit/UPSTREAM"
  bash "$T/harness/scripts/validate.sh" > "$T/out" 2>&1; RC=$?
  [ "$RC" -ne 0 ] || fail "unpinned vendored skill accepted"
  assert_contains "$T/out" "pinned 40-character SHA"
  rm -f "$T/harness/optional-skills/security-audit/UPSTREAM.bak" "$T/harness/optional-skills/security-audit/LICENSE"
  bash "$T/harness/scripts/validate.sh" > "$T/out" 2>&1
  assert_contains "$T/out" "must include its LICENSE"
}

# ---------------------------------------------------------------- update ---
test_update_requires_installation() {
  local p; p="$(new_project react rx)"
  run update.sh --no-fetch "$p"
  [ "$RC" -ne 0 ] || fail "update on uninstalled project should fail"
  assert_contains "$T/out" "run scripts/setup.sh first"
}

test_update_propagates_central_changes() {
  copy_harness; local h="$T/harness"
  local p; p="$(new_project django dj)"
  run_with "$h" setup.sh "$p"
  printf '\n## New rule\n- Use UUID primary keys for new tables.\n' >> "$h/instructions/django.md"
  printf '\nExtra review step.\n' >> "$h/skills/code-review/SKILL.md"
  local v_old; v_old="$(cat "$h/VERSION")"
  echo "9.9.9" > "$h/VERSION"
  run_with "$h" update.sh --no-fetch "$p"
  assert_eq "$RC" 0 "exit code"
  assert_contains "$p/.ai-harness/instructions/django.md" "Use UUID primary keys"
  assert_contains "$p/.cursor/rules/ai-harness-django.mdc" "Use UUID primary keys"
  assert_contains "$p/.claude/skills/code-review/SKILL.md" "Extra review step."
  assert_eq "$(cat "$p/.ai-harness/VERSION")" "9.9.9" "installed version"
  assert_contains "$T/out" "$v_old → 9.9.9"
  assert_contains "$T/out" "0 conflicts"
}

test_update_reports_conflicts_and_keeps_local_edits() {
  copy_harness; local h="$T/harness"
  local p; p="$(new_project django dj)"
  run_with "$h" setup.sh "$p"
  printf '\nLOCAL TEAM TWEAK\n' >> "$p/.ai-harness/instructions/python.md"
  printf '\nUPSTREAM CHANGE\n' >> "$h/instructions/python.md"
  run_with "$h" update.sh --no-fetch "$p"
  assert_eq "$RC" 0 "exit code"
  assert_contains "$p/.ai-harness/instructions/python.md" "LOCAL TEAM TWEAK"
  assert_not_contains "$p/.ai-harness/instructions/python.md" "UPSTREAM CHANGE"
  assert_contains "$p/.ai-harness/instructions/python.md.harness-new" "UPSTREAM CHANGE"
  assert_contains "$T/out" "conflict    .ai-harness/instructions/python.md"
  # The unmodified Cursor copy is updated normally.
  assert_contains "$p/.cursor/rules/ai-harness-python.mdc" "UPSTREAM CHANGE"
  # Still a conflict on the next run (not silently resolved).
  run_with "$h" update.sh --no-fetch "$p"
  assert_contains "$T/out" "conflict    .ai-harness/instructions/python.md"
  # --force accepts upstream and keeps a backup.
  run_with "$h" update.sh --no-fetch --force "$p"
  assert_contains "$p/.ai-harness/instructions/python.md" "UPSTREAM CHANGE"
  ls "$p/.ai-harness/instructions/" | grep -q 'python.md.harness-backup-' || fail "no backup after --force"
}

test_update_preserves_project_content() {
  copy_harness; local h="$T/harness"
  local p; p="$(new_project react rx)"
  run_with "$h" setup.sh "$p"
  printf '\n## Important Rules\n- Feature flags via LaunchDarkly only.\n' >> "$p/.ai-harness/project-context.md"
  printf '\n- Added after setup by the team.\n' >> "$p/AGENTS.md"
  printf '\nUPSTREAM\n' >> "$h/AGENTS.md"
  run_with "$h" update.sh --no-fetch "$p"
  assert_contains "$p/.ai-harness/project-context.md" "LaunchDarkly"
  assert_contains "$p/AGENTS.md" "Added after setup by the team."
  assert_contains "$p/AGENTS.md" "Never display a full policy number"
  assert_contains "$p/.ai-harness/AGENTS.md" "UPSTREAM"
}

test_update_detects_edited_managed_block() {
  copy_harness; local h="$T/harness"
  local p; p="$(new_project django dj)"
  run_with "$h" setup.sh "$p"
  # Edit inside the block, then make upstream change the block (new instruction).
  awk '{print} /^@.ai-harness\/AGENTS.md$/ {print "@docs/local-extra.md"}' "$p/CLAUDE.md" > "$T/c" && cat "$T/c" > "$p/CLAUDE.md"
  printf -- '---\ndescription: Celery standards\nglobs: **/tasks.py\nalwaysApply: false\n---\n# Celery\n- Tasks must be idempotent.\n' > "$h/instructions/celery.md"
  # Make the new instruction always-on (instruction_requires in build.sh).
  sed -i.bak 's/^    general|/    celery|general|/' "$h/scripts/lib/build.sh"
  grep -q '^    celery|general|' "$h/scripts/lib/build.sh" || fail "test setup: could not patch build.sh"
  run_with "$h" update.sh --no-fetch "$p"
  assert_contains "$p/CLAUDE.md" "@docs/local-extra.md"
  assert_not_contains "$p/CLAUDE.md" "@.ai-harness/instructions/celery.md"
  assert_contains "$p/CLAUDE.md.harness-new-block" "@.ai-harness/instructions/celery.md"
  assert_contains "$T/out" "conflict    CLAUDE.md"
  # New files from the same release are still installed.
  assert_file "$p/.ai-harness/instructions/celery.md"
}

test_update_removes_retired_files_but_keeps_edited_ones() {
  copy_harness; local h="$T/harness"
  local p; p="$(new_project django dj)"
  run_with "$h" setup.sh "$p"
  printf '\nlocal note\n' >> "$p/.claude/skills/refactor-code/SKILL.md"
  rm -rf "$h/skills/debug-issue" "$h/skills/refactor-code"
  run_with "$h" update.sh --no-fetch "$p"
  assert_no_path "$p/.claude/skills/debug-issue"
  assert_contains "$T/out" "removed     .claude/skills/debug-issue/SKILL.md"
  assert_file "$p/.claude/skills/refactor-code/SKILL.md"
  assert_contains "$T/out" "kept        .claude/skills/refactor-code/SKILL.md"
}

test_update_honours_config_exclusions() {
  local p; p="$(new_project django dj)"
  run setup.sh "$p"
  sed -i.bak 's/^EXCLUDE_WORKFLOWS=.*/EXCLUDE_WORKFLOWS=deployment/' "$p/.ai-harness/config" && rm -f "$p/.ai-harness/config.bak"
  run update.sh --no-fetch "$p"
  assert_no_path "$p/.claude/commands/deployment.md"
  assert_no_path "$p/.cursor/commands/deployment.md"
  assert_no_path "$p/.ai-harness/workflows/deployment.md"
  assert_file "$p/.claude/commands/bug-fix.md"
}

test_update_fetches_latest_harness_with_git() {
  command -v git >/dev/null 2>&1 || { echo "    (skipped: git not installed)"; return 0; }
  local g="git -c user.name=test -c user.email=test@example.com -c init.defaultBranch=main"
  copy_harness
  $g -C "$T/harness" init -q && $g -C "$T/harness" add -A && $g -C "$T/harness" commit -qm init
  $g clone -q --bare "$T/harness" "$T/origin.git"
  $g clone -q "$T/origin.git" "$T/engineer-clone"
  $g clone -q "$T/origin.git" "$T/admin-clone"
  local p; p="$(new_project react rx)"
  run_with "$T/engineer-clone" setup.sh "$p"
  # Admin publishes a new standard.
  printf '\n- Prefer server components where supported.\n' >> "$T/admin-clone/instructions/react.md"
  echo "1.2.0" > "$T/admin-clone/VERSION"
  $g -C "$T/admin-clone" commit -qam "react: new rule" && $g -C "$T/admin-clone" push -q
  # Engineer updates; update.sh pulls and re-executes itself.
  run_with "$T/engineer-clone" update.sh "$p"
  assert_eq "$RC" 0 "exit code"
  assert_contains "$p/.ai-harness/instructions/react.md" "Prefer server components"
  assert_eq "$(cat "$p/.ai-harness/VERSION")" "1.2.0" "installed version"
  assert_contains "$T/out" "harness updated"
}

# ------------------------------------------------------------- uninstall ---
test_uninstall_restores_project() {
  local p; p="$(new_project django dj)"
  local claude_before; claude_before="$(cat "$p/CLAUDE.md")"
  run setup.sh "$p"
  run uninstall.sh "$p"
  assert_eq "$RC" 0 "exit code"
  assert_eq "$(cat "$p/CLAUDE.md")" "$claude_before" "CLAUDE.md after uninstall"
  assert_no_path "$p/AGENTS.md"          # created by harness, now empty -> removed
  assert_no_path "$p/.cursorignore"
  assert_no_path "$p/.cursor"
  assert_no_path "$p/.claude"
  assert_no_path "$p/.ai-harness/manifest"
  assert_file "$p/.ai-harness/project-context.md"   # user-owned, kept
  run uninstall.sh "$p"; [ "$RC" -ne 0 ] || fail "second uninstall should report not installed"
}

test_uninstall_keeps_modified_files_and_purge() {
  local p; p="$(new_project react rx)"
  run setup.sh "$p"
  printf '\nteam addition\n' >> "$p/.claude/skills/write-tests/SKILL.md"
  run uninstall.sh --purge "$p"
  assert_contains "$p/.claude/skills/write-tests/SKILL.md" "team addition"
  assert_no_path "$p/.claude/skills/code-review"
  assert_no_path "$p/.ai-harness/project-context.md"
  assert_contains "$p/AGENTS.md" "Never display a full policy number"
  assert_not_contains "$p/AGENTS.md" "ai-harness"
}

# ---------------------------------------------------------------- content ---
test_validate_passes() {
  bash "$HARNESS/scripts/validate.sh" > "$T/out" 2>&1; RC=$?
  assert_eq "$RC" 0 "validate.sh exit code"
}

test_validate_catches_bad_skill() {
  copy_harness
  printf -- '---\nname: Wrong Name\n---\nbody\n' > "$T/harness/skills/code-review/SKILL.md"
  bash "$T/harness/scripts/validate.sh" > "$T/out" 2>&1; RC=$?
  [ "$RC" -ne 0 ] || fail "invalid skill accepted"
  assert_contains "$T/out" "frontmatter name must equal folder name"
}

test_scripts_never_execute_project_files() {
  local p; p="$(new_project django dj)"
  printf '#!/bin/sh\ntouch "%s/PWNED"\n' "$T" > "$p/manage.py"; chmod +x "$p/manage.py"
  printf 'STACK=auto\nTOOLS=claude,cursor\n$(touch %s/PWNED2)\n' "$T" > "$T/cfg"
  mkdir -p "$p/.ai-harness"; cp "$T/cfg" "$p/.ai-harness/config"
  run setup.sh "$p"
  assert_no_path "$T/PWNED"
  assert_no_path "$T/PWNED2"
}

# ---------------------------------------------------------------- runner ---
TESTS="$(declare -F | awk '{print $3}' | grep '^test_' )"
for t in $TESTS; do
  case "$t" in *"$FILTER"*) ;; *) continue ;; esac
  T="$(mktemp -d "${TMPDIR:-/tmp}/ai-harness-test.XXXXXX")"
  T="$(cd "$T" && pwd -P)"
  CURRENT_OK=1
  printf '%s\n' "$t"
  "$t"
  if [ "$CURRENT_OK" = 1 ]; then
    PASSED=$((PASSED + 1)); printf '    ok\n'
  else
    FAILED=$((FAILED + 1)); FAILED_NAMES="$FAILED_NAMES $t"
    printf '    --- last command output ---\n'; sed 's/^/    | /' "$T/out" 2>/dev/null | tail -25
  fi
  rm -rf "$T"
done

printf '\n%d passed, %d failed\n' "$PASSED" "$FAILED"
[ "$FAILED" -eq 0 ] || { printf 'failed:%s\n' "$FAILED_NAMES"; exit 1; }
