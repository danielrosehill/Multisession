# Claude-Dead-Drop

Asynchronous messages between Claude Code agents working in different repositories. Agent A writes
a markdown file into repo B's `a2a/` folder. Agent B finds it when its session starts, or straight
away if A pings it. B acts on it, sets any reminders it asks for, and writes what it did back into
the same file.

No server, no broker, no shared meeting place. The target repo's folder is the mailbox.

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
dead-drop:send
  write B/a2a/2026-10-22_<subject>.md  ───────▶ a2a/2026-10-22_<subject>.md   status: open
  ListAgents → one peer named b-*?
     yes → SendMessage "new message in a2a/…" ─▶ arrives mid-session
     no  → nothing; the file waits             SessionStart hook: "dead-drop: 1 open message"
                                                dead-drop:inbox
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
| `founding` | The first brief of a brand-new repo, written by `dead-drop:breakout` when an idea does not belong in the current repo. See [`docs/breakout.md`](docs/breakout.md). |
| `handover` | To the next session in the *same* repo. For the full session-to-session handover workflow, Claude-Hopper does more. |

## Skills

| Skill | Side | What it does |
|---|---|---|
| `dead-drop:send` | A | Write a message into another repo's `a2a/`, ping its session if exactly one is running, append updates later. |
| `dead-drop:inbox` | B | Read open messages, act on them, set requested reminders, record what was done. Also picks up founding briefs. |
| `dead-drop:breakout` | A | An idea that needs its own repo: create the repo, write a founding brief into its `a2a/`, spawn and ping a session there, go back to work. |

Plus `hooks/hooks.json`: a SessionStart hook running `scripts/a2a-inbox.sh`, which lists open
messages for the repo the session started in and prints nothing when there are none.

## Install

From the `danielrosehill` marketplace (`Claude-Code-Plugins`) as `dead-drop`.

Without installing the plugin, the hook still works as a user-level hook. In
`~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|clear",
        "hooks": [{ "type": "command", "command": "/path/to/Claude-Dead-Drop/scripts/a2a-inbox.sh", "timeout": 10 }]
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

Checked 2026-10-22 ([`docs/prior-art.md`](docs/prior-art.md)). Synchronous message buses for
Claude Code sessions exist (claude-peers-mcp, MCP Agent Mail, claude-relay, and the author's own
Agent-Junction and Claude-Agent-Relay-Plugin), as do many same-repo `HANDOFF.md` plugins. Nothing
found writes into *another* repository's mailbox with no server.

This repo was **Claude-Breakout** (plugin `idea-breakout`) until 2026-10-22. Breakout is now one
message kind; the old README is [`docs/breakout.md`](docs/breakout.md).

## License

MIT.
