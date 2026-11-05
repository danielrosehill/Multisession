---
name: setup
description: Set up Multisession on a machine: shell hooks, Konsole close and layout settings, the Konsole profile, the close guard and KWin watch, on this machine or others over SSH, and apply what an update needs. Use on "set up multisession", "set up Konsole like my other machine", "apply my Konsole profile", "save my Konsole profile", "I can't close a tab without a prompt", "install on the other laptop", "update multisession".
---

# setup

Scripts are in this plugin's `scripts/`. If `CLAUDE_PLUGIN_ROOT` is empty, see `spawn-session` section 1.

## This machine

1. **Requirements:** `command -v claude konsole python3 systemctl qdbus6`. Konsole is required for launching
   and restoring. Without systemd user units, skip the watches.
2. **Shell hooks:** `scripts/install-shell-hooks.sh`. It appends one guarded line to `~/.bashrc`, so offer it
   and don't run it unasked. Rerun it after an update: it refreshes `~/.config/multisession/rc.sh`, which
   `grid.sh` checks. New panes pick it up.
3. **Konsole settings:** run `--dry-run` first. Idempotent, and backs up `konsolerc`.

   ```bash
   scripts/konsole-settings.sh --dry-run
   scripts/konsole-settings.sh             # add --no-watch for settings only
   ```

   Whole-window close always asks, a single tab or pane closes without asking, split headers and the tab
   bar show, restore opens side-by-side panes, and the close guard watch is installed.

   Verify: `kreadconfig6 --file konsolerc --group "Notification Messages" --key CloseSingleTab` prints `true`,
   and `systemctl --user is-active konsole-close-guard.path` prints `active`.
4. **KWin watch:** `python3 scripts/compositor_guard.py install-watch`. The PreToolUse hook that blocks
   KWin-crashing commands comes with the plugin. Skills read from a catalogue do not bring hooks.
5. **Profile (optional):**

   ```bash
   scripts/konsole-profile.sh --dry-run
   scripts/konsole-profile.sh              # install templates/konsole/*.profile, set it as default
   scripts/konsole-profile.sh --profile NAME
   scripts/konsole-profile.sh --capture    # copy this machine's default profile into templates/konsole/
   ```

   An existing profile of the same name is backed up. `--capture` needs a git checkout, not the plugin
   cache: review the diff, commit, push.
6. **Report:** what changed. Windows already open keep the old settings until reopened, and the restore
   defaults (`environment.d`) apply from the next login.

**Trap:** if single tabs keep prompting after this, the installed guard is an old one that also removes
`CloseSingleTab`. Rerun `konsole_close_guard.py install-watch` to replace the copy in `~/.local/bin`.

## Another machine over SSH

The user names the hosts, as SSH aliases or `user@host`. Do each in turn and report per host. Nothing needs
root. Run remote commands through a login shell (`ssh H 'bash -lc "..."'`), so `~/.local/bin/claude` is found.

1. **Reach it:** `ssh -o BatchMode=yes -o ConnectTimeout=5 H true`. If that fails, report it and move on.
2. **Requirements:** as above. Without `claude`, see `remote`.
3. **Plugin:** `claude plugin marketplace add <marketplace>`, then `claude plugin install multisession@<marketplace>`.
   If `marketplace add` says the source doesn't match its `extraKnownMarketplaces` entry, H's settings has a stale
   entry. Back up the file and correct the source, then rerun.
4. **Guards**, from the installed copy:

   ```bash
   ssh H 'P=$(ls -d ~/.claude/plugins/cache/*/multisession/*/ | sort -V | tail -1);
          python3 "$P/scripts/konsole_close_guard.py" fix;
          XDG_RUNTIME_DIR=/run/user/$(id -u) python3 "$P/scripts/konsole_close_guard.py" install-watch;
          XDG_RUNTIME_DIR=/run/user/$(id -u) python3 "$P/scripts/compositor_guard.py" install-watch;
          python3 "$P/scripts/konsole_close_guard.py" check --json'
   ```

   `XDG_RUNTIME_DIR` lets `systemctl --user` work over SSH. If the user isn't logged in on H, `install-watch` fails.
   Report that. The `fix` still stands.
5. Never run `konsole_close_guard.py test` over SSH: it opens a window in front of whoever is there.

## After an update

`claude plugin marketplace update <marketplace>`, then `claude plugin update multisession@<marketplace>`. Then, if
installed, rerun `install-shell-hooks.sh` and `konsole_close_guard.py install-watch`, because both keep copies
that don't follow updates, and run `check`. New or changed skills load in new sessions.
