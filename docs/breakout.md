# The breakout pattern

> Moved here from the repo README on 2026-10-22, when Claude-Breakout became Claude-Dead-Drop.
> Breakout is now one use of the dead-drop mailbox: the founding brief is a `kind: founding`
> message in the new repo's `a2a/`, and the receiving procedure (formerly `breakout-adopt`) is part
> of `dead-drop:inbox`. The reasoning below is unchanged.

See [`verification.md`](verification.md) for what is confirmed versus inferred.

---

You are twenty minutes into a piece of work. An idea arrives that is good, and is *not this* — not a
bug in what you are building, not a second feature for the same repo, but a different project that
happened to occur to you while your hands were somewhere else.

Two things go wrong by default, and they are both quiet.

**The agent takes the bait.** You describe the idea, Claude finds it interesting, and the session
turns toward it. The thing you were actually doing is now half-done and the context that made it
tractable is gone.

**Or the idea gets absorbed.** Claude keeps working, and files the new idea into the repo it is
already standing in — a `docs/ideas.md`, a stray directory, a TODO. It is now in the wrong project
forever. Nobody will look for it there, because it isn't about that.

The second failure is the expensive one and it is the one nobody notices. An idea filed in the wrong
repo has not been captured; it has been buried at a findable-looking address.

**Breakout** is the procedure for that moment: the idea gets its own repository, its own agent, and
its own track — and the session you were already in goes back to what it was doing, uninterrupted.

## The pattern in one line

> Recognise that the idea does not belong to this repo → write a seed brief → create the repo →
> hand it to a second agent → return to the work in flight. The two tracks never converge.

## The decision rule

Everything turns on one question, and it is not "is this related?" — relatedness is a trap, because
almost everything is related to almost everything.

> **Does the deliverable of this idea belong in this repository's tree?**

If yes, it is a task in this repo. Use [interrupt](#the-family) to file it without derailing.

If no, it is a breakout. It does not matter how conceptually adjacent it is. A CLI that consumes
this repo's output is still a different repo. A doc about the process this repo automates is still a
different repo.

The rule exists to serve a prior commitment: **one idea, one repository.** Repos are free. A repo
that turns out to be a dead end costs nothing and is trivially archived. An idea wedged into a repo
that was not built to hold it contaminates both — the host repo grows a second purpose, and the
guest never gets a README that describes it honestly.

## The family

Three patterns, often confused, that split three different things. This is the distinction worth
internalising:

| | Splits | Tracks afterwards | Tool |
|---|---|---|---|
| **interrupt** | work *within* a repo | converge — one sprint, one repo | [interrupt-claude](#interrupt-claude) |
| **hopper** | time *within* a track | sequential — same work, new session | [Claude-Hopper](https://github.com/danielrosehill/Claude-Hopper) |
| **breakout** | *tracks* | diverge — permanently, by design | this repo |

- **interrupt** answers *"I noticed a second thing that's broken."* Same repo, same sprint. It is
  filed as a task and routed linear or parallel-subagent. It comes back.
- **hopper** answers *"this session is exhausted, carry the context forward."* A handover document
  moves one track's state across a session boundary. Same work, later.
- **breakout** answers *"this isn't part of this project at all."* New repo, new agent, no
  reconvergence. The original session's only remaining involvement is the handoff message.

The seam with `interrupt` is clean and deliberate: interrupt's taxonomy classifies some
interruptions `out-of-scope` — "file it, explicitly not this sprint." **Breakout is what happens to
an `out-of-scope` item that deserves its own repository.** It picks up exactly where interrupt puts
things down.

## Why this is only now possible

Breakout needs an agent-to-agent layer, and until recently there wasn't one.

Claude Code **2.1.224** (7 August 2026) added cross-session `SendMessage` with `ListAgents` to
discover targets — sessions on any of your machines can now message each other, on macOS and Linux.
Same-machine sessions talk over a local socket without going through Anthropic's servers.

This changes the shape of the handoff from **pull** to **push**. The prior art (Hopper's
`sideclaude`, `spawn-planning-repo`) spawns a session and seeds a file: the new agent has to be told
where to look, and the originating agent cannot follow up. With `SendMessage`, agent one addresses
agent two by name and keeps a channel open.

**The single most load-bearing constraint** — and the one that determines the whole procedure:

> A message is text. It never carries conversation history or files.

So the message cannot be the handoff. The brief must be on disk, in the new repo, **before** you
send anything. The message is a pointer, not the payload. Every other design choice below follows
from that one fact.

Full verified notes on the primitive, including the failure modes:
[`docs/cross-session-messaging.md`](cross-session-messaging.md).

## The procedure

### 1. Recognise, and do not stall

Apply the decision rule. Do not open a discussion about it — recognition should cost the main thread
one line, because the whole point is that the work in flight survives.

### 2. Write the seed brief before anything else

The brief is the deliverable of a breakout. Everything else is plumbing.

It must be readable cold by an agent with **no memory of the conversation that produced it** — that
agent was not there, cannot ask you a follow-up question cheaply, and will confidently invent
anything you left implicit. The brief carries: what the idea is, why it is not part of the origin
repo, the first concrete piece of work, and what "done" looks like for a first pass.

A cheap subagent should write it, so the main thread does not spend its context on drafting.

### 3. Create the repo, in the right place

New repo, seeded with the brief. File it in the narrowest topic group that fits — a breakout that
lands in a junk-drawer directory has reproduced the burial problem it exists to prevent.

Directory name matters more than it looks: **a session's default peer name is its working
directory's folder name.** Creating the directory effectively assigns the address you will message.

### 4. Hand off

Spawn a session in the new repo — Hopper's `new-claude-at` already does this well — then
`ListAgents` to confirm it is reachable, and `SendMessage` it a pointer to the brief.

Prefer launching with an explicit `--name`. Two sessions derived from similar folder names collide,
and a collision means your handoff silently addresses the wrong agent.

### 5. Return

Say one line to the user and go back to the task in flight. The successful outcome of a breakout is
that the original work was never interrupted.

## What breakout must never be used for

Permission boundaries are **per-session**. If an action was denied in your session, routing it to a
peer so the peer performs it bypasses the user's decision — cross-session permission laundering.
Breakout creates a second agent with its own permission context, which makes this a live risk rather
than a theoretical one. Blocked work goes back to the user, never sideways to a peer.

## Skills

| Skill | Side | What it does |
|---|---|---|
| `dead-drop:breakout` | emit | Recognise, brief, create the repo, hand off, return to work |
| `dead-drop:inbox` (founding briefs) | receive | A fresh session in a new repo picks up its founding brief and starts |

The receiving end needs a procedure too. An agent that starts in an empty repo containing one
document, with no idea it was spawned deliberately, will typically ask "what would you like to work
on?" — wasting the entire handoff.

## Relationship to the prior art

This repo does **not** reimplement session spawning. [Claude-Hopper](https://github.com/danielrosehill/Claude-Hopper)
already has `new-claude-at`, `sideclaude` and `spawn-planning-repo`, and they work. Breakout
contributes the decision rule, the brief format, and the push-model handoff that the 2.1.224
primitives made possible.

There is real overlap with `sideclaude` in particular, and a reasonable person could argue these
skills belong inside Hopper rather than in their own plugin. See
[`docs/relationship-to-hopper.md`](relationship-to-hopper.md) for the argument both ways; that
question is open.

- **interrupt-claude** — companion plugin, same-repo interruption routing. Currently unpublished
  (local only), so there is no link to give yet.
- **[Claude-Hopper](https://github.com/danielrosehill/Claude-Hopper)** — session spawning and handover.
- **[Claude-Code-Plugins](https://github.com/danielrosehill/Claude-Code-Plugins)** — the marketplace,
  where this plugin is listed as `dead-drop` (formerly `idea-breakout`).

## Install

Not yet published to the marketplace. Clone and install locally.

## License

MIT.
