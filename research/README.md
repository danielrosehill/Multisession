# Research

What exists for letting Claude Code agents communicate, newest first. Each scan is a snapshot as
of its date. Add a new dated file for a new scan; do not rewrite an old one.

| Date | File | Question | Headline |
|---|---|---|---|
| 2026-10-22 | [`2026-10-prior-art.md`](2026-10-prior-art.md) | Does anything already do cross-repo, asynchronous, serverless agent messages? | No. Synchronous buses and same-repo `HANDOFF.md` plugins exist; nothing writes into another repo's mailbox. Native `SendMessage` (2.1.224) is the doorbell. |
| 2026-07-15 | [`2026-07-a2a-market-scan/`](2026-07-a2a-market-scan/) | How can two Claude Code instances in two terminals talk, on one machine and across machines? | claude-peers-mcp for one machine, MCP Agent Mail over Tailscale across machines. Predates native `SendMessage`. Formerly the repo `danielrosehill/Claude-A2A-Research`. |
