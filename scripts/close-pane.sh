#!/usr/bin/env bash
# close-pane.sh: close the Konsole pane (one terminal session) this Claude Code session runs in.
# Not the window, not the other tabs or splits. If it is the window's last pane, Konsole closes
# the window too, because that is what Konsole does when its last session ends.
#
# Usage: close-pane.sh [--delay SECONDS] [--dry-run]
#   --delay N   wait N seconds before closing (default 6), so the agent's last reply renders
#   --dry-run   resolve and print what would be closed, close nothing
#
# How: Konsole's D-Bus Session interface has no close method (checked on Konsole 25.12.3), so
# this ends the pane's processes instead. It asks Konsole for the pane's shell PID
# (org.kde.konsole.Session.processId on $KONSOLE_DBUS_SESSION), confirms that shell is an
# ancestor of this script (so it can only ever close the pane it was called from), then, from
# a detached process: SIGTERM to Claude Code, then "exit" typed into the idle shell through
# Session.sendText so it exits cleanly (Konsole keeps a pane whose shell died by signal).
#
# Output: one JSON line. Exit 0 = close scheduled (or dry run), 2 = refused (nothing done).

set -u
delay=6; dry=0
while [ $# -gt 0 ]; do
  case "$1" in
    --delay) delay="$2"; shift 2 ;;
    --dry-run) dry=1; shift ;;
    *) echo "{\"closed\":false,\"reason\":\"unknown argument $1\"}"; exit 2 ;;
  esac
done

refuse() { echo "{\"closed\":false,\"reason\":\"$1\"}"; exit 2; }

[ -n "${KONSOLE_DBUS_SERVICE:-}" ] && [ -n "${KONSOLE_DBUS_SESSION:-}" ] \
  || refuse "not running inside a Konsole session (KONSOLE_DBUS_SERVICE/SESSION unset)"
q=$(command -v qdbus6 || command -v qdbus || true)
[ -n "$q" ] || refuse "qdbus6/qdbus not found"

shell=$("$q" "$KONSOLE_DBUS_SERVICE" "$KONSOLE_DBUS_SESSION" org.kde.konsole.Session.processId 2>/dev/null | tr -d '[:space:]')
[[ "$shell" =~ ^[0-9]+$ ]] && [ "$shell" -gt 1 ] || refuse "Konsole did not return a pane process id"

# Walk up from this script. The pane's process must be an ancestor; the process just below it
# on the chain is what runs in the pane (normally claude under bash).
pid=$$; child=""; found=0
while [ -n "$pid" ] && [ "$pid" -gt 1 ]; do
  if [ "$pid" = "$shell" ]; then found=1; break; fi
  child=$pid
  pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
done
[ "$found" = 1 ] || refuse "the pane's process ($shell) is not an ancestor of this script (tmux/screen/ssh in between?)"

# Claude Code's PID: trust $CLAUDE_PID only if it is on our own ancestry chain. An inherited
# CLAUDE_PID (a pane opened from inside another Claude session) would name the wrong process.
claude=""
if [ -n "${CLAUDE_PID:-}" ]; then
  p=$$
  while [ -n "$p" ] && [ "$p" -gt 1 ] && [ "$p" != "$shell" ]; do
    [ "$p" = "$CLAUDE_PID" ] && { claude=$CLAUDE_PID; break; }
    p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
  done
fi
[ -n "$claude" ] || claude="$child"
shell_comm=$(ps -o comm= -p "$shell" | tr -d ' ')
claude_comm=$(ps -o comm= -p "$claude" 2>/dev/null | tr -d ' ')

trap_rc=false
grep -qF 'multisession/close-trap.sh' "$HOME/.bashrc" 2>/dev/null && trap_rc=true
info="\"trap_in_bashrc\":$trap_rc,\"konsole_session\":\"$KONSOLE_DBUS_SESSION\",\"pane_pid\":$shell,\"pane_comm\":\"$shell_comm\",\"claude_pid\":${claude:-null},\"claude_comm\":\"$claude_comm\",\"delay_s\":$delay"

if [ "$dry" = 1 ]; then echo "{\"closed\":false,\"dry_run\":true,$info}"; exit 0; fi

# Detached worker (see close-pane-worker.sh for why it types "exit" rather than signalling).
export Q="$q" SVC="$KONSOLE_DBUS_SERVICE" SESS="$KONSOLE_DBUS_SESSION" SHELLPID="$shell" CPID="$claude" DELAY="$delay"
export CLOSE_LOG="${MULTISESSION_CLOSE_LOG:-/dev/null}"
setsid -f "$(dirname "$(readlink -f "$0")")/close-pane-worker.sh" </dev/null >/dev/null 2>&1

echo "{\"closed\":\"scheduled\",$info}"
