# Closing one Konsole pane from inside Claude Code

Used by `skills/handover` through `scripts/close-pane.sh` (worker: `scripts/close-pane-worker.sh`).
Worked out and tested 2026-10-31 on Konsole 25.12.3, bash 5.3.9, Claude Code 2.1.316, KDE
Plasma 6 on Wayland (Ubuntu, kernel 7.0).

## What works

1. `close-pane.sh` reads `$KONSOLE_DBUS_SERVICE` and `$KONSOLE_DBUS_SESSION` (Konsole sets both
   in every pane) and asks Konsole for the pane's process:
   `qdbus6 $KONSOLE_DBUS_SERVICE $KONSOLE_DBUS_SESSION org.kde.konsole.Session.processId`.
2. It walks up its own process ancestry and refuses unless that PID is an ancestor. This is the
   guarantee that it only closes the pane it was called from. tmux/screen/ssh in between break
   the chain, and it refuses (exit 2, JSON `"closed":false`).
3. Claude Code's PID is `$CLAUDE_PID` **only if that PID is on the ancestry chain**, otherwise
   the process just below the pane shell. An inherited `CLAUDE_PID` (a pane opened from inside
   another Claude session) names a different, live Claude. The sandbox test showed this.
4. A detached worker (`setsid -f`) waits `--delay` seconds so the agent's last reply renders,
   SIGTERMs Claude, waits until the shell is idle (`Session.foregroundProcessId == processId`),
   creates the flag file `$XDG_RUNTIME_DIR/multisession-close.<shellpid>` and sends **SIGALRM**.
5. The shell's rc has sourced `shell/multisession-close-trap.sh`:
   `trap '[ -e flag ] && { rm -f flag; exit 0; }' ALRM`. Bash exits 0 and Konsole closes the
   pane. Other splits, tabs and the window are untouched. If it was the window's last pane,
   the window closes, as it would for any last pane.
6. Fallback, trap not loaded: SIGALRM kills bash by signal (or SIGHUP, then SIGKILL). The
   processes are gone, but the pane stays with the banner below.

Install the trap: `scripts/install-close-trap.sh` copies it to
`~/.config/multisession/close-trap.sh` and appends one guarded source line to `~/.bashrc`.
Panes opened before that need `source ~/.bashrc` or a new pane.

## Wrong turns, ruled out

- **There is no close method on D-Bus.** `org.kde.konsole.Session` has none.
  `org.kde.konsole.Window` has `newSession`, `setCurrentSession` and so on, but no close.
  `/konsole/MainWindow_1/actions/*` exports only window actions (fullscreen, configure,
  menubar…), not `close-session`.
- **Killing the shell by signal leaves the pane open.** Konsole closes a pane only on a clean
  exit. A signal death shows `Warning: Program 'bash …' crashed.` and keeps the pane.
  Interactive bash ignores SIGTERM, and SIGHUP kills it by signal.
- **Typing `exit` with `Session.sendText` / `runCommand` is refused:**
  `org.freedesktop.DBus.Error.AccessDenied: Security sensitive DBus API is disabled in the
  settings.` That is Konsole's default. Turning it on would let any process type into any pane,
  so this plugin doesn't. (When it did run, early on, `\n` was the wrong key anyway: Enter is
  `\r`.)
- **A SIGUSR1/SIGUSR2 trap doesn't fire at an idle prompt.** Bash defers it until the next
  keypress. HUP, INT, TERM and ALRM traps run immediately (tested in a pty). HUP is out, because
  trapping it changes what happens when Konsole itself closes a pane. TERM and INT are signals
  people send to shells. ALRM is the one nothing sends to a shell, and the flag file makes even
  a stray one harmless.
- **TIOCSTI** (inject keystrokes into the tty) is disabled on modern kernels
  (`dev.tty.legacy_tiocsti=0`). Not pursued.

## How it was tested

In the headless KDE sandbox (`kde-agent-workspace`, `kagent.py sandbox start`), never on the
live desktop: `konsole --separate --tabs-from-file` with a "victim" tab running
`pane bash → bash -c (stands in for claude) → close-pane.sh` and a "survivor" tab. Passing
result: `Window.sessionList` went from `1 3` to `3`, no fallback used, survivor alive.

Not yet tested: a real Claude Code process receiving SIGTERM (assumed to exit, verified only
with a stand-in), and panes where `claude` is the pane's process with no shell (then Claude's
own exit status decides whether Konsole closes the pane).
