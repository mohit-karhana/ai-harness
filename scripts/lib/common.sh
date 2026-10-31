#!/usr/bin/env bash
# Shared helpers for ai-harness scripts.
# Compatible with bash 3.2 (macOS default) and GNU/BSD userlands.
# This file is sourced, never executed directly.

# ----------------------------------------------------------------------------
# Output
# ----------------------------------------------------------------------------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YLW=$'\033[33m'
  C_BLU=$'\033[34m'; C_DIM=$'\033[2m'; C_BLD=$'\033[1m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YLW=""; C_BLU=""; C_DIM=""; C_BLD=""; C_RST=""
fi

log()     { printf '%s\n' "$*"; }
info()    { printf '%s==>%s %s\n' "$C_BLU" "$C_RST" "$*"; }
ok()      { printf '%s✓%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn()    { printf '%swarning:%s %s\n' "$C_YLW" "$C_RST" "$*" >&2; }
err()     { printf '%serror:%s %s\n' "$C_RED" "$C_RST" "$*" >&2; }
die()     { err "$*"; exit 1; }

# ----------------------------------------------------------------------------
# Environment checks
# ----------------------------------------------------------------------------
require_cmds() {
  local missing="" c
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || missing="$missing $c"
  done
  [ -z "$missing" ] || die "required command(s) not found:$missing"
}

# Pick a SHA-256 implementation once (sha256sum on Linux, shasum on macOS).
if command -v sha256sum >/dev/null 2>&1; then
  _HASH_CMD="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
  _HASH_CMD="shasum -a 256"
else
  _HASH_CMD=""
fi

hash_file() {
  [ -n "$_HASH_CMD" ] || die "neither sha256sum nor shasum is available"
  $_HASH_CMD < "$1" | awk '{print $1}'
}

# ----------------------------------------------------------------------------
# Paths
# ----------------------------------------------------------------------------

# Print the absolute, symlink-resolved path of an existing directory.
resolve_dir() {
  (cd "$1" 2>/dev/null && pwd -P)
}

# Validate a target project directory and print its resolved absolute path.
# Rejects missing paths, files, filesystem root, $HOME, and the harness itself.
validate_project_dir() {
  local raw="$1" harness_root="$2" resolved home_resolved
  [ -n "$raw" ] || die "no project path given (see --help)"
  [ -e "$raw" ] || die "project path does not exist: $raw"
  [ -d "$raw" ] || die "project path is not a directory: $raw"
  resolved="$(resolve_dir "$raw")" || die "cannot access project directory: $raw"
  [ "$resolved" != "/" ] || die "refusing to install into the filesystem root"
  home_resolved="$(resolve_dir "${HOME:-/nonexistent}" 2>/dev/null || true)"
  [ "$resolved" != "$home_resolved" ] || die "refusing to install into your home directory; pass a project directory"
  case "$resolved/" in
    "$harness_root"/*) die "target is the harness repository itself (or inside it): $resolved" ;;
  esac
  [ -w "$resolved" ] || die "project directory is not writable: $resolved"
  printf '%s\n' "$resolved"
}

# Remove now-empty parent directories of a project-relative path, bottom-up,
# stopping at the project root. rmdir only ever removes empty directories.
prune_empty_dirs() {
  local project="$1" rel="$2" dir
  dir="$(dirname "$rel")"
  while [ "$dir" != "." ] && [ "$dir" != "/" ]; do
    rmdir "$project/$dir" 2>/dev/null || break
    dir="$(dirname "$dir")"
  done
}

make_temp_dir() {
  mktemp -d "${TMPDIR:-/tmp}/ai-harness.XXXXXX" || die "cannot create temporary directory"
}

# ----------------------------------------------------------------------------
# Markdown frontmatter (--- delimited YAML subset: "key: value" lines)
# ----------------------------------------------------------------------------

# fm_get FILE KEY -> value of KEY in the leading frontmatter, or nothing.
fm_get() {
  awk -v key="$2" '
    NR == 1 { if ($0 == "---") { f = 1; next } else exit }
    f && $0 == "---" { exit }
    f {
      i = index($0, ":")
      if (i > 0 && substr($0, 1, i - 1) == key) {
        v = substr($0, i + 1)
        sub(/^[ \t]+/, "", v); sub(/[ \t\r]+$/, "", v)
        print v; exit
      }
    }' "$1"
}

# fm_body FILE -> file content without the leading frontmatter block
# (and without blank lines directly after it).
fm_body() {
  awk '
    NR == 1 && $0 == "---" { f = 1; next }
    f == 1 { if ($0 == "---") f = 2; next }
    f == 2 && $0 ~ /^[ \t]*$/ && !started { next }
    { started = 1; print }' "$1"
}

has_frontmatter() {
  [ "$(head -n 1 "$1" 2>/dev/null)" = "---" ]
}

# ----------------------------------------------------------------------------
# Lists (space separated; bash 3.2 has no associative arrays)
# ----------------------------------------------------------------------------
list_has() {
  case " $1 " in *" $2 "*) return 0 ;; esac
  return 1
}

list_add() {
  if list_has "$1" "$2"; then printf '%s' "$1"; else printf '%s' "${1:+$1 }$2"; fi
}

# Convert "a,b, c" to "a b c".
csv_to_list() {
  printf '%s' "$1" | tr ',' ' ' | tr -s ' ' | sed 's/^ //; s/ $//'
}

# ----------------------------------------------------------------------------
# Config file (KEY=value). Parsed, never sourced: project files are untrusted.
# ----------------------------------------------------------------------------
cfg_get() {
  [ -f "$1" ] || return 0
  grep -E "^[[:space:]]*$2[[:space:]]*=" "$1" | tail -n 1 | cut -d= -f2- |
    sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/" || true
}

# Allow only safe identifiers in config/CLI list values.
validate_list_value() {
  case "$2" in
    *[!a-z0-9,_\ -]*) die "invalid value for $1: '$2' (allowed: lowercase letters, digits, comma, dash, underscore)" ;;
  esac
}

# ----------------------------------------------------------------------------
# Interaction
# ----------------------------------------------------------------------------
# INTERACTIVE=1 only when attached to a terminal and not disabled by flag.
INTERACTIVE=0
if [ -t 0 ] && [ -t 1 ]; then INTERACTIVE=1; fi

confirm() {
  local answer
  [ "$INTERACTIVE" = 1 ] || return 1
  printf '%s [y/N] ' "$1" > /dev/tty
  IFS= read -r answer < /dev/tty || return 1
  case "$answer" in y|Y|yes|YES|Yes) return 0 ;; esac
  return 1
}

timestamp() { date +%Y%m%d%H%M%S; }
