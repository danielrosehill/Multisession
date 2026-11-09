# Multisession

Coordinate Claude Code sessions: start them, hand work between them, lay them out in Konsole, bring them
back after a crash, guard against losing them, reach the user when they are away, and run sessions on other
machines. Thirteen skills, with options inside them rather than a skill per variation.

Sessions on one machine talk through Claude Code's own `SendMessage`. Repos talk through a mailbox: agent A
writes a markdown file into repo B's `a2a/` folder, and B finds it when its session starts. No server, no broker.

Konsole on KDE Plasma is what the launching, closing and guard parts need. `send`, `inbox`, `notify` and
`remote` work anywhere.

## A handover closes on a receipt

A successful `SendMessage` means the message reached a session, not that its Claude read it. So `handover`,
`spawn-fresh`, `continue-sprint` and `compose` ask the receiver for one line back, and close the pane only then. A
timeout, an idle notice or a held message keeps the pane open. Details: `skills/handover`, section 3a.

## Layouts (`multisession:compose`)

One plain request becomes a list of actions. Built in: "new Claude here", "new Claude at <path>", "Claude grid" (2 or
4 panes, `scripts/grid.sh`), "Claude and a shell", "terminal here", "VS Code here". Your own presets go in
`~/.config/multisession/config.json`.

## Restore and guard

`multisession:restore` finds the sessions that died together in a crash, or the last N, or ones picked from a menu,
and resumes each in its repo. `multisession:guard` keeps Konsole's close prompts on, blocks commands known to crash
KWin through a PreToolUse hook, watches for KWin crashes, and works out what killed a window. Incidents are in
`docs/incidents/`.

## Notify (`multisession:notify`)

A desktop notification, or a phone call through Vapi saying what Claude is stuck on. Calls need a real reason, and
the script refuses without one. `--dry-run` prints the payload and calls nothing.

Calling anyone but you has stricter rules, from the Claude-Voice-Notifier design: it says it is an AI first, you approve a
brief every time, it only rings people on your list and within their waking hours, and it can't take a message back.

## Remote (`multisession:remote`)

Check, install, log in, sync settings, connect a skills library, start background sessions, message them, move a
session across and clone repos, on any machine you can reach. Your hosts live in your config. Parts marked
**Template** came from one setup, so adapt them.

## Spawn fresh (`multisession:spawn-fresh`, v0.8.0)

The context cleaner. At the end of a task, split this Konsole pane, start a new Claude Code
session in it with a name and session ID chosen up front (`claude --name … --session-id …`),
write `HANDOVER.md`, send it with `SendMessage`, and close this pane. `--layout tab` opens a new
tab instead. A pane running a command rather than a plain shell always gets a tab, because a
split would re-run that command. Script: `scripts/spawn-session.sh`.

## Handover and close (`multisession:handover`, v0.5.0)

Pass this session's work to another running Claude session and close this one:

1. Writes `HANDOVER.md` (goal, state, next steps, context, attachments) into an agent-to-agent
   space: `local` (a folder on this machine, default `~/a2a-workspace`) for peers on the same
   machine, or `drive` (a Google Drive folder) for peers on other machines or in the cloud.
   Lightweight files only on Drive (default cap 10 MB each).
2. Pings the peer with the built-in `SendMessage`, pointing at the file.
3. Closes **only this session's Konsole pane** (`scripts/close-pane.sh`): not the window, not
   the other splits or tabs.

Config: `~/.config/multisession/config.json` (see `templates/config.example.json`).

How the pane close works, and why: [`docs/konsole-pane-close.md`](docs/konsole-pane-close.md).
One-time setup for a clean close and for split launches: `scripts/install-shell-hooks.sh` (adds one guarded line to
`~/.bashrc`; new panes only).

## Asynchronous messages (`send`, `inbox`)

**Status: v0.4.0, 2026-10-22.** The pattern has been run once end to end, by hand, before it was a
plugin. The skills are new. See [`docs/verification.md`](docs/verification.md) for what is
confirmed and what is not.

## Why a file, not a chat

Two agents in two repos rarely need to talk at the same moment. Usually one learns something the
other will need later:

> The agent in `ASR-Training` starts a training run for a voice model. The agent in
> `My-Weird-Prompts` is planning an episode that will use it. The first agent knows things the
> second needs: the run will take about 50 minutes, the model will be published to a **gated**
> repo, and the second repo's Modal image will therefore need a secret it never needed before.

The workaround that worked, on 2026-10-22: tell agent A to create an `a2a/` folder in repo B and
write B a message; tell agent B to read it. B acted on it the same minute, added the secret to its
Modal image, recorded what it did under `## Done`, and left the steps that depended on the
published model for later.

That is the whole design. This plugin removes the two manual relays (you telling A to write, you
telling B to read) and adds what the run showed was missing: a fixed format, a way for B to notice
mail without being told, and a way for A to say "do this at 16:45".

Claude Code's own cross-session `SendMessage` (2.1.224+) is real-time, but a message is text only,
never files or history, and it reaches only sessions that are running. Here it is the doorbell,
not the letter.

## How it works

```
repo A (sender)                                 repo B (reader)
───────────────                                 ───────────────
multisession:send
  write B/a2a/2026-10-22_<subject>.md  ───────▶ a2a/2026-10-22_<subject>.md   status: open
  ListAgents → one peer named b-*?
     yes → SendMessage "new message in a2a/…" ─▶ arrives mid-session
     no  → nothing; the file waits             SessionStart hook: "multisession: 1 open message"
                                                multisession:inbox
                                                  act on "What to do"
                                                  run the readiness check, not the clock
                                                  schedule: → CronCreate one-shot reminder
                                                  append "## Done", status: done
  later: append "## Update" to the same file ─▶ (B reads the update next time)
```

### The message

```markdown
---
kind: request
subject: Meorav v2 ETA and the gated-repo secret
from_repo: /home/user/repos/ASR-Training
from_agent: asr-training-c0
to_repo: /home/user/repos/My-Weird-Prompts
written: 2026-10-22T15:10Z
status: open
schedule:
  - at: 2026-10-22T16:45Z
    do: Run the readiness check. If the model is published, pin its revision and run the smoke test.
---

# Meorav v2 ETA and the gated-repo secret

## What you need to know
## What to do
## How to tell it is ready
## Update      ← only the sender writes here
## Done        ← only the reader writes here
```

Full specification, including the lifecycle and why messages are kept rather than deleted:
[`docs/protocol.md`](docs/protocol.md).

### Reminders

The sender often knows when the reader will need to act, but it cannot schedule anything in another
session. So it asks: a `schedule:` entry with a UTC time and what to do. The reader sets a one-shot
`CronCreate` job in its own session, converting UTC to local time because cron runs in local time.
These jobs are session-only, and the skill says so to the user rather than implying the reminder is
durable.

### Living messages

For a long task, the sender adds `watch: 30m` and keeps **one** message current, rewriting it and
bumping `revision:` as things change. The reader sets a recurring check that greps the revision and
does nothing unless it moved. A ping on each revision is the fast path; the watch is the fallback.
Recurring checks expire after 7 days and live only in the reader's session.

### Message kinds

| `kind` | Use |
|---|---|
| `note` | Information the other agent should have. |
| `request` | Something the other agent should do. |
| `founding` | The first brief of a brand-new repo, written by `multisession:breakout` when an idea does not belong in the current repo. See [`docs/breakout.md`](docs/breakout.md). |
| `handover` | To the next session in the *same* repo. For the full session-to-session workflow, use `multisession:handover`. |

## Skills

| Skill | Side | What it does |
|---|---|---|
| `multisession:spawn-fresh` | A | Split this pane (or open a new tab), launch a new named Claude, hand it the next task, close this pane. |
| `multisession:continue-sprint` | A | Refresh the context mid-sprint: write a handover of decisions, approvals, state and traps, then carry on in a new session |
| `multisession:compose` | A | Mix actions in one request: handover, sessions in a split, tab or window, a plain terminal, Dolphin, an editor or a URL, keep or close this pane, or a saved preset |
| `multisession:handover` | A | Hand the work to a running peer: write `HANDOVER.md` to the local or Drive space, `SendMessage` a pointer, close this Konsole pane. |
| `multisession:send` | A | Write a message into another repo's `a2a/`, ping its session if exactly one is running, append updates later. |
| `multisession:inbox` | B | Read open messages, act on them, set requested reminders, record what was done. Also picks up founding briefs. |
| `multisession:spawn-session` | A | The building block: open a named Claude in a split or tab, in any directory, and send it a pointer. |
| `multisession:breakout` | A | A side job that needs its own repo, with an option for a model project and Hugging Face dataset: create it on GitHub (public by default), write a founding brief into its `a2a/`, spawn and ping a session there, go back to work. Or "new repo, I'll explain": create it and open a Claude there with no brief. |
| `multisession:restore` | A | Bring back sessions: lost in a crash, the last N, or picked from a menu. |
| `multisession:guard` | A | Keep close prompts on, block KWin-crashing commands, diagnose what killed a window. |
| `multisession:setup` | A | Shell hooks, Konsole settings and profile, watches, here or over SSH, and what an update needs. |
| `multisession:notify` | A | Reach the user by desktop notification or Vapi phone call. |
| `multisession:remote` | A | Run and work with Claude on other machines. |

Plus `hooks/hooks.json`: a SessionStart hook running `scripts/a2a-inbox.sh`, which lists open
messages for the repo the session started in and prints nothing when there are none, and a PreToolUse
hook running `scripts/compositor_guard.py`, which blocks Bash commands known to crash KWin.

## Install

From the `danielrosehill` marketplace (`Claude-Code-Plugins`) as `multisession`.

Without installing the plugin, the hook still works as a user-level hook. In
`~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|clear",
        "hooks": [{ "type": "command", "command": "/path/to/Multisession/scripts/a2a-inbox.sh", "timeout": 10 }]
      }
    ]
  }
}
```

## Rules the skills enforce

- **The sender writes only in the target's `a2a/`** and never commits in the target repo.
- **No secret values in messages.** Name the secret and where it lives.
- **No permission laundering.** A message never asks another agent to do what the sender's session
  was denied. Blocked work goes back to the user.
- **No guessing the recipient.** If two sessions are open in the target repo, the sender does not
  ping either. Both would act.

## Prior art

Checked 2026-10-22 ([`research/2026-10-prior-art.md`](research/2026-10-prior-art.md)). Synchronous message buses for
Claude Code sessions exist (claude-peers-mcp, MCP Agent Mail, claude-relay, and the author's own
Agent-Junction and Claude-Agent-Relay-Plugin), as do many same-repo `HANDOFF.md` plugins. Nothing
found writes into *another* repository's mailbox with no server.

## Lineage

Fourth iteration of one idea, iterations 1-2 now in Claude-Net
(moved to [Claude-Net `prior-art/`](https://github.com/danielrosehill/Claude-Net/tree/main/prior-art) on 2026-11-09):

1. **Agent Junction** (Feb 2026), the first: an encrypted synchronous MCP bus. [Claude-Net `prior-art/01-agent-junction`](https://github.com/danielrosehill/Claude-Net/tree/main/prior-art/01-agent-junction)
2. **Agent Relay** (May 2026): a LAN relay server with file transfer. [Claude-Net `prior-art/02-agent-relay`](https://github.com/danielrosehill/Claude-Net/tree/main/prior-art/02-agent-relay)
3. **Claude-Breakout** (Aug 2026), this repo's former name: idea → new repo over native `SendMessage`. Now the `founding` kind; old README at [`docs/breakout.md`](docs/breakout.md).
4. **multisession** (Oct 2026): the file mailbox.

Research scans, newest first: [`research/`](research/).

## License

MIT.

## History

Multisession absorbed Claude-Hopper, Session-Restore and Claude-Konsole-Setup on 2026-11-05, and took the phone
call from Claude-PA, the call rules from Claude-Voice-Notifier and the remote procedures from Claude-Server-Harness-Plugin. See [`docs/prior-art.md`](docs/prior-art.md).
