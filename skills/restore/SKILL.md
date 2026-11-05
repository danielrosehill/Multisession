---
name: restore
description: Bring back Claude Code sessions: ones lost when Konsole or the terminal crashed or closed, the last N, or ones picked from a menu, each resumed in its own repo in one split window, tabs or separate windows. Use on "restore my sessions", "Konsole crashed", "bring back my sessions", "reopen the last five", "which sessions can I restore".
---

# restore

When a terminal dies, every Claude session in it writes its transcript on the way out, within about a
second of the others. That burst identifies the sessions that were open. Each is resumed in the
directory it was started in. After a crash, restore first, then use `guard` to find out why.

```bash
SR="${CLAUDE_PLUGIN_ROOT}/scripts/session_restore.py"   # empty root: see spawn-session section 1
python3 "$SR" list                  # default: the most recent crash burst
python3 "$SR" list --last 12 --json # id, repo, title, active_ago, last_prompt, prompt_ago, in_crash
```

Sessions still running, and this session, are already left out.

## Which sessions

| User says | Selection |
| --- | --- |
| Lost, crashed, closed | The crash burst, no flags. If it looks wrong: `--minutes 15`, `--cluster-seconds 60` or `--last 5` |
| "The last five" | `--last 5` |
| Named or numbered ones | Id prefixes: `restore b23972c1 634a69af` |
| "Which sessions", no clear set | The menu below |

Show the list (repo, title, how long ago, last prompt) unless the user already named the set.

## Restore

```bash
python3 "$SR" restore                               # crash burst, split panes
python3 "$SR" restore --minutes 15 --layout tabs
python3 "$SR" restore --last 5 --dry-run            # plan as JSON, if the selection is in doubt
```

Use the same selection flags as `list`. The layout is the user's stated one, else one window of
side-by-side panes. Ask only if there are more than six sessions and no stated layout: offer `tabs` or
`windows`, because panes get narrow.

Report what opened (repo and title) and any `skipped_missing_cwd` (the repo moved or was deleted).

## Menu

Put everything in **one** `AskUserQuestion` call: up to three multi-select session questions, then a
single-select "Open as" question.

- Newest `in_crash` sessions first, then by recency, up to 12. Groups of at most 4, never a group of 1
  (5 is 3 + 2, 9 is 4 + 3 + 2). One session: skip the menu and ask only the layout.
- Label: `<repo>: <2-3 words of title>`, all unique. Description: `<title>. Active <active_ago> ago[, lost
  in the crash]. Last: "<last_prompt, about 70 chars>"`. The tool can't preselect, so the description
  carries the suggestion.
- "Open as": `One Konsole, split (Recommended)` is `--layout split`, `One Konsole each` is
  `--layout windows`. "Other" text such as "all", "the crash ones" or "tabs" maps to the same flags.
- Nothing ticked: say so and stop.

## Options

| Flag / env | Default | Meaning |
| --- | --- | --- |
| `--layout` / `SESSION_RESTORE_LAYOUT` | `split` | `split`, `tabs` or `windows` |
| `--orientation` / `SESSION_RESTORE_ORIENTATION` | `horizontal` | panes side by side, or `vertical` for stacked |
| `--command` / `SESSION_RESTORE_COMMAND` | `claude --resume {id}` | what each pane runs. `{id}` and `{cwd}` are replaced |
| `--cluster-seconds` / `SESSION_RESTORE_CLUSTER_SECONDS` | `10` | width of the crash burst |
| `--all` | off | include sessions still running |

## Limits

- Each pane starts where the session **started**: Claude Code files a transcript under the starting
  directory's project folder, so a session that changed directory can only be resumed from there.
- This opens real windows and resumes real sessions. To test the mechanics, use a harmless
  `--command 'echo {id}'`. A real `claude --resume` in a test would run the session in two places.
