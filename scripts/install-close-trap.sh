#!/usr/bin/env bash
# Add the multisession close trap to ~/.bashrc (idempotent). New panes pick it up; existing
# panes need `source ~/.bashrc` or a new pane. Prints one JSON line.
set -eu
src="$(dirname "$(readlink -f "$0")")/../shell/multisession-close-trap.sh"
src="$(readlink -f "$src")"
rc="${1:-$HOME/.bashrc}"
dest="${XDG_CONFIG_HOME:-$HOME/.config}/multisession/close-trap.sh"
mkdir -p "$(dirname "$dest")"; cp "$src" "$dest"
line='[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/multisession/close-trap.sh" ] && . "${XDG_CONFIG_HOME:-$HOME/.config}/multisession/close-trap.sh"'
if grep -qF 'multisession/close-trap.sh' "$rc" 2>/dev/null; then
  echo "{\"installed\":true,\"changed\":false,\"rc\":\"$rc\",\"trap\":\"$dest\"}"
else
  printf '\n# multisession: clean pane close for agent handovers\n%s\n' "$line" >> "$rc"
  echo "{\"installed\":true,\"changed\":true,\"rc\":\"$rc\",\"trap\":\"$dest\"}"
fi
