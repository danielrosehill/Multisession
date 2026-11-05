#!/usr/bin/env bash
# spawn-fresh.sh: start a new, named Claude Code session in a new Konsole tab, or in a split of
# the pane this script runs in. Prints one JSON line.
#
# Usage: spawn-fresh.sh --name NAME [--dir DIR] [--session-id UUID] [--layout tab|split]
#                       [--direction right|down] [--wait SECONDS]
#   --name        peer name for the new session (claude --name); this is its SendMessage address
#   --dir         working directory for it (default: current directory)
#   --session-id  conversation UUID (claude --session-id); generated if omitted
#   --layout      tab (default) or split
#   --direction   for a split: right (side by side, default) or down (stacked)
#   --wait        seconds to wait for the new session's messaging socket (default 45)
#   MULTISESSION_LAUNCH_CMD (env, testing only): run this instead of claude
#
# Needs the shell hook from shell/multisession-rc.sh in ~/.bashrc (scripts/install-shell-hooks.sh):
# Konsole refuses Session.runCommand/sendText by default, so the new pane's own shell claims a
# pending launch file this script writes. Exit 0 = launched; 2 = refused/failed (JSON says why).
set -u
name=""; dir="$PWD"; sid=""; layout=tab; direction=right; wait_s=45
while [ $# -gt 0 ]; do
  case "$1" in
    --name) name="$2"; shift 2 ;;
    --dir) dir="$2"; shift 2 ;;
    --session-id) sid="$2"; shift 2 ;;
    --layout) layout="$2"; shift 2 ;;
    --direction) direction="$2"; shift 2 ;;
    --wait) wait_s="$2"; shift 2 ;;
    *) echo "{\"launched\":false,\"reason\":\"unknown argument $1\"}"; exit 2 ;;
  esac
done
fail() { echo "{\"launched\":false,\"reason\":\"$1\"${2:+,$2}}"; exit 2; }

[[ "$name" =~ ^[A-Za-z0-9._-]+$ ]] || fail "--name is required: letters, digits, . _ - only"
dir=$(readlink -f "$dir"); [ -d "$dir" ] || fail "no such directory: $dir"
[ -n "$sid" ] || sid=$(cat /proc/sys/kernel/random/uuid)
[[ "$sid" =~ ^[0-9a-f-]{36}$ ]] || fail "--session-id must be a UUID"
case "$layout" in tab|split) ;; *) fail "--layout must be tab or split" ;; esac
case "$direction" in right) horiz=true ;; down) horiz=false ;; *) fail "--direction must be right or down" ;; esac
[ -n "${KONSOLE_DBUS_SERVICE:-}" ] && [ -n "${KONSOLE_DBUS_SESSION:-}" ] && [ -n "${KONSOLE_DBUS_WINDOW:-}" ] \
  || fail "not running inside a Konsole session"
q=$(command -v qdbus6 || command -v qdbus || true); [ -n "$q" ] || fail "qdbus6/qdbus not found"
grep -qF 'multisession/rc.sh' "$HOME/.bashrc" 2>/dev/null || fail "shell hook not installed: run scripts/install-shell-hooks.sh"
W() { "$q" "$KONSOLE_DBUS_SERVICE" "$KONSOLE_DBUS_WINDOW" "org.kde.konsole.Window.$@" 2>/dev/null; }

me=${KONSOLE_DBUS_SESSION##*/}

# Konsole's createSplit starts the new pane with the source pane's *command*. Only split a pane
# whose process is a plain shell (no -c), or the new pane would re-run that command: a
# `konsole -e claude --resume X` pane would resume X twice, and a script pane recurses (seen in
# testing: one split became eighteen).
panepid=$("$q" "$KONSOLE_DBUS_SERVICE" "$KONSOLE_DBUS_SESSION" org.kde.konsole.Session.processId 2>/dev/null | tr -d '[:space:]')
[[ "$panepid" =~ ^[0-9]+$ ]] || fail "Konsole did not return this pane's process id"
mapfile -d '' -t pargv < "/proc/$panepid/cmdline"
pbase=$(basename -- "${pargv[0]#-}")
mode=$layout; why=""
[ "$layout" = tab ] || case "$pbase" in bash|zsh|fish|sh|dash|ksh) ;; *) mode=tab; why="pane runs '$pbase', not a shell" ;; esac
[ "$layout" = tab ] || for a in "${pargv[@]:1}"; do [ "$a" = "-c" ] && { mode=tab; why="pane runs '$pbase -c ...'"; }; done
# Fallback: a new tab (Window.newSession) starts the profile's plain shell, never a copy.

# Find this session's view (split mode only). There is no session->view getter; setCurrentView(v) then
# currentSession() reveals it. Views are tried in hierarchy order.
view=""
views=$(W viewHierarchy | sed 's/([0-9]*)//g' | grep -oE '[0-9]+')
[ "$mode" = tab ] && views=""
for v in $views; do
  W setCurrentView "$v" >/dev/null
  [ "$(W currentSession | tr -d '[:space:]')" = "$me" ] && { view=$v; break; }
done
[ "$mode" = tab ] || [ -n "$view" ] || fail "could not find this session's view in the window"

# Pending launch file, claimed by the new pane's shell hook.
ld="${XDG_RUNTIME_DIR:-/tmp}/multisession-launch"; mkdir -p "$ld"; chmod 700 "$ld"
pf="$ld/pending.$(date +%s%N).$$"
if [ -n "${MULTISESSION_LAUNCH_CMD:-}" ]; then
  cmd="$MULTISESSION_LAUNCH_CMD"
else
  cmd="claude --name $(printf %q "$name") --session-id $(printf %q "$sid")"
fi
{
  echo "# target: $KONSOLE_DBUS_SERVICE $KONSOLE_DBUS_WINDOW"
  echo "# created: $(date +%s)"
  echo "# multisession launch for $name"
  echo "cd -- $(printf %q "$dir") && $cmd"
} > "$pf.tmp" && mv "$pf.tmp" "$pf"

before=$(W sessionList | sort -n | tr '\n' ' ')
if [ "$mode" = split ]; then
  [ "$(W createSplit "$view" "$horiz" | tr -d '[:space:]')" = "true" ] || { rm -f "$pf"; fail "Konsole createSplit failed"; }
else
  W newSession "" "$dir" >/dev/null || { rm -f "$pf"; fail "Konsole newSession failed"; }
fi
new=""; for i in $(seq 20); do
  for s in $(W sessionList); do case " $before " in *" $s "*) ;; *) new=$s ;; esac; done
  [ -n "$new" ] && break; sleep 0.25
done

claimed=false; for i in $(seq 40); do [ -e "$pf" ] || { claimed=true; break; }; sleep 0.25; done
if [ "$claimed" = false ]; then
  rm -f "$pf"
  fail "the new pane did not claim the launch (shell hook not loaded there?)" "\"konsole_session\":\"${new:-null}\""
fi

# Ready = the new Claude has its cross-session messaging socket open.
ready=false; cpid=null
if [ -z "${MULTISESSION_LAUNCH_CMD:-}" ] && [ -n "$new" ]; then
  shellpid=$("$q" "$KONSOLE_DBUS_SERVICE" "/Sessions/$new" org.kde.konsole.Session.processId 2>/dev/null | tr -d '[:space:]')
  end=$(( $(date +%s) + wait_s ))
  while [ "$(date +%s)" -lt "$end" ]; do
    for c in $(pgrep -P "$shellpid" -x claude 2>/dev/null); do
      cpid=$c; [ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/cc-socks/$c.sock" ] && { ready=true; break 2; }
    done
    sleep 0.5
  done
fi
echo "{\"launched\":true,\"name\":\"$name\",\"session_id\":\"$sid\",\"dir\":\"$dir\",\"konsole_session\":${new:-null},\"mode\":\"$mode\",\"mode_reason\":\"$why\",\"split_from_view\":${view:-null},\"direction\":\"$direction\",\"claude_pid\":$cpid,\"messaging_ready\":$ready}"
