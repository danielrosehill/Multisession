---
name: spawn-session
description: Open a new named Claude Code session in a Konsole split view or tab, in any directory, confirm it is up, and send it a pointer to its task. The building block other skills call. Use directly on "open a new Claude here", "start a Claude in <dir>", "new Claude in a split", "new Claude in a tab", "new pane with Claude". This session keeps running. To also move your own work across and close this pane, use spawn-fresh.
---

# spawn-session

Start one new Claude Code session and tell it where its work is. Nothing else: the caller decides
what the work is, and this session carries on afterwards.

**Calling this from another skill:** write the task to disk first, then follow this skill with the
parameters below. A cross-session message carries text only, so the message is always a pointer to
a file, never the payload.

## Parameters

| Parameter | Values | Default |
|---|---|---|
| `name` | peer name, letters, digits, `.`, `_`, `-`. It is the `SendMessage` address | required; `<folder, lowercased>-<2–3 word task slug>` |
| `dir` | where the new session works | current directory |
| `layout` | `split` (a new pane beside this one, Konsole's split view), `tab`, or `window` (a new Konsole window) | `split` |
| `terminal` | open a plain shell with no Claude (`--terminal`); `name` is then optional | off |
| `direction` | for a split: `right` or `down` | `right` |
| `message` | the pointer to send, naming an absolute path | none: launch only |

Say "tab" or "split" and it is honoured. Otherwise use `split`.

## 1. Launch

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/spawn-session.sh" --name <name> --dir <dir> --layout <split|tab|window> --direction <right|down>
```

If `CLAUDE_PLUGIN_ROOT` is empty (skill read from a catalogue), use a local clone of
https://github.com/danielrosehill/Multisession, or fetch `scripts/spawn-session.sh` and
`shell/multisession-rc.sh` from
`https://raw.githubusercontent.com/danielrosehill/Multisession/master/`, keeping the same layout.

Needs Konsole and the shell hook. The script checks both and says what is missing. If the hook is
missing, offer `scripts/install-shell-hooks.sh`, which appends one guarded line to `~/.bashrc`.
Don't run it unasked.

The script writes a one-shot launch file and splits this pane or opens a tab. The new shell claims
the file and runs `claude --name <name> --session-id <uuid>` in `<dir>`, then the script waits for
the new Claude's messaging socket. A split is refused when this pane's process isn't a plain shell
(a `claude --resume` pane, a `bash -c` pane), because the split would copy that command, so it
opens a tab instead (`"mode":"tab"`).

Read the JSON:

- `"launched":true, "messaging_ready":true`: go on.
- `"launched":true, "messaging_ready":false`: the pane is up but Claude is slow, or stopped at a
  prompt. A directory Claude has not seen before may ask whether to trust it. Run `ListAgents`.
  If `<name>` isn't listed, tell the user to look at the new pane, and stop.
- `"launched":false`: report `reason` and stop. The task file is written, so the user can start a
  session there and point it at the file.

## 2. Send the pointer

Skip this if there is no `message`.

1. `ListAgents` and confirm a row named exactly `<name>`. If two rows share it, use the `[ref]` form.
2. `SendMessage` to `<name>`.
3. If the send errors, retry once. If it still fails, give the user the file path and the new pane,
   and stop.

A successful send means the message reached the session, not that it was read.

## Hard limits

- **One new session per call.** For several, use `compose`. If a launch fails, report it and stop.
  Retrying blind stacks up panes.
- **Nothing this session was denied.** Permission boundaries are per session.
- **No secret values** in the message.
- Never close another session's pane.
