---
name: remote
description: Run Claude on another machine and work with it from this one: check it, install and log in, sync settings and skills, start background sessions, message them, move a session across, clone repos to the same paths. Use on "is Claude set up on <host>", "install Claude on the server", "sync my config to <host>", "start a session on <host>", "move this session to the server", "put this repo on <host>", "message the agent on <host>".
---

# remote

One skill for every machine that isn't this one. Read the reference file for the job.

| Job | Reference |
| --- | --- |
| Is it ready: SSH, Claude, version, login. Install. Log in | `references/host.md` |
| Sync settings. Connect the skills library | `references/sync.md` |
| Start background sessions. Message them. Move a session across | `references/sessions.md` |
| Clone repos to the same paths | `references/clone-repos.md` |

## Reaching a host

Hosts are the user's, so they live in `~/.config/multisession/config.json`, never in this plugin:

```json
{
  "remote": {
    "hosts": {
      "<alias>": { "ssh": "<ssh alias or user@host>", "exec_tool": "<optional tool that runs a command there>" }
    }
  }
}
```

If the host has an `exec_tool`, run commands through that tool instead of SSH. It is the user's chosen route.
Otherwise use `ssh -o BatchMode=yes -o ConnectTimeout=5 <host> 'bash -lc "<command>"'`. The login shell is what
puts `~/.local/bin/claude` on the PATH. A host not in the config: use the name given as an SSH alias, and offer
to save it. Below, "run on H" means whichever route applies.

## Rules

- **Read first.** Check before changing. Changing another machine is the user's call: say what you will change,
  and go on only if they asked for that change.
- **Never copy `~/.credentials.json` or `~/.claude/.credentials.json`.** Each machine logs in for itself.
- **A running service on that machine is not yours to restart** unless the user said so.
- Files marked **Template** in the references were written from one setup and checked no further. Read them as a
  shape to adapt, and report what you had to change.
