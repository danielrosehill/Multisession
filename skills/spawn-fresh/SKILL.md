---
name: spawn-fresh
description: Start the next task in a fresh Claude Code session with a clean context. Splits this Konsole pane (or opens a new tab), launches a new named Claude there (its own peer name and session ID), writes a handover, sends it with the built-in SendMessage, and optionally closes this pane. Use on "spawn fresh", "start fresh", "new pane and hand over", "split and hand over", "new session for the next task", "break out to a new session", "context is full, carry on in a new one", "split and hand over", "clear the decks and continue", "clean up the context", "open another Claude here and hand over to it", "new instance in this repo and pass it this". For an idea that needs its own new repo, use breakout instead; for handing to a session that is already running, use handover.
---

# spawn-fresh

The context cleaner. This session has finished a task, or its context is heavy, and the next
piece of work should start clean. You open the new session yourself, beside this one, give it a
name you choose, and hand the work over through Claude Code's own agent-to-agent messaging.

Claude Code has no built-in "continue in a new session" command. `--fork-session` copies the
conversation, which is the opposite of what this skill is for. The parts this skill uses are
built in: `claude --name` (sets the peer name `SendMessage` addresses), `claude --session-id`
(lets you pick the UUID in advance), `ListAgents` and `SendMessage`.

## Parameters

| Parameter | Values | Default |
|---|---|---|
| `task` | what the new session should do next | from the conversation; ask if unclear |
| `name` | peer name for the new session | `<cwd folder, lowercased>-<2–3 word task slug>`, e.g. `multisession-docs-pass` |
| `dir` | where the new session works | current directory |
| `layout` | `split` (a new pane beside this one, Konsole's split view) or `tab` | `split` |
| `direction` | for a split: `right` (side by side) or `down` (stacked) | `right` |
| `close` | close this pane once the new session confirms it read the handover | `yes` |

## 0. Preconditions

- In Konsole, with the shell hooks installed. `spawn-session.sh` checks both and says what is
  missing. If the hooks are missing, offer `scripts/install-shell-hooks.sh`, which appends one
  guarded line to `~/.bashrc`. Don't run it unasked. It takes effect in **new** panes; the tab or
  split it makes is new, so it works straight away.
- Commit and push what should survive. Anything left uncommitted goes in the handover's `## State`.

Scripts are in this plugin's `scripts/`. If `CLAUDE_PLUGIN_ROOT` is empty (skill read from a
catalogue), `multisession:spawn-session` says where to get them, plus `scripts/close-pane.sh` and
`scripts/close-pane-worker.sh`.

## 1. Write the handover first

Use the handover format and the `local` space from the `handover` skill (section 2): a folder
`<local_space>/YYYY-MM-DD_HHMM_<me>_to_<name>_<slug>/HANDOVER.md` (default local space
`~/a2a-workspace`; config `~/.config/multisession/config.json`). Set `to_agent: <name>`, and
put the next task under `## Goal` and `## Next steps`. Write it before launching, so the new
session never waits on you. If the repo already holds the plan (a sprint file, a planning doc), point
at it rather than copying it.

The receiver starts with **nothing**: no memory of this conversation, possibly not the same
skills. Name skills by catalogue id or `SKILL.md` path, not by bare name.

## 2. Launch and hand over

Follow `multisession:spawn-session` with `name`, `dir`, `layout`, `direction`, and this message:

`Handover from <me>. You were started for this task. Read <absolute path>/HANDOVER.md and take it from there. Record what you did under ## Done in that file. Once you have read it, send me one line through SendMessage to confirm. I close my pane only after that.`

Send it with `notify_when_idle: true`. Leave out the closing sentence if `close: no`. If that skill stops at a failure, stop here too and
keep this pane open.

## 3. Close this pane

If `close: yes`, wait for the receipt as in the `handover` skill (section 3a). No receipt means the pane
stays open. With the receipt, run this as your final tool call:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/close-pane.sh" --delay 6
```

Same rules as in the `handover` skill (section 4). It closes only this pane, and it refuses if
it can't prove the pane is its own.

## 4. Report

One line:

> Started `<name>` (session `<uuid>`) in a split <right/below> / a new tab, handed over `<path>`, receipt in. Closing this pane in 6s.

## Hard limits

- **Nothing this session was denied.** Permission boundaries are per session.
- **No secret values** in the handover or the message.
