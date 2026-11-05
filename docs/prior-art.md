# Prior art

Consolidated on 2026-11-05. Predecessor repos and what came across. "Carried" means the idea or file now lives
here. Dropped items were superseded by something Multisession already does.

| Repo | What it was | What came across, and where | Dropped |
| --- | --- | --- | --- |
| Claude-Hopper (14 skills) | Session jumping and handover | `new-claude-here`, `new-claude-at`, `terminal-here`, `vscode-here`, `claude-and-shell`, `claude-grid` to `compose` built-in presets and `scripts/grid.sh`. `handover` menu, `clipboard-handover`, `handover-with-tasks`, `start-from-handover` to `skills/handover`. `sideclaude`, `start-leftover` to `skills/spawn-fresh`. `spawn-planning-repo` to `repo-mgmt` | `new-workspace` (a meta-tools scaffold; `repo-mgmt:new-workspace-repo` covers the need). The window-killing close (`kill -TERM` on Konsole), replaced by `close-pane.sh`. The D-Bus `runCommand` recipes, which Konsole refuses by default |
| Session-Restore (8 skills) | Crash recovery and Konsole guards | `scripts/session_restore.py`, `konsole_close_guard.py`, `compositor_guard.py`. Skills to `restore`, `guard`, `setup`. PreToolUse hook to `hooks/hooks.json`. Incident to `docs/incidents/`. Changelog to `docs/prior-art/session-restore-CHANGELOG.md` | `update` as its own skill (now a section of `setup`) |
| Claude-Konsole-Setup (2 skills) | Konsole settings and profile | `scripts/konsole-settings.sh`, `scripts/konsole-profile.sh`, `templates/konsole/`, `skills/setup` | Its curl fallback for the guard: the guard now sits beside the script |
| Claude-PA (kept) | House-wide escalation and phone calls | Phone call to `skills/notify`, `scripts/notify-call.sh` (rewritten: user and named contacts), `templates/vapi/system-prompt.md` | Not carried, so the repo stays: speakers, signal bulb, voice packs, screen flash, Home Assistant cascade, MQTT, escalator, mute and schedule |
| Claude-Voice-Notifier | Planned one-way Twilio voice notifications. The code was never committed and stopped before `cli.py` | Rules to `skills/notify/references/calling-others.md`, `templates/vapi/system-prompt.md`, `scripts/notify-call.sh`. Everything else, including the uncommitted 2026-08-13 code, kept as it was in `docs/prior-art/voice-notifier/`: not wired in, never run | Nothing |
| Claude-Server-Harness-Plugin (kept) | One server's harness | `transfer-sessions`, `align-config`, `clone-repos` rewritten as generic templates in `skills/remote/references/` | Not carried: Codeman, the host-specific `harness.py` and `check-harness`. The repo stays for that server |

`breakout-model` became `skills/breakout/references/model.md`.

## What the grid had to change

Hopper's `claude-grid` ran `konsole -e claude` and split that. Two things stop this: `createSplit` starts the new pane
with the source pane's command, and Konsole refuses `Session.runCommand` by default. `scripts/grid.sh` opens a plain
shell and has every pane claim a launch file instead.

The first attempt targeted `org.kde.konsole-<pid>`, and no pane claimed it, because `KONSOLE_DBUS_SERVICE` in a pane is
the unique bus name (for example `:1.3107`), which can't be known before the window starts. The hook now also accepts
`# target-pid: <pid>`, matched against the shell's parent. Confirmed on Konsole 25.12.3, 2026-11-05.
