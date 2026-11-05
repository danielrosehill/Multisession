---
name: guard
description: Protect a window full of Claude sessions and find out what killed one. Turns Konsole's close prompts back on and keeps them on, blocks commands known to crash KWin, watches for KWin crashes, and diagnoses a loss (a silent close, a Konsole crash or a KWin crash). Use on "terminal closed without asking", "why does Konsole keep crashing", "it happened again", "lost all my sessions again".
---

# guard

Restore first (`restore`), then diagnose. Three causes have been seen:

| What the logs show | Cause | Prevention |
| --- | --- | --- |
| No Konsole core dump at the loss time | The window was **closed**: a click on the X with prompts suppressed | Close guard |
| Konsole SIGSEGV in `QWaylandShmBackingStore::recreateBackBufferIfNeeded`, after a KWin crash | KWin crashed earlier and left the window damaged. A later repaint killed it | Find the KWin trigger, `compositor_guard.py install-watch` |
| `kwin_wayland` SIGSEGV | The compositor crashed. Konsole may die at once or minutes later | `compositor_guard.py culprits`, then fix or block the trigger |

## Diagnose

```bash
C="${CLAUDE_PLUGIN_ROOT}/scripts/compositor_guard.py"   # empty root: see spawn-session section 1
coredumpctl list --since -1d                            # what crashed, when
coredumpctl info <pid> | grep -A30 "Stack trace of thread <pid>"
python3 "$C" check                                      # last KWin crash, Konsole windows at risk
python3 "$C" culprits --window 10                       # commands sessions ran just before it
python3 "$C" culprits --at "2026-10-28 16:36:14"
```

1. Get the loss time from `session_restore.py list`.
2. `coredumpctl list --since -1d`. No `konsole` entry near that time means a silent close. A `konsole`
   entry: read its stack. A `kwin_wayland` entry shortly before it means KWin was the cause.
3. For a KWin crash, run `culprits`. A command within a second or so of the crash is the prime suspect.
   Also read `journalctl --user --since ... --until ... -o short-precise`. Timing is evidence, not proof,
   unless the stack matches the command.
4. If the trigger is a command pattern, add it to `BLOCKED` in `compositor_guard.py` with a dated
   comment, and record it in `docs/incidents/`.
5. Make sure the watch runs (`systemctl --user is-active kwin-crash-watch.service`). For every at-risk
   Konsole that `check` lists, tell the user to move its sessions to a new window before it dies.

Known triggers, both blocked by the hook:

- **Hand-sent `org.kde.kconfig.notify.ConfigChanged`** (2026-10-28). `dbus-send` sends `a{ss}`, KConfigWatcher
  expects `a{saay}`, and KWin 6.6.6 segfaults unpacking it. `kwriteconfig6 ... --notify` is correct.
- **Restarting KWin** (`kwin_wayland --replace`, `pkill kwin`, `kquitapp6 kwin`). Same aftermath as a crash.

## Close guard

Konsole asks before a window close kills running programs, unless "Don't ask again" was ticked once.
That answer lives in `~/.config/konsolerc`, `[Notification Messages]` (`CloseAllTabs`, `CloseAllEmptyTabs`).
After that a stray click on the X closes everything, and no crash shows in the logs.

```bash
G="${CLAUDE_PLUGIN_ROOT}/scripts/konsole_close_guard.py"
python3 "$G" check            # exit 1 = prompts suppressed. Lists Konsole processes older than the last fix
python3 "$G" fix              # back up konsolerc, remove the window-level keys
python3 "$G" tab-prompt off   # single tabs close without asking (`on` to ask)
python3 "$G" install-watch    # systemd path unit: re-run fix whenever konsolerc changes
python3 "$G" test             # throwaway window. Exit 0 = the prompt refused the close
```

Run `check`, `fix`, `tab-prompt off` (unless the user wants tab prompts), `install-watch`. The watch notifies
the desktop when it undoes a tick. Tell the user that **windows already open keep the old setting** until
closed. `test` flashes a window on screen, so say so first, and never run it over SSH.

`install-watch` copies the guard to `~/.local/bin`, which does not follow plugin updates. Rerun it after an
update.

## Limits

- The dialog's default button is "Close Window", so Enter still closes.
- Konsole skips the check when the foreground process has the tab's own program name, so a tab started as
  `konsole -e claude` is not protected. Start a shell and run `claude` from it, as Multisession's
  launchers do.
