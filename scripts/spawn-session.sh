#!/usr/bin/env bash
# spawn-session.sh: start a new, named Claude Code session in a split of the Konsole pane this
# script runs in, or in a new tab. Prints one JSON line.
#
# Usage: spawn-session.sh --name NAME [--dir DIR] [--session-id UUID] [--layout split|tab|window]
#                       [--direction right|down] [--wait SECONDS] [--terminal]
#   --name        peer name for the new session (claude --name); this is its SendMessage address
#   --dir         working directory for it (default: current directory)
#   --session-id  conversation UUID (claude --session-id); generated if omitted
#   --layout      split (default), tab, or window (a new Konsole window)
#   --direction   for a split: right (side by side, default) or down (stacked)
#   --terminal    open a plain shell in --dir, with no Claude. --name is then optional
#   --wait        seconds to wait for the new session's messaging socket (default 45)
#   MULTISESSION_LAUNCH_CMD (env, testing only): run this instead of claude
#
# Needs the shell hook from shell/multisession-rc.sh in ~/.bashrc (scripts/install-shell-hooks.sh):
# Konsole refuses Session.runCommand/sendText by default, so the new pane's own shell claims a
# pending launch file this script writes. Exit 0 = launched; 2 = refused/failed (JSON says why).
set -u
name=""; dir="$PWD"; sid=""; layout=split; direction=right; wait_s=45; terminal=false
while [ $# -gt 0 ]; do
  case "$1" in
    --name) name="$2"; shift 2 ;;
    --dir) dir="$2"; shift 2 ;;
    --session-id) sid="$2"; shift 2 ;;
    --layout) layout="$2"; shift 2 ;;
    --direction) direction="$2"; shift 2 ;;
    --wait) wait_s="$2"; shift 2 ;;
    --terminal) terminal=true; shift ;;
    *) echo "{\"launched\":false,\"reason\":\"unknown argument $1\"}"; exit 2 ;;
  esac
done
fail() { echo "{\"launched\":false,\"reason\":\"$1\"${2:+,$2}}"; exit 2; }

[ "$terminal" = true ] && [ -z "$name" ] && name=terminal
[[ "$name" =~ ^[A-Za-z0-9._-]+$ ]] || fail "--name is required: letters, digits, . _ - only"
dir=$(readlink -f "$dir"); [ -d "$dir" ] || fail "no such directory: $dir"
[ -n "$sid" ] || sid=$(cat /proc/sys/kernel/random/uuid)
[[ "$sid" =~ ^[0-9a-f-]{36}$ ]] || fail "--session-id must be a UUID"
case "$layout" in tab|split|window) ;; *) fail "--layout must be split, tab or window" ;; esac
case "$direction" in right) horiz=true ;; down) horiz=false ;; *) fail "--direction must be right or down" ;; esac

# A new window needs neither the shell hook nor this pane: Konsole takes the command directly.
# --separate gives it its own process, so its shell can be found from the PID. `exec bash` keeps a
# plain shell in the window once Claude exits.
if [ "$layout" = window ]; then
  command -v konsole >/dev/null || fail "konsole not found"
  if [ "$terminal" = true ]; then
    setsid -f konsole --separate --workdir "$dir" >/dev/null 2>&1 || fail "konsole did not start"
    echo "{\"launched\":true,\"name\":\"$name\",\"dir\":\"$dir\",\"mode\":\"window\",\"terminal\":true}"
    exit 0
  fi
  wcmd="${MULTISESSION_LAUNCH_CMD:-claude --name $(printf %q "$name") --session-id $(printf %q "$sid")}"
  nohup setsid konsole --separate --workdir "$dir" -e bash -ic "$wcmd; exec bash" >/dev/null 2>&1 &
  kp=$!
  ready=false; cpid=null; end=$(( $(date +%s) + wait_s ))
  while [ -z "${MULTISESSION_LAUNCH_CMD:-}" ] && [ "$(date +%s)" -lt "$end" ]; do
    for sh in $(pgrep -P "$kp" 2>/dev/null); do
      for c in $(pgrep -P "$sh" -x claude 2>/dev/null); do
        cpid=$c; [ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/cc-socks/$c.sock" ] && { ready=true; break 3; }
      done
    done
    sleep 0.5
  done
  echo "{\"launched\":true,\"name\":\"$name\",\"session_id\":\"$sid\",\"dir\":\"$dir\",\"mode\":\"window\",\"konsole_pid\":$kp,\"claude_pid\":$cpid,\"messaging_ready\":$ready}"
  exit 0
fi

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

# setCurrentView only moves focus while the Konsole window is active, so with another app in front
# the walk above finds nothing. Session and view ids both rise with creation, so the Nth session
# by id sits in the Nth view by id. That is inferred, and a wrong guess would split a pane it
# has not checked, so it is used only if every pane is a plain shell. Otherwise: a tab.
plain_shell() {
  local argv b a; mapfile -d '' -t argv < "/proc/$1/cmdline" 2>/dev/null || return 1
  [ "${#argv[@]}" -gt 0 ] || return 1
  b=$(basename -- "${argv[0]#-}")
  case "$b" in bash|zsh|fish|sh|dash|ksh) ;; *) return 1 ;; esac
  for a in "${argv[@]:1}"; do [ "$a" = "-c" ] && return 1; done
  return 0
}
if [ "$mode" = split ] && [ -z "$view" ]; then
  mapfile -t sess < <(W sessionList | sort -n)
  mapfile -t vs < <(printf '%s\n' $views | sort -n)
  safe=true; [ "${#sess[@]}" -eq "${#vs[@]}" ] || safe=false
  for s in "${sess[@]}"; do
    p=$("$q" "$KONSOLE_DBUS_SERVICE" "/Sessions/$s" org.kde.konsole.Session.processId 2>/dev/null | tr -d '[:space:]')
    plain_shell "$p" || safe=false
  done
  if [ "$safe" = true ]; then
    for i in "${!sess[@]}"; do [ "${sess[$i]}" = "$me" ] && view=${vs[$i]}; done
  fi
  if [ -n "$view" ]; then why="Konsole not focused: view matched by creation order"
  else mode=tab; why="Konsole not focused and the view could not be matched safely"; fi
fi

# Pending launch file, claimed by the new pane's shell hook.
ld="${XDG_RUNTIME_DIR:-/tmp}/multisession-launch"; mkdir -p "$ld"; chmod 700 "$ld"
pf="$ld/pending.$(date +%s%N).$$"
if [ "$terminal" = true ]; then
  cmd=":"
elif [ -n "${MULTISESSION_LAUNCH_CMD:-}" ]; then
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
if [ "$terminal" = false ] && [ -z "${MULTISESSION_LAUNCH_CMD:-}" ] && [ -n "$new" ]; then
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
