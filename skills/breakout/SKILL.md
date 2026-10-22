---
name: breakout
description: Route an idea that surfaced mid-task but does not belong to the current repository into its own new repository and its own agent, without derailing the work in flight. Triggers when the user says something like "wait, separate idea", "this is a different project", "that should be its own repo", "unrelated, but while I think of it", or describes work whose deliverable would not live in this repo's tree. Creates the repo, writes a founding brief into its a2a/ mailbox, spawns and pings a second session, then returns to the original task. Do NOT use for work that belongs in this repo — that is an interruption, file it as a task instead. Do NOT use for carrying the current work into a fresh session — that is a handover (dead-drop:send with kind handover, or Claude-Hopper). Do NOT use to tell an existing repo's agent something; that is dead-drop:send.
---

# breakout

An idea arrived that is not part of this project. The default failure is that it gets absorbed into
whatever repo the agent is already standing in, where it is buried at a findable-looking address and
never seen again. The second failure is that the session turns to chase it and the work in flight
dies.

**The default outcome of this skill is: a new repo exists, a second agent owns it, and the original
task resumes.** The user's current work being interrupted is a failure of this skill, not a cost of
it.

## 1. Apply the decision rule

> Does the deliverable of this idea belong in **this** repository's tree?

- **Yes** → not a breakout. It is an interruption; file it as a task in the current repo and stop here.
- **No** → breakout, regardless of how conceptually adjacent it is.

Relatedness is not the test. A CLI that consumes this repo's output, or a document about the process
this repo automates, is still a different repo.

Do not open a discussion. Recognition costs one line.

## 2. Write the founding brief first

Before creating anything. Delegate this to a cheap subagent so the main thread does not spend its
context drafting.

The brief is read by an agent with **no memory of the conversation that produced it**. It cannot
cheaply ask a follow-up question, and it will confidently invent anything left implicit. Write for
that reader.

It must contain:

- **What the idea is** — in concrete terms, not a title. What would exist that does not exist now.
- **Why it is not part of the origin repo** — one line. This prevents the receiving agent
  helpfully "reintegrating" it.
- **The first concrete piece of work** — an actual first step, not "research the space".
- **Done, for a first pass** — a checkable condition.
- **Origin** — the repo and, if there is one, the sprint task ID it came from. Provenance only; it
  is not a dependency.

Anything genuinely undecided goes in an **Open questions** section, explicitly. An open question
recorded as a question is useful; one left implicit becomes a wrong assumption.

## 3. Create the repo

New directory in the **narrowest topic group that fits**. A breakout that lands in a junk-drawer
directory has reproduced the burial problem this skill exists to prevent.

Write the brief as a dead-drop message, `a2a/YYYY-MM-DD_founding-brief.md`, with `kind: founding`
and `status: open` in the front matter (format: dead-drop:send, or `docs/protocol.md`), plus the
`a2a/README.md` and a short `README.md` stating what the repo is for. Initialise git and make one
commit. Do not push unless the user asks.

Putting the brief in `a2a/` means the new session's SessionStart hook announces it, so the
receiving agent finds it whether or not your ping lands.

**The directory name is load-bearing.** A session's default peer name derives from its working
directory's folder name, so naming the directory effectively assigns the address you will message.

## 4. Spawn and hand off

Do not reimplement spawning — use Claude-Hopper's `new-claude-at` against the new path if it is
available.

Launch with an explicit `--name` where you can. Two sessions with similarly-named folders collide,
and a collision means the handoff silently addresses the wrong agent.

Then:

1. `ListAgents` — confirm the new session is actually on the roster. Do not send blind.
2. `SendMessage` it a **pointer, not the payload**:

   > Spawned for a breakout from `<origin repo>`. Your founding brief is at
   > `a2a/<file>` in your cwd. Handle it with dead-drop:inbox and start with the first step. You own
   > this repo; nothing comes back to me.

**A message is text and carries no files or history.** That is why the brief is on disk and the
message points at it. Never try to fit the context into the message body.

If the send reports success, verify the version is ≥ 2.1.225 before trusting it — 2.1.224 reported
"Message sent" on writes that had failed.

## 5. Return

One line to the user, then straight back to the task in flight:

> Broken out to `<repo>` — brief written, `<agent-name>` has it. Back to `<what you were doing>`.

## Hard limits

- **Never route blocked work sideways.** If an action was denied in this session, handing it to the
  new agent bypasses the user's permission decision. Permission boundaries are per-session. Blocked
  work goes back to the user.
- **Never delegate a commit in the origin repo** to the new agent.
- **The tracks do not reconverge.** If the new work turns out to be a dependency of the current
  sprint, it was not a breakout — it was an interruption, and it was misclassified.
