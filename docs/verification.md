# What is verified here, and what is not

Written 12 August 2026 for Claude-Breakout; extended 22 October 2026 for dead-drop. Kept honest so
a later reader knows which claims to lean on.

## dead-drop (2026-10-22)

### Confirmed

- **The pattern works by hand.** 2026-10-22: the agent in `ASR-Training` wrote
  `My-Weird-Prompts/a2a/2026-10-22_meorav-v2-eta.md` (ETA, gated-repo secret, readiness check) at
  the user's request. The agent in `My-Weird-Prompts` read it when told to, made the Modal image
  build use a secret that can read the gated repo, and recorded a partial `## Done` within about
  ten minutes. No front matter yet; the format in `protocol.md` was derived from that file.
- **`scripts/a2a-inbox.sh`** run against that folder and against a fixture: lists `open` messages,
  flags `schedule:`, lists the hand-written file as `status unknown`, skips `done` files, and prints
  nothing (exit 0) when there is no `a2a/`.
- **Peer names** in `ListAgents` are folder name, lowercased, plus a hex suffix
  (`my-weird-prompts-2d`, `asr-training-c0`), and two sessions in one repo get two names. Observed
  2026-10-22.
- **`CronCreate`** schema, read 2026-10-22: 5-field cron in **local** time, `recurring: false` for
  one-shots, session-only, fires only while the session is idle. `date -d '<UTC>Z' '+%M %H %d %m'`
  gives the local fields (16:45Z → 19:45 IDT).
- **The hook as a user-level SessionStart hook** in `~/.claude/settings.json` (how the author runs
  it, since plugins there come from a catalogue rather than being installed).

### Not verified

- **The skills have not dispatched** from their descriptions in a real session.
- **`hooks/hooks.json` inside an installed plugin** has not run. The user-level hook uses the same
  script.
- **A `schedule:` reminder has not fired end to end** (reader sets it, session idles, prompt runs).
- **The peer-name prefix match** breaks for folders whose names normalise to the same prefix as
  another (e.g. `Foo` and `Foo-Bar`). The skill only sends on a single unambiguous match.

## Breakout (2026-08-12)

### Confirmed

**The agent-to-agent primitives exist and behave as documented.** Read directly from the live
`SendMessage` and `ListAgents` tool schemas in a running session, not from release notes. The
contracts in [`cross-session-messaging.md`](cross-session-messaging.md) — addressing by name,
automatic delivery, `<cross-session-message from="...">` wrapping, the enqueue-and-drain model, the
`[ref]` disambiguation rule, the per-session permission boundary — come from those schemas.

**The release facts.** 2.1.224 on 7 August 2026, macOS and Linux, local socket for same-machine
peers, text-only messages, `--name` / `/rename` with folder-name fallback, the 2.1.225 fix to false
"Message sent" reporting. Corroborated across the Claude Code docs and several independent write-ups.

**The prior art.** `sideclaude`, `spawn-planning-repo` and `new-claude-at` were read from
Claude-Hopper's published README on 12 August 2026.

**interrupt-claude is unpublished.** `gh repo view danielrosehill/interrupt-claude-plugin` returns
"Could not resolve to a Repository" — it exists locally with a single scaffold commit and no remote.
Its own `plugin.json` already carries a `repository` URL for that address, which will resolve only
once it is pushed.

### Not verified

**No breakout has been run end to end.** The procedure is a design. The specific failure modes it
claims to prevent are reasoned from the primitives' constraints, not observed.

**The skills have never dispatched.** Their trigger descriptions are untested against a real
session, and they overlap with Hopper's `sideclaude` — which is exactly the condition under which
model dispatch gets unpredictable.

**The socket permissions claim** (`srw-------`) is second-hand from a single report and was not
checked directly.

**Whether the pattern survives contact with more than two concurrent tracks.** interrupt's routing
notes already observe that beyond about two parallel delegates the bottleneck stops being the
machine and becomes the user's attention. Breakout spawns *full sessions*, which are heavier than
subagents, so that ceiling is probably lower here. Untested.

### First things to check when it is used for real

1. Does the spawned session actually appear in `ListAgents` promptly, or is there a registration lag
   that makes the handoff race the spawn?
2. Does the folder-name default produce collisions in practice across sibling repos in the same
   topic group?
3. Does the receiving agent, following `dead-drop:inbox` (formerly `breakout-adopt`), start work without asking an opening
   question?
