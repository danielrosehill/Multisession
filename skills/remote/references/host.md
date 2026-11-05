# Check, install, log in

## Check

Run on H, read-only. Report one line per item.

```bash
hostname; command -v claude && claude --version
claude auth status --text 2>&1 | head -5
```

| Result | Meaning | Next |
| --- | --- | --- |
| Host unreachable | SSH alias, network or key | Report it. Don't guess a route |
| `claude` not found | Not installed | Install, with the user's yes |
| Not logged in | No credentials on H | Log in |
| Old version | Cross-machine `SendMessage` needs 2.1.225 or later | `claude update` on H, with the user's yes |

## Install

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

It installs to `~/.local/bin`. Check with `bash -lc 'claude --version'`.

## Log in

A person has to do this. `claude auth login` on H gives a URL or opens a browser. Run it in the user's own
terminal, not through an agent's command route: suggest `ssh -t H claude auth login`.

Unconfirmed as of 2026-11-05: whether login completes with no browser on H. If it doesn't, log in with H's terminal
in a desktop session.

What the login method allows:

| Login | Headless `claude -p`, background sessions | Remote Control and cross-machine `SendMessage` |
| --- | --- | --- |
| Full claude.ai login | Yes | Yes |
| API key, `setup-token`, `CLAUDE_CODE_OAUTH_TOKEN` | Yes | **No** |
