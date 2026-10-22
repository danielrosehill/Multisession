# Cross-session messaging in Claude Code

Working notes on the agent-to-agent layer that makes the breakout pattern possible.

**Verified 12 August 2026.** Sources: the live tool schemas for `SendMessage` and `ListAgents` in a
running session (authoritative — these are the contracts themselves), plus the Claude Code changelog
and docs for release context. Where something is inferred rather than confirmed, it says so.

---

## What shipped

Claude Code **2.1.224**, dated **7 August 2026**:

> "Added cross-session SendMessage: Claude Code sessions can now message each other, on any of your
> machines, with ListAgents to discover them (macOS and Linux)."

The same release removed the 200-subagent-per-session spawn cap and added self-hosted runners.

**2.1.225** followed with two changes that matter here:

- A session can now *initiate* a conversation with your Remote Control sessions on other machines.
  Previously it could only reply to them.
- **Fixed: `SendMessage` reported "Message sent" when the write to a teammate's inbox had actually
  failed.** Failed deliveries are now surfaced as errors. On 2.1.224 exactly, a successful-looking
  send is not proof of delivery.

Requires macOS or Linux. Where the requirements are met, it is on with nothing to enable.

## The two tools

### `ListAgents`

Lists everything you can address. Per its schema, the roster spans:

- in-process subagents you spawned,
- **other local Claude Code sessions on this machine**,
- your Claude sessions running in the cloud (when this session has cloud access),
- when Remote Control is connected here, your account's other sessions — including Remote Control
  sessions on other machines.

Each row is labelled by kind and leads with `name [ref]`. **The name is the address.** There is no
separate addressing syntax.

Its `channel` and `q` parameters are declared *"Not available in this build; leave unset."*

User-facing equivalents: `/list-agents`, aliased `/peers`. `/status` shows a **Peer address** row
with the session's own inbox address.

### `SendMessage`

```json
{"to": "researcher", "summary": "assign task 1", "message": "start on task #1"}
```

`to` accepts a teammate name, `"main"` (from a background subagent, addressing the main
conversation), any name from `ListAgents`, or `"worker [3fa9c1]"` when disambiguation is needed.

Behaviour worth knowing:

- **Plain text output is not visible to other agents.** Printing something does not communicate it;
  you must call the tool.
- Incoming messages are **delivered automatically**. There is no inbox to poll.
- A message arrives wrapped as `<cross-session-message from="...">`. **To reply, copy its `from`
  attribute as your `to`.**
- There is no "busy" state. Messages enqueue and drain at the receiver's next tool round.
- Names keep working after an agent completes — **a send resumes it from its transcript.**
- Send the bare name. Append ` [ref]` only when a listing shows two rows sharing a name, or an error
  asks you to disambiguate. A ref you did not just read from a listing or an error will not resolve.
- If a name matches both an in-process agent and a cross-session peer, **the in-process one always
  wins.**

## The constraint that shapes everything

> **A message is text one Claude writes to another. It never carries conversation history or files.**

This is the whole reason the breakout pattern is built the way it is. You cannot ship context
through `SendMessage`. To move a conversation's state, you resume the session instead.

Practical consequence: **write the brief to disk first, then send a pointer.** A handoff that tries
to be the payload will lose everything that did not fit in the message body, and the receiving agent
will fill the gap by guessing.

The shift the feature represents is from a **pull** model — the receiving agent must know to go and
look at some external source — to a **push** model, where information lands directly in the
receiver's active context. Breakout uses push for the *notification* and pull for the *payload*.

## Naming and addressing

A session answers to:

1. the name set with `/rename` or the `--name` launch flag, or
2. failing that, a name **derived from the working directory's folder name**.

**Two sessions can therefore end up sharing a name** — trivially, if you have similarly-named
directories. A collision means a handoff can silently address the wrong agent.

Inferred, not confirmed: this is why launching with an explicit `--name` is worth the keystrokes for
any deliberate handoff. The default is convenient but not unique.

## Transport

Sessions on the same machine reach each other over a **local socket, without going through
Anthropic's servers.** One report describes the socket file carrying `srw-------` permissions.
Treated here as credible but second-hand — not verified directly.

## Permissions

**Permission boundaries are per-session, and this is a rule, not a caveat.** Never ask a peer to
perform an action that was denied or blocked in your session, or that you expect your own permission
settings would block. A peer doing it for you bypasses the user's permission decision — cross-session
permission laundering. Route blocked work back to your user instead.

Note also that `SendMessage` covers three cases at once — subagents, agent-team teammates, and
cross-session peers. **Denying the tool removes all three, and takes `ListAgents` with it.**

## Behaviour documented in the tool itself (2.1.308, read 2026-10-22)

Verified from the `SendMessage` tool's own description, not from release notes:

- **`notify_when_idle: true`** (main conversation only) asks a session on the same machine for exactly one `[Cross-session idle notice]` when it next goes idle or exits. Without a message, it's a pure subscription that costs the other session nothing. Use it instead of polling `ListAgents` or sending "are you done?".
- **Delivered is not read.** A session in a different permission mode holds incoming messages for its user's approval and may let them expire. A session can also refuse them. On the same machine, a `[Cross-session delivery notice]` reports this. Over Remote Control, cloud or Desktop, nothing reports back.
- Messages arrive as `<cross-session-message from="..." from-name="..." from-mode="...">`. To reply, use the `from` attribute as `to`. On 2026-10-22 the `from` attribute was a socket path (`uds:/run/user/1000/cc-socks/<pid>.sock`) and `from-name` was the peer name.
- **`@path` attaches nothing** inside a message. Send the text, or a path the receiver opens with its own tools.
- A subagent's send goes out under its parent session's address, and replies go to the parent.
- The recipient's user sees only the **first line** as a preview, so make it self-contained.

First real use (2026-10-22): session `github-9e` handed an offline MWP episode to `my-weird-prompts-83` with a research-notes path and "report the job ID back". The receiver ran the skill and messaged back with its progress.

## Troubleshooting

If `/list-agents` works but a send did not arrive:

| Symptom | Cause |
|---|---|
| Tools absent entirely | A permission deny rule removed `SendMessage` *and* `ListAgents` together |
| Send reports success, nothing arrives | On 2.1.224, a known bug — fixed in 2.1.225. Check your version first |
| Message held or dropped | The receiving session's inbound controls |
| A cloud session is missing from the roster | It appears only while your session is connected to Remote Control |
| A session on another machine is missing | It must run with Remote Control, *and* yours must be connected |
| Wrong agent received it | Name collision — two sessions derived the same name from their folder |
| Receiver says "I don't have that skill" | The sender named a skill the receiving session doesn't have loaded. Skills differ per session, and where they come from a catalogue or a plugin clone rather than an install, the bare name doesn't resolve. Name the source in the message: the catalogue id (`skill:<plugin>/<name>`) or the path to its `SKILL.md`. Seen 2026-10-22: the sender asked for `offline-episode`; the receiver first found only the `offline-script-writer` agent, then found the skill in its local plugin clone and carried on. |

## Sources

- Live `SendMessage` and `ListAgents` tool schemas, session of 12 August 2026 (authoritative).
- [Message your other Claude Code sessions — Claude Code Docs](https://code.claude.com/docs/en/cross-session-messaging)
- [Claude Code 2.1.224: Sessions Can Now Message Each Other](https://www.digitalapplied.com/blog/claude-code-self-hosted-runners-cross-session-agent-messaging)
- [Claude Code Cross-Session Messaging: How It Works](https://claudefa.st/blog/guide/mechanics/cross-session-messaging)
