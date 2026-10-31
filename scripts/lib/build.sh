#!/usr/bin/env bash
# Stage builder: renders everything the harness wants a project to contain
# into $STAGE (a temp dir mirroring the project layout) and lists it in
# $STAGE/.entries. The reconciler then compares the stage with the project.
#
# .entries format (tab separated):
#   file   <relpath>  <policy>     policy: managed | create-only | user
#   block  <relpath>  <style>      style:  html | hash
#
#   managed      harness owns the file; updated when unmodified, conflict otherwise
#   create-only  created if absent, never forced afterwards (e.g. settings.json)
#   user         created once from a template, then owned by the developer
#   block        a marked region inside a developer-owned file

# Instruction file -> required stack tag ("" = always installed).
instruction_requires() {
  case "$1" in
    general|tech-stack|security|testing) echo "" ;;
    api-development)          echo "api" ;;
    *)                        echo "$1" ;;   # python, django, react, database, devops...
  esac
}

# Skill -> required stack tag ("" = always installed). New skills added to
# skills/ are installed everywhere unless listed here.
skill_requires() {
  case "$1" in
    create-api)            echo "api" ;;
    database-optimization) echo "database" ;;
    *)                     echo "" ;;
  esac
}

_stage_entry() { printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$STAGE/.entries"; }

_stage_file() {  # _stage_file RELPATH POLICY  (content on stdin)
  mkdir -p "$STAGE/$(dirname "$1")"
  cat > "$STAGE/$1"
  _stage_entry file "$1" "$2"
}

_stage_block() { # _stage_block RELPATH STYLE  (block body on stdin)
  local begin end
  if [ "$2" = html ]; then
    begin="<!-- ai-harness:begin (managed by ai-harness: do not edit inside this block; add project rules outside it) -->"
    end="<!-- ai-harness:end -->"
  else
    begin="# ai-harness:begin (managed by ai-harness; edit outside this block)"
    end="# ai-harness:end"
  fi
  mkdir -p "$STAGE/.blocks/$(dirname "$1")"
  { printf '%s\n' "$begin"; cat; printf '%s\n' "$end"; } > "$STAGE/.blocks/$1"
  _stage_entry block "$1" "$2"
}

# Decide where Claude Code's memory file lives: an existing ./CLAUDE.md,
# else an existing ./.claude/CLAUDE.md, else a new ./CLAUDE.md.
claude_md_path() {
  if [ -f "$1/CLAUDE.md" ]; then echo "CLAUDE.md"
  elif [ -f "$1/.claude/CLAUDE.md" ]; then echo ".claude/CLAUDE.md"
  else echo "CLAUDE.md"; fi
}

# build_stage HARNESS_ROOT PROJECT_DIR STAGE TAGS TOOLS EXCLUDE_SKILLS EXCLUDE_WORKFLOWS INCLUDE_SKILLS
# Sets globals: SEL_INSTRUCTIONS SEL_SKILLS SEL_WORKFLOWS
build_stage() {
  local harness="$1" project="$2" tags="$4" tools="$5" ex_skills="$6" ex_workflows="$7" inc_skills="${8:-}"
  STAGE="$3"
  local f name req desc globs always hint version project_name tech claude_md
  : > "$STAGE/.entries"
  SEL_INSTRUCTIONS=""; SEL_SKILLS=""; SEL_WORKFLOWS=""
  version="$(tr -d '[:space:]' < "$harness/VERSION")"

  # --- Core + version --------------------------------------------------------
  _stage_file .ai-harness/AGENTS.md managed < "$harness/AGENTS.md"
  printf '%s\n' "$version" | _stage_file .ai-harness/VERSION managed

  # --- Instructions ------------------------------------------------------------
  # Always-on standards first, then the rest alphabetically.
  for f in "$harness"/instructions/general.md "$harness"/instructions/tech-stack.md \
           "$harness"/instructions/security.md \
           "$harness"/instructions/testing.md "$harness"/instructions/*.md; do
    [ -f "$f" ] || continue
    name="$(basename "$f" .md)"
    list_has "$SEL_INSTRUCTIONS" "$name" && continue
    req="$(instruction_requires "$name")"
    if [ -n "$req" ] && ! list_has "$tags" "$req"; then continue; fi
    SEL_INSTRUCTIONS="$(list_add "$SEL_INSTRUCTIONS" "$name")"
    fm_body "$f" | _stage_file ".ai-harness/instructions/$name.md" managed
  done

  # --- Workflows (canonical copies; tool stubs are generated below) ----------
  for f in "$harness"/workflows/*.md; do
    [ -f "$f" ] || continue
    name="$(basename "$f" .md)"
    list_has "$ex_workflows" "$name" && continue
    SEL_WORKFLOWS="$(list_add "$SEL_WORKFLOWS" "$name")"
    fm_body "$f" | _stage_file ".ai-harness/workflows/$name.md" managed
  done

  # --- Templates ---------------------------------------------------------------
  for f in "$harness"/templates/*.md; do
    [ -f "$f" ] || continue
    name="$(basename "$f")"
    [ "$name" = project-context.md ] && continue
    _stage_file ".ai-harness/templates/$name" managed < "$f"
  done

  # Project context (user-owned; created once with detected values filled in).
  project_name="$(basename "$project" | sed 's/[&\\]/-/g')"
  tech="$(describe_stack "$tags")"
  awk -v n="$project_name" -v t="$tech" '{
      gsub(/\{\{PROJECT_NAME\}\}/, n); gsub(/\{\{TECHNOLOGY\}\}/, t); print }' \
    "$harness/templates/project-context.md" | _stage_file .ai-harness/project-context.md user

  # Per-project configuration (user-owned).
  _render_config | _stage_file .ai-harness/config user

  # --- Skills (.claude/skills is read by Claude Code AND Cursor) -------------
  if [ -n "$tools" ]; then
    for f in "$harness"/skills/*/SKILL.md; do
      [ -f "$f" ] || continue
      name="$(basename "$(dirname "$f")")"
      list_has "$ex_skills" "$name" && continue
      req="$(skill_requires "$name")"
      if [ -n "$req" ] && ! list_has "$tags" "$req"; then continue; fi
      SEL_SKILLS="$(list_add "$SEL_SKILLS" "$name")"
      _stage_skill_dir "$harness/skills/$name" ".claude/skills/$name"
    done
    # Opt-in skills (vendored third-party or heavyweight), only when requested.
    for name in $inc_skills; do
      SEL_SKILLS="$(list_add "$SEL_SKILLS" "$name")"
      _stage_skill_dir "$harness/optional-skills/$name" ".claude/skills/$name"
    done
  fi

  # --- Root AGENTS.md block (Cursor, Codex, Copilot and other agents) --------
  _render_agents_block | _stage_block AGENTS.md html

  # --- Claude Code -------------------------------------------------------------
  if list_has "$tools" claude; then
    claude_md="$(claude_md_path "$project")"
    _render_claude_block "$claude_md" | _stage_block "$claude_md" html
    for name in $SEL_WORKFLOWS; do
      f="$harness/workflows/$name.md"
      desc="$(fm_get "$f" description)"; hint="$(fm_get "$f" argument-hint)"
      {
        printf -- '---\ndescription: %s\n' "${desc:-Company $name workflow}"
        [ -n "$hint" ] && printf 'argument-hint: %s\n' "$hint"
        printf -- '---\n'
        printf 'Follow the company workflow defined in @.ai-harness/workflows/%s.md\n' "$name"
        printf 'together with the project context in @.ai-harness/project-context.md.\n\n'
        printf 'The task provided by the user:\n\n$ARGUMENTS\n'
      } | _stage_file ".claude/commands/$name.md" managed
    done
    _stage_file .ai-harness/claude-settings.json managed < "$harness/config/claude-settings.json"
    _stage_file .claude/settings.json create-only < "$harness/config/claude-settings.json"
  fi

  # --- Cursor ----------------------------------------------------------------
  if list_has "$tools" cursor; then
    {
      printf -- '---\ndescription: Company AI engineering standards: workflow, security and approval rules\nglobs:\nalwaysApply: true\n---\n'
      printf '> Before any task, read `.ai-harness/project-context.md` (project architecture,\n'
      printf '> commands and rules). Project context overrides the company defaults below,\n'
      printf '> except security and approval rules.\n\n'
      cat "$harness/AGENTS.md"
    } | _stage_file .cursor/rules/ai-harness-core.mdc managed
    for name in $SEL_INSTRUCTIONS; do
      f="$harness/instructions/$name.md"
      desc="$(fm_get "$f" description)"; globs="$(fm_get "$f" globs)"; always="$(fm_get "$f" alwaysApply)"
      {
        printf -- '---\ndescription: %s\nglobs: %s\nalwaysApply: %s\n---\n' "$desc" "$globs" "${always:-false}"
        fm_body "$f"
      } | _stage_file ".cursor/rules/ai-harness-$name.mdc" managed
    done
    for name in $SEL_WORKFLOWS; do
      desc="$(fm_get "$harness/workflows/$name.md" description)"
      {
        printf '# /%s\n\n%s\n\n' "$name" "${desc:-Company $name workflow}"
        printf 'Read `.ai-harness/project-context.md`, then read `.ai-harness/workflows/%s.md`\n' "$name"
        printf 'and follow it step by step for the task the user wrote after this command.\n'
      } | _stage_file ".cursor/commands/$name.md" managed
    done
    _stage_block .cursorignore hash < "$harness/config/ai-ignore"
  fi

  # Generated README for the installed directory (last: it lists selections).
  _render_installed_readme "$version" | _stage_file .ai-harness/README.md managed
}

# Names of available opt-in skills, one per line.
optional_skill_names() {
  local d
  for d in "$HARNESS_ROOT"/optional-skills/*/; do
    [ -f "$d/SKILL.md" ] && basename "$d"
  done
  return 0
}

_stage_skill_dir() { # copy every file of a skill directory as managed files
  local src="$1" dst="$2" f rel
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    rel="${f#"$src"/}"
    _stage_file "$dst/$rel" managed < "$f"
  done <<EOF
$(find "$src" -type f ! -name '.DS_Store' | LC_ALL=C sort)
EOF
}

_render_config() {
  cat <<EOF
# ai-harness project configuration.
# User-owned: scripts/update.sh reads this file but never overwrites it.
# Values: comma-separated lists of lowercase identifiers.

# Technology tags, or "auto" to re-detect on every update.
# Known tags: $KNOWN_TAGS
STACK=${CFG_STACK:-auto}

# AI tools to configure: claude, cursor
TOOLS=${CFG_TOOLS:-claude,cursor}

# Opt-in skills to add (see optional-skills/ in the harness): $(optional_skill_names | tr '\n' ' ')
INCLUDE_SKILLS=${CFG_INCLUDE_SKILLS:-}

# Harness skills / workflows this project does not want installed.
EXCLUDE_SKILLS=${CFG_EXCLUDE_SKILLS:-}
EXCLUDE_WORKFLOWS=${CFG_EXCLUDE_WORKFLOWS:-}
EOF
}

_render_agents_block() {
  local list
  list="$(printf '%s' "$SEL_INSTRUCTIONS" | sed 's/ /, /g')"
  cat <<EOF
## Company AI standards (ai-harness)

This project uses the company AI Engineering Harness. Before changing code:

1. Read \`.ai-harness/project-context.md\` for this project's architecture,
   commands and rules.
2. Follow \`.ai-harness/AGENTS.md\`: the company workflow (inspect, plan,
   implement, test, review), security rules and actions that need approval.
3. Apply the matching standards in \`.ai-harness/instructions/\`
   (installed: $list).

Skills live in \`.claude/skills/\` and process workflows in
\`.ai-harness/workflows/\`.

Precedence: security and approval rules, then the user's request, then
project context and this file's project-specific content, then company stack
standards.
EOF
}

_render_claude_block() {
  local name
  printf '## Company AI standards (ai-harness)\n\n'
  printf 'Project context and project-specific instructions outside this block take\n'
  printf 'precedence over company defaults, except security and approval rules.\n\n'
  printf '@.ai-harness/project-context.md\n'
  # Import the root AGENTS.md so project instructions kept there are visible to
  # Claude Code (it does not read AGENTS.md on its own).
  [ "$1" != AGENTS.md ] && printf '@AGENTS.md\n'
  printf '@.ai-harness/AGENTS.md\n'
  for name in $SEL_INSTRUCTIONS; do
    printf '@.ai-harness/instructions/%s.md\n' "$name"
  done
}

_render_installed_readme() {
  cat <<EOF
# .ai-harness

Installed by the company AI Engineering Harness, version $1.

| Path | Owner | Notes |
|------|-------|-------|
| \`project-context.md\` | **You** | Fill in architecture, commands and rules. Never overwritten. |
| \`config\` | **You** | Stack/tool selection read by \`update.sh\`. Never overwritten. |
| \`AGENTS.md\`, \`instructions/\`, \`workflows/\`, \`templates/\` | Harness | Updated by \`scripts/update.sh\`. Propose changes upstream. |
| \`manifest\` | Harness | Checksums used to detect local edits. Do not edit. |

Installed instructions: ${SEL_INSTRUCTIONS:-none}
Installed skills: ${SEL_SKILLS:-none}
Installed workflows: ${SEL_WORKFLOWS:-none}

If you edit a harness-managed file, \`update.sh\` will not overwrite it. It
reports a conflict and writes the new upstream version next to it as
\`<file>.harness-new\` so you can merge by hand.
EOF
}
