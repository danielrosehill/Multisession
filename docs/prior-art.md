# Prior art

Scan done 2026-10-22, before turning Claude-Breakout into dead-drop. The question was whether
anything already does what dead-drop does: an agent in repo A leaves a message for the agent in
repo B, asynchronously, with no server.

## Verdict

Nothing found does exactly that. The nearest tools are either **synchronous buses** (need a server
or broker, and both sessions connected at once) or **same-repo handoff files** (one session to the
next in the same project). Listings were read; third-party code was not reviewed.

## Native: Claude Code cross-session messaging

`SendMessage` / `ListAgents`, since 2.1.224 (2026-08-07). Confirmed working 2026-10-22: `ListAgents`
in a session at `~/repos/github` listed five interactive peers in other repos. Text only, reaches
only running sessions, and `ListAgents`' `channel` parameter is "not available in this build".
dead-drop uses it as the doorbell. Notes: [`cross-session-messaging.md`](cross-session-messaging.md).

## The author's own earlier attempts

| Repo | Date | What | Relation to dead-drop |
|---|---|---|---|
| [Agent-Junction](https://github.com/danielrosehill/Agent-Junction) | 2026-02 | npm MCP server, encrypted in-memory bus, read-once messages, localhost or LAN | Synchronous "meeting place". Still the option for non-Claude CLIs. |
| [Claude-Agent-Relay-Plugin](https://github.com/danielrosehill/Claude-Agent-Relay-Plugin) | 2026-05 | FastMCP + SQLite relay, file attachments, LAN | Cross-machine, server-based. |
| [Claude-A2A-Research](https://github.com/danielrosehill/Claude-A2A-Research) | 2026-07 | Market scan of Claude↔Claude communication | Recommended claude-peers-mcp (same machine) and MCP Agent Mail (cross-machine). |
| Claude-Breakout (this repo, renamed) | 2026-08 | Idea → new repo → new agent, over `SendMessage` | Became the `founding` kind. |

## Third-party

- **Message buses (synchronous, server or broker):**
  [claude-peers-mcp](https://github.com/louislva/claude-peers-mcp),
  [MCP Agent Mail](https://github.com/Dicklesworthstone/mcp_agent_mail),
  [claude-session-bus](https://glama.ai/mcp/servers/exalsch/claude-session-bus) (an append-only
  file per project plus a prompt hook, closest in spirit but scoped to one project),
  [claude-relay](https://glama.ai/mcp/servers/@gvorwaller/claude-relay) (WebSocket, cross-machine),
  [claude-intercom](https://glama.ai/mcp/servers/AriOliv/claude-intercom).
- **Same-repo handoff files:**
  [thepushkarp/handoff](https://github.com/thepushkarp/handoff),
  [AbdurRafay2004/handoff](https://github.com/AbdurRafay2004/handoff),
  [lean-handoff](https://github.com/atashjamal5666-blip/session-handoff),
  [EhsanMo/claude-session-handoff](https://github.com/EhsanMo/claude-session-handoff),
  [Kayvan-Zahiri/claude-code-handoff](https://github.com/Kayvan-Zahiri/claude-code-handoff).
  All write a `HANDOFF.md` for the next session in the same project.
- **Anthropic Channels** connect a messaging app (Telegram, Discord) to a session, not one session
  to another.

## What dead-drop adds

Cross-repo addressing (the target repo's folder is the address), no infrastructure, a persistent
thread both sides append to, a readiness check instead of trusting an ETA, and reminders the sender
requests and the reader sets in its own harness.
