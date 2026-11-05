#!/usr/bin/env bash
# konsole-settings.sh: apply Konsole settings for running many Claude Code sessions on this machine.
# Idempotent; safe to re-run. Backs up ~/.config/konsolerc first.
#
#   ./konsole-settings.sh              apply everything
#   ./konsole-settings.sh --dry-run    print what would be done
#   ./konsole-settings.sh --no-watch   skip installing the close-guard watch
#
# What it sets (skills/setup says why):
#   - closing a whole window always asks (window-level "Don't ask again" keys removed)
#   - closing a single tab or split pane never asks (CloseSingleTab=true)
#   - split headers and the tab bar always visible
#   - Restore defaults: one window, horizontal (side-by-side) split panes
#   - the konsole-close-guard watch, which removes the window-level keys again
#     if "Don't ask again" is ticked on a window-close dialog
set -euo pipefail

DRY=0; WATCH=1
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --no-watch) WATCH=0 ;;
    -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
    *) echo "unknown option: $a" >&2; exit 2 ;;
  esac
done

CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
RC="$CFG/konsolerc"
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

KW=$(command -v kwriteconfig6 || command -v kwriteconfig5 || true)
[ -n "$KW" ] || { echo "kwriteconfig6/kwriteconfig5 not found (KDE frameworks tools)" >&2; exit 1; }

run() { if [ "$DRY" = 1 ]; then echo "would run: $*"; else "$@"; fi; }
kset() { run "$KW" --file "$RC" --group "$1" --key "$2" "$3"; }
kdel() { run "$KW" --file "$RC" --group "$1" --key "$2" --delete; }

if [ -f "$RC" ] && [ "$DRY" = 0 ]; then
  cp -p "$RC" "$RC.bak-$(date +%Y%m%d-%H%M%S)"
fi

# Close behaviour
kdel "Notification Messages" CloseAllTabs        # window close with programs running: ask
kdel "Notification Messages" CloseAllEmptyTabs   # window close with several tabs: ask
kset "Notification Messages" CloseSingleTab true # tab/pane close: don't ask, close

# Layout
kset SplitView SplitViewVisibility AlwaysShowSplitHeader
kset TabBar TabBarVisibility AlwaysShowTabBar

# Restore defaults (read by session_restore.py; environment.d applies at next login)
ENVD="$CFG/environment.d/session-restore.conf"
if [ "$DRY" = 1 ]; then
  echo "would write $ENVD: SESSION_RESTORE_LAYOUT=split, SESSION_RESTORE_ORIENTATION=horizontal"
else
  mkdir -p "$(dirname "$ENVD")"
  printf 'SESSION_RESTORE_LAYOUT=split\nSESSION_RESTORE_ORIENTATION=horizontal\n' > "$ENVD"
fi

# Close-guard watch (guards window closes only)
if [ "$WATCH" = 1 ]; then
  GUARD="$HERE/konsole_close_guard.py"
  run python3 "$GUARD" install-watch
fi

if [ "$DRY" = 0 ]; then
  echo "Applied. Konsole reads konsolerc once per process: windows opened from now on get these settings."
fi
