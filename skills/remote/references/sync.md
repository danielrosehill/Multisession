# Sync settings and connect the skills library

**Template.** Written from one laptop-to-server setup. Check every path against the machines in front of you.

## What to sync

| Item | Do | Why |
| --- | --- | --- |
| User `CLAUDE.md`, context files | Copy, leaving out what is machine-specific | Same instructions on both |
| `~/.claude/settings.json` | Merge, as below | Holds machine-specific values |
| `~/.claude/hooks/` | Copy, not `.bak*` files | Every hook path in settings must exist on H |
| `~/.claude/.credentials.json` | **Never** | Each machine logs in for itself |
| `~/.claude.json` | **Never** | Machine state and per-machine MCP URLs |

## settings.json

1. Back up H's copy: `cp ~/.claude/settings.json ~/.claude/settings.json.bak-<timestamp>`.
2. Start from this machine's file and delete what doesn't belong on H: voice and UI keys, and any token in `env`:

   ```bash
   jq 'del(.voice, .voiceEnabled, .tui, .env.OP_SERVICE_ACCOUNT_TOKEN)' ~/.claude/settings.json > /tmp/settings.remote.json
   ```

3. Check `env` has no `ANTHROPIC_*`, which would override H's login. Then copy it across and delete the local file.
4. A hook that points into a repo needs that repo at the same path on H. See `clone-repos.md`.

## Connect the skills library

Skills reach H in one of two ways. Use the one this machine uses.

- **Plugins:** `claude plugin marketplace add <marketplace>`, then `claude plugin install <plugin>@<marketplace>`.
- **An MCP server that serves skills:** add it at user scope. A URL that works here may not work there, so use
  the address H can reach:

  ```bash
  claude mcp add --scope user --transport http <name> <url>
  ```

## Check

Run a headless prompt on H that can only be answered from the synced config: `claude -p "<question about a line in
CLAUDE.md>"`. It must quote the current text. Report what changed, what was left out on purpose, and that result.
