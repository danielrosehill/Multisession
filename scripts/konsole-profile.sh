#!/usr/bin/env bash
# konsole-profile.sh: install my Konsole profile (Hack 14, default colours) and make it the default.
#
#   ./konsole-profile.sh                   install templates/konsole/*.profile, set "My Theme" as default
#   ./konsole-profile.sh --profile NAME    install and set templates/konsole/NAME.profile as default
#   ./konsole-profile.sh --capture         copy this machine's current default profile (and its
#                                        colour scheme, if custom) into templates/konsole/ to commit
#   ./konsole-profile.sh --dry-run         print what would be done
#
# Installs the Hack font (Ubuntu/Debian package fonts-hack) if it's missing.
# Profiles and colour schemes live in ~/.local/share/konsole/; the default is
# konsolerc [Desktop Entry] DefaultProfile. Windows already open keep their profile.
set -euo pipefail

HERE="$(cd "$(dirname "$(readlink -f "$0")")/../templates/konsole" && pwd)"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/konsole"
RC="${XDG_CONFIG_HOME:-$HOME/.config}/konsolerc"
NAME="My Theme"; MODE=apply; DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --profile) NAME="$2"; shift ;;
    --capture) MODE=capture ;;
    --dry-run) DRY=1 ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done
run() { if [ "$DRY" = 1 ]; then echo "would run: $*"; else "$@"; fi; }
KW=$(command -v kwriteconfig6 || command -v kwriteconfig5 || true)
KR=$(command -v kreadconfig6 || command -v kreadconfig5 || true)
[ -n "$KW" ] && [ -n "$KR" ] || { echo "kwriteconfig6/kreadconfig6 not found" >&2; exit 1; }

if [ "$MODE" = capture ]; then
  CUR=$("$KR" --file "$RC" --group "Desktop Entry" --key DefaultProfile)
  [ -n "$CUR" ] && [ -f "$DATA/$CUR" ] || { echo "no custom default profile set (DefaultProfile='$CUR')" >&2; exit 1; }
  run cp "$DATA/$CUR" "$HERE/"
  SCHEME=$("$KR" --file "$DATA/$CUR" --group Appearance --key ColorScheme)
  if [ -n "$SCHEME" ] && [ -f "$DATA/$SCHEME.colorscheme" ]; then
    run cp "$DATA/$SCHEME.colorscheme" "$HERE/"
  fi
  echo "Captured $CUR into templates/konsole/. Review and commit."
  exit 0
fi

[ -f "$HERE/$NAME.profile" ] || { echo "templates/konsole/$NAME.profile not found" >&2; exit 1; }

if [ -z "$(fc-list :family=Hack)" ]; then
  if command -v apt-get >/dev/null; then
    run sudo apt-get install -y fonts-hack
  else
    echo "Hack font missing; install it with your package manager (it's 'fonts-hack' on Debian/Ubuntu)." >&2
  fi
fi

run mkdir -p "$DATA"
for f in "$HERE"/*.profile "$HERE"/*.colorscheme; do
  [ -e "$f" ] || continue
  dest="$DATA/$(basename "$f")"
  if [ -f "$dest" ] && ! cmp -s "$f" "$dest" && [ "$DRY" = 0 ]; then
    cp -p "$dest" "$dest.bak-$(date +%Y%m%d-%H%M%S)"
  fi
  run cp "$f" "$dest"
done
run "$KW" --file "$RC" --group "Desktop Entry" --key DefaultProfile "$NAME.profile"
[ "$DRY" = 1 ] || echo "Default Konsole profile: $NAME. New windows and tabs use it."
