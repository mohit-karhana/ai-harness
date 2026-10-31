#!/usr/bin/env bash
# Reconciler: applies a stage (see build.sh) to a project without ever
# silently overwriting developer content.
#
# The manifest (.ai-harness/manifest) records the checksum of every file and
# block the harness last wrote. Comparing three checksums decides each action:
#
#   old = manifest checksum (what the harness last wrote; empty = never)
#   cur = checksum of the file currently in the project
#   new = checksum of the staged (desired) content
#
#   file missing                   -> install
#   cur == new                     -> unchanged
#   old empty (file not ours)      -> ask; skip unless approved or --force
#   cur == old (untouched by dev)  -> update
#   cur != old (edited by dev)     -> conflict: keep file, write <file>.harness-new
#                                     (--force: back up and overwrite)
#
# Globals used: PROJECT STAGE FORCE DRY_RUN HARNESS_VERSION
# Results are appended to $REPORT as "status<TAB>path<TAB>note".

MANIFEST_REL=".ai-harness/manifest"

_manifest_get() { # _manifest_get KIND RELPATH FIELD(3|4)
  [ -f "$OLD_MANIFEST" ] || return 0
  awk -F '\t' -v k="$1" -v p="$2" -v n="$3" '$1 == k && $2 == p { print $n; exit }' "$OLD_MANIFEST"
}

_record()  { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$NEW_MANIFEST"; }
_report()  { printf '%s\t%s\t%s\n' "$1" "$2" "${3:-}" >> "$REPORT"; }

_write() { # _write SRC DST
  [ "$DRY_RUN" = 1 ] && return 0
  mkdir -p "$(dirname "$2")"
  cp "$1" "$2"
}

_backup() { # _backup DST -> prints backup path
  local b
  b="$1.harness-backup-$(timestamp)"
  [ "$DRY_RUN" = 1 ] || cp "$1" "$b"
  printf '%s' "${b#"$PROJECT"/}"
}

_reconcile_file() {
  local rel="$1" policy="$2" src dst old cur new b
  src="$STAGE/$rel"; dst="$PROJECT/$rel"
  new="$(hash_file "$src")"
  old="$(_manifest_get file "$rel" 3)"

  if [ "$policy" = user ]; then
    if [ -e "$dst" ]; then _report kept "$rel" "user-owned"
    else _write "$src" "$dst"; _report created "$rel" "user-owned: please review and complete"; fi
    return 0
  fi

  if [ ! -e "$dst" ]; then
    _write "$src" "$dst"; _record file "$rel" "$new" "$policy"
    if [ -n "$old" ]; then _report restored "$rel"; else _report installed "$rel"; fi
    return 0
  fi
  if [ -d "$dst" ] || [ -L "$dst" ]; then
    _report skipped "$rel" "path is a directory or symlink; not touching it"
    return 0
  fi

  cur="$(hash_file "$dst")"
  if [ "$cur" = "$new" ]; then
    _record file "$rel" "$new" "$policy"; _report unchanged "$rel"; return 0
  fi

  if [ -z "$old" ]; then
    # Existing file the harness did not create.
    if [ "$policy" = create-only ]; then
      _report kept "$rel" "existing file left as-is; recommended version in .ai-harness/"
      return 0
    fi
    if [ "$FORCE" = 1 ] || confirm "  $rel exists and was not created by ai-harness. Overwrite it (a backup is kept)?"; then
      b="$(_backup "$dst")"; _write "$src" "$dst"; _record file "$rel" "$new" "$policy"
      _report overwritten "$rel" "backup: $b"
    else
      _report skipped "$rel" "existing file not created by ai-harness (rerun interactively or with --force to replace)"
    fi
    return 0
  fi

  if [ "$cur" = "$old" ]; then
    _write "$src" "$dst"; _record file "$rel" "$new" "$policy"; _report updated "$rel"
    return 0
  fi

  # Locally modified harness file.
  if [ "$policy" = create-only ]; then
    _record file "$rel" "$old" "$policy"; _report kept "$rel" "customized locally"
    return 0
  fi
  if [ "$FORCE" = 1 ]; then
    b="$(_backup "$dst")"; _write "$src" "$dst"; _record file "$rel" "$new" "$policy"
    _report overwritten "$rel" "had local edits; backup: $b"
  else
    _write "$src" "$dst.harness-new"; _record file "$rel" "$old" "$policy"
    _report conflict "$rel" "local edits kept; upstream version written to $rel.harness-new"
  fi
}

# Block helpers ---------------------------------------------------------------
_block_prefixes() { # sets BEGIN_P END_P for a style
  if [ "$1" = html ]; then BEGIN_P="<!-- ai-harness:begin"; END_P="<!-- ai-harness:end"
  else BEGIN_P="# ai-harness:begin"; END_P="# ai-harness:end"; fi
}

# _block_state FILE -> none | ok | broken
_block_state() {
  awk -v b="$BEGIN_P" -v e="$END_P" '
    index($0, b) == 1 { nb++; if (!open) open = 1; next }
    index($0, e) == 1 { ne++; if (open) closed = 1 }
    END {
      if (nb == 0 && ne == 0) print "none"
      else if (nb == 1 && ne == 1 && closed) print "ok"
      else print "broken"
    }' "$1"
}

_block_extract() { # _block_extract FILE -> block including markers
  awk -v b="$BEGIN_P" -v e="$END_P" '
    index($0, b) == 1 { on = 1 }
    on { print }
    on && index($0, e) == 1 { exit }' "$1"
}

_block_replace() { # _block_replace FILE NEWBLOCKFILE -> new content on stdout
  awk -v b="$BEGIN_P" -v e="$END_P" -v nf="$2" '
    index($0, b) == 1 { while ((getline line < nf) > 0) print line; skip = 1; next }
    skip && index($0, e) == 1 { skip = 0; next }
    !skip { print }' "$1"
}

# Remove the block and the single blank separator line before it; trim
# trailing blank lines.
_block_remove() {
  awk -v b="$BEGIN_P" -v e="$END_P" '
    { lines[NR] = $0 }
    END {
      n = 0
      for (i = 1; i <= NR; i++) {
        if (index(lines[i], b) == 1) {
          if (n > 0 && out[n] ~ /^[ \t]*$/) n--
          while (i <= NR && index(lines[i], e) != 1) i++
          continue
        }
        out[++n] = lines[i]
      }
      while (n > 0 && out[n] ~ /^[ \t]*$/) n--
      for (i = 1; i <= n; i++) print out[i]
    }' "$1"
}

_replace_file_with() { # atomically replace DST with stdin content
  local tmp
  tmp="$(mktemp "$1.tmp.XXXXXX")"
  cat > "$tmp"
  # Preserve the original permissions.
  chmod "$(_file_mode "$1")" "$tmp" 2>/dev/null || true
  mv "$tmp" "$1"
}

_file_mode() {
  if stat -c '%a' "$1" >/dev/null 2>&1; then stat -c '%a' "$1"; else stat -f '%Lp' "$1"; fi
}

_reconcile_block() {
  local rel="$1" style="$2" src dst old cur new created state tmp
  src="$STAGE/.blocks/$rel"; dst="$PROJECT/$rel"
  _block_prefixes "$style"
  new="$(hash_file "$src")"
  old="$(_manifest_get block "$rel" 3)"
  created="$(_manifest_get block "$rel" 4)"; created="${created:-0}"

  if [ ! -e "$dst" ]; then
    _write "$src" "$dst"; _record block "$rel" "$new" 1; _report installed "$rel" "created with harness block"
    return 0
  fi

  state="$(_block_state "$dst")"
  if [ "$state" = broken ]; then
    _record block "$rel" "${old:-none}" "$created"
    _report conflict "$rel" "harness block markers are damaged; fix or remove them by hand"
    return 0
  fi
  if [ "$state" = none ]; then
    if [ "$DRY_RUN" != 1 ]; then
      {
        cat "$dst"
        # Ensure the existing content ends with a newline, then a blank line.
        [ -s "$dst" ] && [ "$(tail -c 1 "$dst" | od -An -c | tr -d ' ')" != '\n' ] && printf '\n'
        [ -s "$dst" ] && printf '\n'
        cat "$src"
      } | _replace_file_with "$dst"
    fi
    _record block "$rel" "$new" "$created"; _report installed "$rel" "harness block appended; existing content preserved"
    return 0
  fi

  tmp="$WORK/block.cur"
  _block_extract "$dst" > "$tmp"
  cur="$(hash_file "$tmp")"
  if [ "$cur" = "$new" ]; then
    _record block "$rel" "$new" "$created"; _report unchanged "$rel"; return 0
  fi
  if [ -n "$old" ] && [ "$cur" = "$old" ] || [ "$FORCE" = 1 ]; then
    local note="harness block refreshed; content outside the block untouched"
    if [ "$cur" != "$old" ]; then note="block had local edits; backup: $(_backup "$dst")"; fi
    [ "$DRY_RUN" = 1 ] || _block_replace "$dst" "$src" | _replace_file_with "$dst"
    _record block "$rel" "$new" "$created"
    if [ "$cur" = "$old" ]; then _report updated "$rel" "$note"; else _report overwritten "$rel" "$note"; fi
    return 0
  fi
  _write "$src" "$dst.harness-new-block"
  _record block "$rel" "${old:-none}" "$created"
  _report conflict "$rel" "harness block was edited locally; proposed block written to $rel.harness-new-block"
}

# Remove harness files that are no longer part of the stage (e.g. a skill was
# retired upstream or the stack changed). Edited files are kept.
_reconcile_orphans() {
  local kind rel hash policy dst cur
  [ -f "$OLD_MANIFEST" ] || return 0
  while IFS="$(printf '\t')" read -r kind rel hash policy; do
    case "$kind" in file|block) ;; *) continue ;; esac
    if awk -F '\t' -v k="$kind" -v p="$rel" '$1 == k && $2 == p { found = 1 } END { exit !found }' "$NEW_MANIFEST"; then
      continue
    fi
    dst="$PROJECT/$rel"
    [ -e "$dst" ] || continue
    if [ "$kind" = file ]; then
      cur="$(hash_file "$dst")"
      if [ "$cur" = "$hash" ]; then
        [ "$DRY_RUN" = 1 ] || { rm -f "$dst"; prune_empty_dirs "$PROJECT" "$rel"; }
        _report removed "$rel" "no longer provided by the harness"
      else
        _report kept "$rel" "no longer provided by the harness, but edited locally"
      fi
    else
      _remove_block "$rel" "$hash" "$policy" removed
    fi
  done < "$OLD_MANIFEST"
}

# _remove_block RELPATH RECORDED_HASH CREATED STATUS
_remove_block() {
  local rel="$1" hash="$2" created="$3" status="$4" dst="$PROJECT/$1" style tmp cur
  style="html"; case "$rel" in .cursorignore|*.gitignore) style="hash" ;; esac
  _block_prefixes "$style"
  [ "$(_block_state "$dst")" = ok ] || { _report kept "$rel" "no intact harness block found"; return 0; }
  tmp="$WORK/block.rm"; _block_extract "$dst" > "$tmp"; cur="$(hash_file "$tmp")"
  if [ "$cur" != "$hash" ] && [ "$FORCE" != 1 ]; then
    _report kept "$rel" "harness block was edited locally; remove it by hand or use --force"
    return 0
  fi
  if [ "$DRY_RUN" != 1 ]; then
    _block_remove "$dst" | _replace_file_with "$dst"
    if [ "$created" = 1 ] && ! grep -q '[^[:space:]]' "$dst"; then
      rm -f "$dst"; prune_empty_dirs "$PROJECT" "$rel"
    fi
  fi
  _report "$status" "$rel" "harness block removed; other content preserved"
}

# reconcile_stage -> applies $STAGE/.entries to $PROJECT, writes manifest
reconcile_stage() {
  local kind rel arg
  OLD_MANIFEST="$PROJECT/$MANIFEST_REL"
  NEW_MANIFEST="$WORK/manifest.new"
  printf '# ai-harness manifest: generated, do not edit\nversion\t%s\n' "$HARNESS_VERSION" > "$NEW_MANIFEST"
  while IFS="$(printf '\t')" read -r kind rel arg; do
    case "$kind" in
      file)  _reconcile_file "$rel" "$arg" ;;
      block) _reconcile_block "$rel" "$arg" ;;
    esac
  done < "$STAGE/.entries"
  _reconcile_orphans
  if [ "$DRY_RUN" != 1 ]; then
    mkdir -p "$PROJECT/.ai-harness"
    cp "$NEW_MANIFEST" "$PROJECT/$MANIFEST_REL"
  fi
}

# print_report TITLE -> human-readable summary; returns counts in globals
print_report() {
  local status rel note verb=""
  COUNT_INSTALLED=0; COUNT_UPDATED=0; COUNT_UNCHANGED=0; COUNT_SKIPPED=0; COUNT_CONFLICT=0; COUNT_REMOVED=0
  log ""
  if [ "$DRY_RUN" = 1 ]; then
    verb="would be "
    log "${C_BLD}Planned changes${C_RST} (dry run: nothing was written)"
  else
    log "${C_BLD}Changes${C_RST}"
  fi
  while IFS="$(printf '\t')" read -r status rel note; do
    case "$status" in
      installed|created|restored) COUNT_INSTALLED=$((COUNT_INSTALLED + 1)); printf '  %s+%s %-11s %s %s\n' "$C_GRN" "$C_RST" "$status" "$rel" "${note:+$C_DIM($note)$C_RST}" ;;
      updated|overwritten)        COUNT_UPDATED=$((COUNT_UPDATED + 1));     printf '  %s~%s %-11s %s %s\n' "$C_BLU" "$C_RST" "$status" "$rel" "${note:+$C_DIM($note)$C_RST}" ;;
      removed)                    COUNT_REMOVED=$((COUNT_REMOVED + 1));     printf '  %s-%s %-11s %s %s\n' "$C_YLW" "$C_RST" "$status" "$rel" "${note:+$C_DIM($note)$C_RST}" ;;
      unchanged)                  COUNT_UNCHANGED=$((COUNT_UNCHANGED + 1)) ;;
      kept)                       printf '  %s=%s %-11s %s %s\n' "$C_DIM" "$C_RST" "$status" "$rel" "${note:+$C_DIM($note)$C_RST}" ;;
      skipped)                    COUNT_SKIPPED=$((COUNT_SKIPPED + 1));     printf '  %s!%s %-11s %s\n      %s\n' "$C_YLW" "$C_RST" "$status" "$rel" "$note" ;;
      conflict)                   COUNT_CONFLICT=$((COUNT_CONFLICT + 1));   printf '  %s✗%s %-11s %s\n      %s\n' "$C_RED" "$C_RST" "$status" "$rel" "$note" ;;
    esac
  done < "$REPORT"
  log ""
  log "${C_BLD}Summary:${C_RST} ${COUNT_INSTALLED} ${verb}installed, ${COUNT_UPDATED} ${verb}updated, ${COUNT_REMOVED} ${verb}removed, ${COUNT_UNCHANGED} unchanged, ${COUNT_SKIPPED} skipped, ${COUNT_CONFLICT} conflicts"
}
