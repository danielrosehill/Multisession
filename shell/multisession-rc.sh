# multisession: shell hooks for Konsole panes. Source from ~/.bashrc
# (scripts/install-shell-hooks.sh does it). Interactive bash only; a no-op elsewhere.
case $- in *i*) ;; *) return 0 2>/dev/null || exit 0 ;; esac

# 1. Clean pane close (scripts/close-pane.sh). Exits 0 on SIGALRM only if the closer created a
#    flag file for this shell's PID, so a stray SIGALRM is ignored. Why ALRM: interactive bash
#    runs HUP/INT/TERM/ALRM traps at an idle prompt at once but defers USR1/USR2 until the next
#    keypress (tested bash 5.3.9), and nothing else sends ALRM to a shell.
trap '[ -e "${XDG_RUNTIME_DIR:-/tmp}/multisession-close.$$" ] && { rm -f "${XDG_RUNTIME_DIR:-/tmp}/multisession-close.$$"; exit 0; }' ALRM

# 2. Launch claim (scripts/spawn-session.sh). Konsole refuses Session.runCommand/sendText by
#    default, so a new split cannot be told what to run. Instead the spawner writes a pending
#    launch file naming this Konsole window, then splits; the new pane's shell claims it here
#    (atomic mv, so exactly one pane takes it) and runs it at its first prompt.
#    A file for a window that does not exist yet (scripts/grid.sh) names the Konsole PID instead,
#    with "# target-pid:", because KONSOLE_DBUS_SERVICE is a unique bus name such as :1.3107 that
#    cannot be known before the window starts. Konsole is this shell's parent.
_multisession_launch=""
if [ -n "${KONSOLE_DBUS_WINDOW:-}" ] && [ -d "${XDG_RUNTIME_DIR:-/tmp}/multisession-launch" ]; then
  _ms_d="${XDG_RUNTIME_DIR:-/tmp}/multisession-launch"; _ms_now=$(date +%s)
  for _ms_f in "$_ms_d"/pending.*; do
    [ -f "$_ms_f" ] || continue
    grep -qxF "# target: ${KONSOLE_DBUS_SERVICE:-} ${KONSOLE_DBUS_WINDOW}" "$_ms_f" \
      || grep -qxF "# target-pid: $PPID" "$_ms_f" || continue
    _ms_c=$(sed -n 's/^# created: //p' "$_ms_f")
    if [ $(( _ms_now - ${_ms_c:-0} )) -gt 60 ]; then rm -f "$_ms_f"; continue; fi
    mv "$_ms_f" "$_ms_d/claimed.$$" 2>/dev/null || continue
    _multisession_launch="$_ms_d/claimed.$$"; break
  done
  unset _ms_d _ms_now _ms_f _ms_c
fi
if [ -n "$_multisession_launch" ]; then
  _multisession_first_prompt() {
    [ -n "$_multisession_launch" ] || return 0
    local f="$_multisession_launch"; _multisession_launch=""
    . "$f"; rm -f "$f"
  }
  PROMPT_COMMAND="_multisession_first_prompt${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
fi
