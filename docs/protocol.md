# The dead-drop protocol

The message format and lifecycle that every skill in this plugin reads and writes. Version 1,
written 2026-10-22.

## Where messages live

Each repository has one mailbox: an `a2a/` folder at its root. A message for the agent working
in repo B goes in **B's** `a2a/`, written by the agent in repo A. One file per subject:

```
<target-repo>/a2a/
├── README.md                          # what the folder is (templates/a2a-README.md)
└── YYYY-MM-DD_<subject-slug>.md       # one message thread
```

The sender creates `a2a/` and its README if they do not exist. It writes nothing else in the
target repo and never commits there; the target repo's agent decides what gets committed.

## The message file

YAML front matter, then a markdown body. The front matter is the part tools read (the
SessionStart hook greps `status:`), so keep it flat and exact.

```markdown
---
kind: note
subject: Meorav v2 ETA and the gated-repo secret
from_repo: /home/user/repos/ASR-Training
from_agent: asr-training-c0
to_repo: /home/user/repos/My-Weird-Prompts
written: 2026-10-22T15:10Z
updated: 2026-10-22T15:40Z
revision: 2
status: open
watch: 30m
schedule:
  - at: 2026-10-22T16:45Z
    do: Check whether the model is published (see "How to tell it is ready"). If it is, do steps 1 and 3.
---

# <subject>

## What you need to know
## What to do
## How to tell it is ready
## Update
## Done
```

| Field | Required | Values / meaning |
|---|---|---|
| `kind` | yes | `note` (information), `request` (the reader should do something), `founding` (the first brief of a new repo; see the `breakout` skill), `handover` (to the next session in the *same* repo) |
| `subject` | yes | One line. Also the file's slug. |
| `from_repo` | yes | Absolute path of the sender's repo. |
| `from_agent` | no | The sender's peer name, as `ListAgents` prints it ("This session is …"). Lets the reader reply by `SendMessage` while the sender is still running. |
| `to_repo` | yes | Absolute path of the target repo. Lets a misplaced file be noticed. |
| `written` | yes | UTC, `YYYY-MM-DDTHH:MMZ`. |
| `updated` | no | UTC time of the latest revision. Absent means never revised. |
| `revision` | no | Integer, starts at 1. The sender bumps it on **every** change to the file. The reader compares it to the last revision it acted on. Absent means 1. |
| `status` | yes | `open` → `done`, or `withdrawn` by the sender. |
| `watch` | no | `15m`, `30m`, `1h`, … The sender asks the reader to re-read this message on that interval while it is `open`, because the sender will keep revising it. `off` (or absent) means no polling. See "Living messages" below. |
| `schedule` | no | Reminders the **reader** sets in its own harness. Each has `at` (UTC) and `do` (the prompt the reader should run then). See below. |
| `reply_to` | no | Filename of the message this answers, when replying in the other repo's `a2a/`. |

### Body sections

- **What you need to know**: facts, with how each was established (measured or inferred).
- **What to do**: numbered steps the reader can act on cold.
- **How to tell it is ready**: a check of the thing itself, for anything time-dependent. An ETA
  is an estimate; the reader runs the check and does not go by the clock alone.
- **Update**: only the sender writes here: one line per revision, newest first, saying what
  changed (`r3, 16:20Z: ETA moved to 17:00; secret renamed`). The reader uses it to see what is new
  without diffing. The thread stays in one file; the sender does not start a new file on the same
  subject.
- **Done**: only the reader writes here: the date, what it did, and any reminder it set.

## Lifecycle

1. The sender writes the file with `status: open`.
2. Optional push: if exactly one live peer's name matches the target repo's folder, the sender
   `SendMessage`s it a one-line pointer to the file. Otherwise the file waits.
3. The reader picks the message up: the SessionStart hook lists open messages when a session
   starts, a `SendMessage` pointer arrives mid-session, or the user says "check your a2a".
4. The reader acts on it, sets any `schedule` reminders, appends to `## Done`, and sets
   `status: done` once nothing is left to do. A partly done message stays `open`, with the partial
   `## Done` entry saying what is still waiting.
5. Files are **kept, not deleted**. The sender appends updates to the same file after the reader
   has seen it, and both agents use the file as the record of what was agreed. Old `done` files
   may be moved to `a2a/archive/` during a tidy.

### Why not delete after reading

Deleting messages after they are read keeps the inbox empty, but in practice (the first real use,
2026-10-22) the sender came back to append the published revision to a message the reader had
already acted on. A deleted file leaves nowhere for that update to go, and no record of what the
reader agreed to.

## Scheduled reminders

A sender often knows *when* the reader will need to act: when training finishes, when a deploy
lands. The sender cannot schedule anything in another session's harness, so it puts the request in
`schedule:` and the reader schedules it.

On the reader's side (Claude Code, verified 2026-10-22 from the `CronCreate` tool schema):

- Use `CronCreate` with `recurring: false`, with minute, hour, day-of-month and month pinned.
- **Cron runs in the machine's local timezone**, but `at` is UTC. Convert before building the
  expression. Getting this wrong fires the reminder hours off.
- The prompt is the `do` text **plus a pointer back to the message file**, so the fired prompt is
  readable cold: `"[dead-drop] a2a/2026-10-22_meorav-v2-eta.md: <do>"`.
- **Jobs are session-only and fire only while the session is idle.** They disappear when the
  session exits. The reader records the reminder in `## Done` with its job ID and says in one line
  to the user that it lasts only while this session stays open. If the session will not stay open,
  it says so instead of pretending the reminder is durable.
- After scheduling, read back the actual next fire time from the tool result or `CronList`; the
  scheduler can shift a job by up to about 90 s.

## Living messages (`watch`)

Some tasks run for hours and the sender learns more as they go: the ETA moves, a path changes, a
step is no longer needed. Rather than stack updates, the sender keeps **one message current** and
rewrites it, and the reader re-reads it on an interval.

**Ownership.** The sender owns the front matter except `status`, and every section except
`## Done`. It may rewrite those freely, so the body always states the current picture rather than
a history. The reader owns `status` and `## Done`.

**Sender, on each revision:**

1. Re-read the file **immediately before writing**, and write from that copy, never from one held
   since earlier. The reader may have appended to `## Done` in between, and a stale rewrite would
   erase it.
2. Rewrite what changed. Keep `## Done` exactly as found.
3. Bump `revision`, set `updated`, add one line to `## Update` naming what changed.
4. Ping the reader if exactly one session matches (see below). The ping is immediate; `watch` is
   the fallback for when no ping is possible or it is missed.
5. When the task is over, set `watch: off`, or `status: withdrawn` if the message no longer applies.

**Reader, when it first handles a message with `watch`:**

1. Set a **recurring** `CronCreate` job on that interval, on off-minutes (`30m` →
   `"7,37 * * * *"`, `1h` → `"23 * * * *"`).
2. The prompt does the cheap check first and stops there if nothing changed:
   `[dead-drop watch] a2a/<file>: run grep -E '^(revision|status|watch):' on it. If revision is
   higher than the last one recorded under ## Done, read the ## Update lines and the changed
   sections, act, and record "seen r<N>". If status is not open or watch is off, CronDelete this job
   and say so. Otherwise do nothing and say nothing.`
3. Record in `## Done`: the job ID, the interval, and `seen r<N>` for the revision acted on. That
   line is how the next check knows what is new.

Every check is a full model turn, so the do-nothing path must be one `grep` and no output. That is
also why the reader, not the sender, chooses minute offsets: sessions polling on `:00` and `:30`
all land at once.

**Limits (verified from the `CronCreate` schema, 2026-10-22):** jobs live only in the reader's
session, fire only while it is idle, and a recurring job can run up to half its interval late.
**Recurring jobs expire after 7 days.** A watch on a task longer than that has to be re-armed, and
the reader says so when it sets one. `Monitor` is not a substitute: monitors expire after at most
30 minutes and need re-arming.

## Push notification by peer name

A session's default peer name is its working directory's folder name, lowercased, plus a short
hex suffix (observed 2026-10-22: `My-Weird-Prompts` → `my-weird-prompts-2d`, `ASR-Training` →
`asr-training-c0`). `ListAgents` shows names and status, not working directories, so matching is
by folder-name prefix.

- **One match:** send the pointer.
- **No match:** do not send. The hook delivers it when a session starts there.
- **Several matches** (two sessions open in the same repo, as with `my-weird-prompts-2d` and
  `my-weird-prompts-5c` on 2026-10-22): do not guess. If both receive it, both act on it. Leave the
  file and tell the user which peers could take it.

A message body is text only and never carries files or history, which is why the file is the
payload and the `SendMessage` is only a pointer. See [`cross-session-messaging.md`](cross-session-messaging.md).

## Legacy messages

Files without front matter (written by hand before this protocol existed) cannot be read for
status. The hook lists them as `status unknown`. A reader that acts on one adds front matter.
