# Sessions on another machine

## Start one

`claude --bg` starts a background session. `claude agents` manages them, on H (2.1.318, 2026-11-05):

```bash
cd <dir> && claude --bg --name <name> "<task>"
claude agents --json          # what is running
```

## Message one

Cross-machine `SendMessage` goes through Anthropic's servers as text only, and needs **all** of:

- Claude Code 2.1.225 or later at both ends.
- Remote Control on at both ends: `claude remote-control` is a server mode, with `--spawn` and `--capacity`.
- A full claude.ai login at both ends. API keys, `setup-token` and `CLAUDE_CODE_OAUTH_TOKEN` cannot start it.

Then H's session shows in `ListAgents`. Starting Remote Control exposes that machine's sessions to the account, so
it needs the user's yes. A cloud session receives messages but can't reply. Silence from a Remote Control session
is not a receipt: nothing reports back if it was held. Files don't travel: use the `drive` space in `handover`.

Unconfirmed as of 2026-11-05: whether a session on another account can be reached.

## Move a session across

**Template.** Written from one setup where both machines use the same home path.

A session is a transcript at `~/.claude/projects/<slug>/<id>.jsonl`, with an optional `<id>/` sidecar folder. The slug
is the working directory with every non-alphanumeric character turned into `-`. The files come from git, not
from this disk.

1. **List:** which sessions, and whether each repo has uncommitted or unpushed work. Leave this session out unless named.
2. **Settle local changes.** Commit and push, or have the user say they don't matter. A session mid-turn: wait for it
   to go idle, or the transcript loses the end of the turn.
3. **Repo on H:** clone it, or fast-forward to this machine's branch (`clone-repos.md`).
4. **Copy:** `scp` the `.jsonl` and the sidecar into the same slug on H. If the home path differs, recompute the slug.
5. **Resume:** `cd <dir> && claude --bg --resume <id>` on H.
6. **Verify:** `claude agents --json` shows it, with the old conversation.
7. **Close the copy here.** Tell the user which sessions to exit. If both run, they diverge, and resuming either forks.

The transcript is copied, not moved. A non-git working directory arrives empty.
