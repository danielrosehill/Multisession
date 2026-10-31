#!/usr/bin/env bash
# Detached worker for close-pane.sh. Do not call directly. Env from close-pane.sh:
# Q (qdbus binary), SVC, SESS (Konsole D-Bus service and session path), SHELLPID (the pane's
# process), CPID (Claude Code's PID), DELAY (seconds), CLOSE_LOG (trace target, /dev/null default).
#
# Konsole closes a pane only when its process exits cleanly. A shell killed by a signal leaves
# the pane open with "Warning: Program '...' crashed." (seen in testing, Konsole 25.12.3). So:
# stop Claude, then, once the shell is idle at its prompt (foregroundProcessId == shell), create a
# flag file and send SIGALRM, which the shell-rc trap (shell/multisession-close-trap.sh) turns into
# a clean exit 0. Session.sendText
# would be the obvious route but Konsole refuses it by default ("Security sensitive DBus API is
# disabled in the settings"), and Konsole exports no close-session action over D-Bus.
# Without the trap, SIGALRM kills bash by signal and the pane stays open with the warning (the
# processes are still gone); SIGHUP/SIGKILL are the last fallback.
exec 2>>"${CLOSE_LOG:-/dev/null}"; set -x
sleep "$DELAY"
if [ -n "$CPID" ] && [ "$CPID" != "$SHELLPID" ]; then
  kill -TERM "$CPID" 2>/dev/null
  for i in $(seq 20); do kill -0 "$CPID" 2>/dev/null || break; sleep 0.5; done
  kill -0 "$CPID" 2>/dev/null && kill -KILL "$CPID" 2>/dev/null && sleep 0.5
  # The pane's shell exits cleanly (status 0) on a flagged SIGALRM if its rc sourced
  # shell/multisession-close-trap.sh. Interactive bash runs that trap at an idle prompt.
  for i in $(seq 10); do
    fg=$("$Q" "$SVC" "$SESS" org.kde.konsole.Session.foregroundProcessId 2>/dev/null | tr -d '[:space:]')
    [ "$fg" = "$SHELLPID" ] && break; sleep 0.3
  done
  flag="${XDG_RUNTIME_DIR:-/tmp}/multisession-close.$SHELLPID"
  : > "$flag"
  kill -ALRM "$SHELLPID" 2>/dev/null
  for i in $(seq 10); do kill -0 "$SHELLPID" 2>/dev/null || exit 0; sleep 0.5; done
  rm -f "$flag"   # trap not installed in that shell: fall through
fi
kill -HUP "$SHELLPID" 2>/dev/null; sleep 2
kill -0 "$SHELLPID" 2>/dev/null && kill -KILL "$SHELLPID" 2>/dev/null
exit 0
