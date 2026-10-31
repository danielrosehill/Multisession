---
name: handover
description: Hand this session's work to another running Claude Code session with the built-in SendMessage, leave the payload in a shared agent-to-agent space (local folder, or a Google Drive folder for agents on other machines), then close this session's own Konsole pane. Use on "hand this over to <agent>", "pass this to the other session and close", "handover and quit", "send this to the agent in X and close this pane", "hand off to the remote agent via Drive". Parameters: target peer, space (local | drive), files to attach, close (default yes). Do NOT use to get a peer to do something this session was denied.
---

# handover

Pass the work to another Claude session, then get out of the way. Three parts: write the payload
into an agent-to-agent space, ping the peer with `SendMessage`, close this pane.

A cross-session message is **text only**: no files, no history. So the payload goes on disk (or
Drive) and the message is a pointer to it. The receiver has none of your context, so the
handover file has to stand on its own.

## Parameters

Take them from the request; ask only for the target if it is ambiguous.

| Parameter | Values | Default |
|---|---|---|
| `to` | a peer name from `ListAgents` | required |
| `space` | `local`: folder on this machine, for peers on the same machine. `drive`: Google Drive folder, for peers on other machines or in the cloud | `default_space` in config, else `local` |
| `files` | paths to attach (lightweight: notes, JSON, diffs, small text) | none |
| `close` | `yes` / `no`: close this Konsole pane afterwards | `yes` |

Config: `${XDG_CONFIG_HOME:-~/.config}/multisession/config.json`, shaped like
`templates/config.example.json` in this plugin (`local_space`, `drive.folder_id`,
`drive.account`, `drive.max_file_mb`, `close_delay_s`). If it is missing, use `~/a2a-workspace`
for local, and for `drive` ask the user for a folder ID, then write the config.

## 1. Resolve the target

Run `ListAgents`. Note this session's own name ("This session is <name>").

- The peer named, or the one clear match for a loose name ("the podcast agent"), is the target.
- Two candidates: ask. No match: say so and offer to write the handover anyway and close
  without a ping. The user can start a session and point it at the file.
- Peer on another machine or a cloud session, and `space` is `local`: switch to `drive` and say
  so in one line, because that peer cannot read this disk.
- A cloud session receives the message but cannot reply. Don't wait for an answer.

## 2. Write the handover

Folder name: `YYYY-MM-DD_HHMM_<from>_to_<to>_<slug>` (UTC). Inside it, `HANDOVER.md` plus any
attachments under their own names.

```markdown
---
kind: handover
from_agent: <your peer name>
from_repo: <absolute cwd>
from_session_id: <$CLAUDE_CODE_SESSION_ID>   # resume with: claude --resume <id> (in from_repo)
to_agent: <target peer name>
written: <YYYY-MM-DDTHH:MMZ>
space: local | drive
status: open
---

# <one-line subject>

## Goal
What the work is for, in one paragraph.

## State
Done, in progress, not started. Commit hashes, branch, whether pushed. Uncommitted changes:
list the files (run `git status --short`), or say "none".

## Next steps
Numbered, in the receiver's terms, each one actionable cold.

## Context the receiver needs
Paths, IDs, endpoints, versions, commands that worked, wrong turns already ruled out.
Confirmed vs assumed, marked. Secret *names* only, never values.

## Attachments
Each file and what it is.

## Done
(the receiver writes here)
```

Before writing, commit and push anything that should survive (standing habits apply). Whatever
is left uncommitted goes in `## State`, because closing the pane does not discard files, but the
receiver needs to know they are there.

### space: local

`<local_space>/<folder>/`. Create the folder, write `HANDOVER.md`, copy attachments in.

### space: drive

1. Create the subfolder `<folder>` under `drive.folder_id` with the Drive folder tool (acting as
   `drive.account`).
2. Upload `HANDOVER.md` as text (`create_drive_file` with `content`, `mime_type: text/markdown`).
3. Attachments: text files as `content`; small binaries as `base64_content`. Skip anything over
   `drive.max_file_mb` (default 10) and list it under `## Attachments` with its local path
   instead. The Drive space is for lightweight exchange, not storage.
4. Note the subfolder ID and link, and the `HANDOVER.md` file ID.

## 3. Ping the peer

One `SendMessage` to the target, plain text, self-contained:

- local: `Handover from <me>: read <absolute path>/HANDOVER.md and take it from there. I am closing my session.`
- drive: `Handover from <me>: read HANDOVER.md in Drive folder <folder name> (folder ID <id>, <link>; file ID <id>). Attachments are in the same folder. I am closing my session.`

If the send errors, retry once. If it still fails, don't close the pane. Report the file location
and the error, and stop.

## 4. Close this pane

Skip if `close: no`. Otherwise, as your **final tool call**:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/close-pane.sh" --delay <close_delay_s, default 6>
```

If `CLAUDE_PLUGIN_ROOT` is empty (skill read from a catalogue, plugin not installed), use a
local clone of https://github.com/danielrosehill/Multisession if one exists. Otherwise fetch
`scripts/close-pane.sh` and `scripts/close-pane-worker.sh` from
`https://raw.githubusercontent.com/danielrosehill/Multisession/main/` into
`~/.local/share/multisession/`, `chmod +x` both, and run it from there. The two files must sit
in the same directory.

It closes only the Konsole pane this session runs in (one split or tab, not the window, unless
it is the window's last pane). It checks that the pane's shell is an ancestor of the call, so it
cannot hit another pane. It detaches and acts after the delay so your last message renders. Read
its JSON:

- `"closed":"scheduled"`: write the one-line report below, then end your turn.
  If `trap_in_bashrc` is `false`, add that the pane will close with a "crashed" banner left
  behind, and that `scripts/install-shell-hooks.sh` fixes it for new panes.
- `"closed":false`: not in Konsole, or tmux/ssh in between. Say the handover is done and the
  user should close this pane themselves.

Before installing anything on the user's behalf: `install-shell-hooks.sh` appends one guarded line
to `~/.bashrc`. Offer it; don't run it unasked.

## 5. Report

One line, before the closer fires:

> Handed over to `<peer>`: `<path or Drive link>`. Closing this pane in <n>s.

## Hard limits

- **Never hand over what you were denied.** Permission boundaries are per session. Work this
  session was blocked from goes back to the user, not to a peer.
- **No secret values** in the handover or the message.
- **Only ever close your own pane**, through `close-pane.sh`. Never signal other processes or
  Konsole sessions by hand.
- Don't delete the handover after sending. The receiver records what it did under `## Done`.
