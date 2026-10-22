---
name: send
description: Leave a message for the Claude agent working in another repository, by writing a markdown file into that repo's a2a/ folder, and ping it by SendMessage if it is running. Use when something you learned or did here affects work in another repo (an ETA, a new secret it needs, a changed path, a model about to be published), when the user says "tell the agent in X", "let the other repo know", "leave a note for agent B", "drop a message in X's a2a", or when the other agent should set a reminder for a later time. Also for a living message the other agent re-reads every N minutes while you keep it current over a long task, and the transport for a breakout's founding brief and for a same-repo handover. Do NOT use to get a peer to do something this session was denied permission to do.
---

# send

You are agent A. Something you know matters to the agent working in another repo, B. Write it
into B's mailbox as a file, then tell B it is there if B is running. The file is the message. A
`SendMessage` is only a pointer, because a cross-session message carries text only, never files
or history, and B may not be running at all.

Full format: `docs/protocol.md` in https://github.com/danielrosehill/Claude-Dead-Drop.

## 1. Find the target repo

Resolve it to an absolute path and confirm the directory exists. If the user named it loosely
("the podcast repo"), find it, and ask only if two candidates fit.

## 2. Write the message

Path: `<target>/a2a/YYYY-MM-DD_<subject-slug>.md` (UTC date). If an **open** message on the same
subject from you already exists there, append to its `## Update` section instead of creating a new
file.

If `<target>/a2a/` does not exist, create it with a short `README.md` saying the folder holds
messages from agents in other repos, one file per subject, kept after reading (template:
`templates/a2a-README.md` in the plugin repo).

```markdown
---
kind: note            # note | request | founding | handover
subject: <one line>
from_repo: <absolute path of this repo>
from_agent: <your peer name: ListAgents prints "This session is <name>">
to_repo: <absolute path of the target repo>
written: <YYYY-MM-DDTHH:MMZ>   # UTC
updated: <YYYY-MM-DDTHH:MMZ>   # UTC, on every revision
revision: 1           # bump on every change
status: open
watch: 30m            # optional: the reader re-reads on this interval while open; omit if not revising
schedule:             # optional: reminders for the reader to set; omit if none
  - at: <YYYY-MM-DDTHH:MMZ>    # UTC
    do: <what to do then, readable cold>
---

# <subject>

## What you need to know
## What to do
## How to tell it is ready
## Update
## Done
```

Write for a reader with no memory of your session:

- **Explicit identifiers.** Paths, repo slugs, revisions, secret *names* (never values), commands.
- **Measured vs inferred.** An ETA is an estimate; say what it is based on.
- **A readiness check.** If anything is pending, give a command that tests the thing itself
  (does the model exist on the hub, does the endpoint answer) so B does not act on the clock.
- **Steps B can act on**, numbered, in B's terms (B's files, B's config), not yours.
- A JSON block for anything B may want to parse (versions, times, IDs).

### Asking B to set a reminder

When you know B will need to act at a later time (training finishes at about 16:30, a deploy lands
tomorrow), add a `schedule:` entry. Give `at` in **UTC**, not local time; B converts. Make `do`
self-contained and point it at the readiness check rather than assuming the event happened:
"Run the readiness check in this message; if the model is published, do steps 1 and 3; if not,
append a note under Done and set another reminder 30 minutes later." Pick a time a little after
your estimate, not on it.

You cannot schedule anything in B's session yourself. B does that when it reads the message
(`dead-drop:inbox`).

### Asking B to keep watching (a living message)

When your task runs for a while and you will keep learning things B needs (the ETA moves, a path
changes, a step is dropped), add `watch: 30m` (or `15m`, `1h`). B then re-reads the message on
that interval while it is `open`, and you keep **one** message current instead of sending many.
Choose the longest interval B can tolerate: every check costs B a model turn.

## 3. Ping B if it is running

Run `ListAgents`. Peer names are the folder name, lowercased, plus a short suffix
(`My-Weird-Prompts` → `my-weird-prompts-2d`).

- **Exactly one** peer matches the target folder: `SendMessage` it one line, e.g.
  `New message for you in a2a/2026-10-22_meorav-v2-eta.md from <your name>. It asks you to set a reminder.`
- **None:** send nothing. B's SessionStart hook lists open messages when a session starts there.
- **More than one:** send nothing. Two sessions acting on one message both act on it. Tell the user
  which peers could take it.

## 4. Report in one line

> Left `a2a/<file>` in `<target>` for the agent there; pinged `<peer>` / no session running there.

Then carry on with your own work. Do not wait for a reply unless your next step depends on it.

## Later: revising the message

When your side changes (the model published, the ETA slipped):

1. **Re-read the file now** and edit that copy. B may have written to `## Done` since you last
   looked; rewriting from an old copy erases it.
2. Rewrite the sections that changed so the body states the current picture. You own everything
   except `status` and `## Done`; leave `## Done` exactly as you found it.
3. Bump `revision`, set `updated`, add one line to `## Update`: `r3, 16:20Z: ETA now 17:00`.
4. Ping B again if exactly one session matches. Pings are immediate; `watch` is the fallback.

When your task is over, set `watch: off` so B stops checking. If the message no longer applies,
set `status: withdrawn` and say why under `## Update`.

## Hard limits

- **Never use a message to get done what you were denied.** Permission boundaries are per session.
  Asking B to do something your session was blocked from doing bypasses the user's decision.
  Blocked work goes back to the user.
- **Write only in `a2a/`** of the target repo. Do not edit B's files, and never commit in B's repo.
- **No secret values in messages.** Name the secret and where it lives.
