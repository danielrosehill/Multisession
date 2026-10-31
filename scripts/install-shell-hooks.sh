#!/usr/bin/env bash
# Install the multisession shell hooks (clean pane close + split launch claim) into ~/.bashrc.
# Idempotent; migrates the 0.5.0 close-trap line. New panes pick it up; existing panes need
# `source ~/.bashrc` or a new pane. Prints one JSON line.
set -eu
src="$(readlink -f "$(dirname "$(readlink -f "$0")")/../shell/multisession-rc.sh")"
rc="${1:-$HOME/.bashrc}"
cfg="${XDG_CONFIG_HOME:-$HOME/.config}/multisession"
mkdir -p "$cfg"; cp "$src" "$cfg/rc.sh"; rm -f "$cfg/close-trap.sh"
line='[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/multisession/rc.sh" ] && . "${XDG_CONFIG_HOME:-$HOME/.config}/multisession/rc.sh"'
changed=false
if grep -qF 'multisession/close-trap.sh' "$rc" 2>/dev/null; then
  grep -vF 'multisession/close-trap.sh' "$rc" > "$rc.multisession.tmp" && cat "$rc.multisession.tmp" > "$rc" && rm -f "$rc.multisession.tmp"
  changed=true
fi
if ! grep -qF 'multisession/rc.sh' "$rc" 2>/dev/null; then
  grep -qF '# multisession:' "$rc" || printf '\n# multisession: clean pane close + split launch for agent handovers\n' >> "$rc"
  printf '%s\n' "$line" >> "$rc"; changed=true
fi
echo "{\"installed\":true,\"changed\":$changed,\"rc\":\"$rc\",\"hooks\":\"$cfg/rc.sh\"}"
