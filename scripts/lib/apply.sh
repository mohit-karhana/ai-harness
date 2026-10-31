#!/usr/bin/env bash
# harness_apply: shared by setup.sh and update.sh.
# Resolves settings (defaults < .ai-harness/config < CLI flags), detects the
# stack, renders the stage, reconciles it into the project and reports.

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HARNESS_ROOT="$(cd "$LIB_DIR/../.." && pwd -P)"
# shellcheck source=common.sh
. "$LIB_DIR/common.sh"
# shellcheck source=detect.sh
. "$LIB_DIR/detect.sh"
# shellcheck source=build.sh
. "$LIB_DIR/build.sh"
# shellcheck source=reconcile.sh
. "$LIB_DIR/reconcile.sh"

KNOWN_TOOLS="claude cursor"

# Option state (filled by parse_common_args)
PROJECT_ARG=""; OPT_STACK=""; OPT_TOOLS=""; OPT_EX_SKILLS="__unset__"; OPT_EX_WORKFLOWS="__unset__"; OPT_INC_SKILLS="__unset__"
FORCE=0; DRY_RUN=0; NO_FETCH=0

# parse_common_args "$@" -> sets option globals; unknown flags are fatal.
parse_common_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      --stack) [ $# -ge 2 ] || die "--stack needs a value"; OPT_STACK="$2"; shift 2 ;;
      --stack=*) OPT_STACK="${1#*=}"; shift ;;
      --tools) [ $# -ge 2 ] || die "--tools needs a value"; OPT_TOOLS="$2"; shift 2 ;;
      --tools=*) OPT_TOOLS="${1#*=}"; shift ;;
      --exclude-skills) [ $# -ge 2 ] || die "--exclude-skills needs a value"; OPT_EX_SKILLS="$2"; shift 2 ;;
      --exclude-skills=*) OPT_EX_SKILLS="${1#*=}"; shift ;;
      --exclude-workflows) [ $# -ge 2 ] || die "--exclude-workflows needs a value"; OPT_EX_WORKFLOWS="$2"; shift 2 ;;
      --exclude-workflows=*) OPT_EX_WORKFLOWS="${1#*=}"; shift ;;
      --with-skills|--include-skills) [ $# -ge 2 ] || die "$1 needs a value"; OPT_INC_SKILLS="$2"; shift 2 ;;
      --with-skills=*|--include-skills=*) OPT_INC_SKILLS="${1#*=}"; shift ;;
      --force) FORCE=1; shift ;;
      --dry-run) DRY_RUN=1; shift ;;
      --non-interactive|--no-input) INTERACTIVE=0; shift ;;
      --no-fetch) NO_FETCH=1; shift ;;
      --) shift; [ $# -gt 0 ] && { PROJECT_ARG="$1"; shift; } ;;
      -*) die "unknown option: $1 (see --help)" ;;
      *) [ -z "$PROJECT_ARG" ] || die "only one project path may be given"; PROJECT_ARG="$1"; shift ;;
    esac
  done
}

_validate_items() { # _validate_items LABEL "list" "allowed"
  local item
  for item in $2; do
    list_has "$3" "$item" || die "unknown $1 '$item' (known: $3)"
  done
}

# harness_apply MODE   (MODE = setup | update)
harness_apply() {
  local mode="$1" cfg stack_setting tags tools ex_skills ex_workflows inc_skills existing
  require_cmds awk sed grep find cp mv mktemp tr cut sort
  PROJECT="$(validate_project_dir "$PROJECT_ARG" "$HARNESS_ROOT")" || exit 1
  HARNESS_VERSION="$(tr -d '[:space:]' < "$HARNESS_ROOT/VERSION")"
  cfg="$PROJECT/.ai-harness/config"

  existing=""
  [ -f "$PROJECT/$MANIFEST_REL" ] && existing="$(awk -F '\t' '$1 == "version" { print $2; exit }' "$PROJECT/$MANIFEST_REL")"
  if [ "$mode" = update ] && [ ! -f "$PROJECT/$MANIFEST_REL" ]; then
    die "ai-harness is not installed in $PROJECT (run scripts/setup.sh first)"
  fi

  # Effective settings: defaults < config file < CLI flags.
  stack_setting="${OPT_STACK:-$(cfg_get "$cfg" STACK)}"; stack_setting="${stack_setting:-auto}"
  tools="${OPT_TOOLS:-$(cfg_get "$cfg" TOOLS)}"; tools="${tools:-claude,cursor}"
  if [ "$OPT_EX_SKILLS" = __unset__ ]; then ex_skills="$(cfg_get "$cfg" EXCLUDE_SKILLS)"; else ex_skills="$OPT_EX_SKILLS"; fi
  if [ "$OPT_EX_WORKFLOWS" = __unset__ ]; then ex_workflows="$(cfg_get "$cfg" EXCLUDE_WORKFLOWS)"; else ex_workflows="$OPT_EX_WORKFLOWS"; fi
  validate_list_value STACK "$stack_setting"; validate_list_value TOOLS "$tools"
  if [ "$OPT_INC_SKILLS" = __unset__ ]; then inc_skills="$(cfg_get "$cfg" INCLUDE_SKILLS)"; else inc_skills="$OPT_INC_SKILLS"; fi
  validate_list_value EXCLUDE_SKILLS "$ex_skills"; validate_list_value EXCLUDE_WORKFLOWS "$ex_workflows"
  validate_list_value INCLUDE_SKILLS "$inc_skills"
  _validate_items "optional skill" "$(csv_to_list "$inc_skills")" "$(optional_skill_names | tr '\n' ' ')"

  tools="$(csv_to_list "$tools")"
  _validate_items tool "$tools" "$KNOWN_TOOLS"
  [ -n "$tools" ] || die "at least one tool must be configured (claude, cursor)"

  if [ "$stack_setting" = auto ]; then
    tags="$(detect_stack "$PROJECT")"
  else
    _validate_items "stack tag" "$(csv_to_list "$stack_setting")" "$KNOWN_TAGS"
    tags="$(expand_tags "$(csv_to_list "$stack_setting")")"
  fi

  # Values written to a newly created config file.
  CFG_STACK="$stack_setting"; CFG_TOOLS="$(printf '%s' "$tools" | tr ' ' ',')"
  CFG_EXCLUDE_SKILLS="$ex_skills"; CFG_EXCLUDE_WORKFLOWS="$ex_workflows"; CFG_INCLUDE_SKILLS="$inc_skills"

  log "${C_BLD}ai-harness ${HARNESS_VERSION}${C_RST} ${mode} → $PROJECT"
  if [ -n "$existing" ]; then
    if [ "$existing" = "$HARNESS_VERSION" ]; then log "  installed version: $existing (re-applying; safe to repeat)"
    else log "  installed version: $existing → $HARNESS_VERSION"; fi
  fi
  log "  stack:  ${tags:-none detected} ${C_DIM}($( [ "$stack_setting" = auto ] && echo auto-detected || echo "from STACK=$stack_setting"))${C_RST}"
  log "  tools:  $tools"
  [ -n "$tags" ] || warn "no technology detected; installing general standards only (use --stack to choose)"

  WORK="$(make_temp_dir)"
  # shellcheck disable=SC2064
  trap "rm -rf '$WORK'" EXIT INT TERM
  mkdir -p "$WORK/stage"
  REPORT="$WORK/report"; : > "$REPORT"

  build_stage "$HARNESS_ROOT" "$PROJECT" "$WORK/stage" "$tags" "$tools" \
    "$(csv_to_list "$ex_skills")" "$(csv_to_list "$ex_workflows")" "$(csv_to_list "$inc_skills")"

  # Setup flags are an explicit choice: persist them into an existing config.
  if [ "$mode" = setup ] && [ -f "$cfg" ] && [ "$DRY_RUN" != 1 ] &&
     { [ -n "$OPT_STACK" ] || [ -n "$OPT_TOOLS" ] || [ "$OPT_EX_SKILLS" != __unset__ ] || [ "$OPT_EX_WORKFLOWS" != __unset__ ] || [ "$OPT_INC_SKILLS" != __unset__ ]; }; then
    _render_config > "$cfg"
    _report updated .ai-harness/config "saved command-line selections"
  fi

  reconcile_stage
  print_report

  log ""
  log "${C_BLD}Components${C_RST}"
  log "  instructions: ${SEL_INSTRUCTIONS:-none}"
  log "  skills:       ${SEL_SKILLS:-none}"
  log "  workflows:    ${SEL_WORKFLOWS:-none}"
  list_has "$tools" claude && log "  Claude Code:  $(claude_md_path "$PROJECT") imports, .claude/skills/, .claude/commands/, .claude/settings.json"
  list_has "$tools" cursor && log "  Cursor:       .cursor/rules/ai-harness-*.mdc, .cursor/commands/, .claude/skills/, AGENTS.md, .cursorignore"

  if [ "$COUNT_CONFLICT" -gt 0 ]; then
    log ""
    warn "$COUNT_CONFLICT file(s) have local modifications and were NOT overwritten."
    log "  Review each *.harness-new file, merge what you need, then delete it."
    log "  To accept upstream versions instead (backups are kept): rerun with --force"
  fi
  if [ "$mode" = setup ] && [ "$DRY_RUN" != 1 ]; then
    log ""
    log "${C_BLD}Next steps${C_RST}"
    log "  1. Complete .ai-harness/project-context.md (architecture, commands, rules)."
    log "  2. Review the changes (git diff) and commit them so your team shares the setup."
    log "  3. Open the project in Claude Code or Cursor and try: /new-feature <description>"
  fi
}
