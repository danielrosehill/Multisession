---
name: compose
description: Run any mix of session and desktop actions from one plain request - hand over, start one or more Claude sessions in a split, tab or new window, open a plain terminal, Dolphin, an editor or a URL, keep or close this pane, or run a saved preset. Use when the user combines them, e.g. "hand over to a new window, open Dolphin and a terminal there, then self-destruct", "two new sessions side by side", "new session below and keep me open", "open this folder in Dolphin and Konsole", "my sprint layout", "save this as a preset".
---

# compose

The other Multisession skills are fixed recipes. This one takes the user's words, turns them into a list of
actions and runs them in order. Add a new action here, not a new skill.

## Actions

Scripts are in this plugin's `scripts/`. `spawn-session` says where to find them if `CLAUDE_PLUGIN_ROOT` is empty.

| Action | Does | How |
| --- | --- | --- |
| `handover` | Write the task to a file | `handover` skill format, or `continue-sprint` section 2 if the same work carries on. `spawn-fresh` section 1 for a new task |
| `session` | A new named Claude | `spawn-session.sh --name N --dir D --layout L --direction R` |
| `send` | Point a session at its handover | `spawn-session` section 2, with `notify_when_idle: true`. A session started with no task needs none |
| `receipt` | Wait for a session to confirm it read the handover | `handover` section 3a. Implied before `close` |
| `terminal` | A plain shell in a folder, no Claude | `spawn-session.sh --terminal --dir D --layout L --direction R` |
| `files` | Dolphin in a folder | `open-files.sh D` |
| `editor` | The user's editor in a folder | `setsid -f ${VISUAL:-code} D`, or the `editor` key in the config |
| `browser` | Open a URL | `xdg-open URL` |
| `close` | Self-destruct this pane | `close-pane.sh --delay 6`, as in `continue-sprint` section 5 |
| `keep` | Leave this pane open | Do nothing |

**Where things go:**

| User says | `--layout` | `--direction` |
| --- | --- | --- |
| "split", "beside", "side by side", "to the right", "vertical split", no preference | `split` | `right` |
| "below", "underneath", "stacked", "horizontal split" | `split` | `down` |
| "tab" | `tab` | |
| "new window", "in a window" | `window` | |

People use "vertical" and "horizontal" split in opposite ways. If the words could mean either and it
matters, use "beside" or "below" as the guide, and say which way you went.

A folder not named means the directory of the session being started, or the current one.

## Running a plan

1. **Build the list** from the request, and state it in one line. If it includes `close`, or more than two
   sessions, check nothing in it is a guess. Otherwise just go.
2. **Order:** `handover` first, so a new session never waits. Then `session` and `send` for each session.
   Then `terminal` and `files`. `close` is always last, with the report just before it.
3. **Each session needs its own name,** and its own handover if it has its own task.
4. **Stop on failure.** If a `session` or `send` fails, stop, keep this pane open, and report which
   actions ran. Never retry blind: that stacks up panes. A failed `terminal` or `files` is only reported.
5. **`close` is earned.** It needs a receipt from every session handed work in this plan, so ask for one
   in each `send`. No receipt means the pane stays open. Then follow `continue-sprint` section 5. If the user did not say
   `close`, keep the pane, unless the recipe they named closes by default.

## Presets

A preset is a saved plan, kept with the user's own settings in `~/.config/multisession/config.json`,
never in this plugin, so it survives updates. "Save this as my sprint layout" adds one:

```json
{
  "presets": {
    "sprint": {
      "description": "Carry on in a new window, with the repo open beside it",
      "plan": ["handover", "session window", "send", "files", "terminal window", "close"]
    }
  }
}
```

Steps use the notation below. `{dir}` and `{url}` in a step are filled in from the request or the current
directory. Merge into the file, keeping its other keys. On "my sprint layout", or `compose sprint`, read the
preset and run it as a plan: the rules above still apply, so `close` must still be earned. Words in the
request win over the preset, so "my sprint layout, but keep me open" swaps `close` for `keep`. "What
presets do I have" lists them.

## Examples

"Hand over in a new window, open Dolphin and a terminal there, then self-destruct":

```
handover -> session (window) -> send -> files -> terminal (window) -> receipt -> report -> close
```

"Two new sessions side by side on these tasks, and keep me open":

```
handover x2 -> session (split, right) -> send -> session (split, right) -> send -> keep
```

"Open the repo in Konsole and Dolphin": `terminal (window) -> files -> keep`

## Limits

- Permission boundaries are per session. A new session gets nothing this one was denied.
- No secret values in a handover or a message.
- Never close another session's pane.
- A split needs this pane to be a plain shell, or it becomes a tab. A pane inside a `window` action's
  Claude session is not one until Claude exits, so splits made from it become tabs.
