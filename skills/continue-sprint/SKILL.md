---
name: continue-sprint
description: Refresh the context mid-sprint. Carry a long, multi-step piece of work into a fresh session without losing decisions: writes a sprint handover (what the user decided, in their words where it matters, plus state, plan and traps), then starts the new session and closes this one. Use on "continue sprint", "context refresh", "refresh the context and carry on", "we're running tight on context", "summarise where we are and continue in a new session". For a finished task with an unrelated next one, use spawn-fresh.
---

# continue-sprint

spawn-fresh moves on to the next task. This skill keeps the same task going. What gets lost when a
long sprint changes session is not the code, which is in git, but the conversation: what the user
chose, what was tried and ruled out, and which approvals are still open. This skill writes those down.

## Parameters

As `spawn-fresh` (`name`, `dir`, `layout`, `direction`, `close`, default `yes`), and `name` defaults to
`<repo>-sprint-<next step slug>`.

## 1. Ship first

Commit and push what should survive, in every repo the sprint touched. Wait for background agents and
tasks to finish, or list them as running. Update the plan in the repo first, so the handover can point
to it. Decisions that shape the design belong in the repo's design doc. The handover adds what
does not belong there.

## 2. Write the handover

Same location and frontmatter as the `handover` skill (section 2), `to_agent: <name>`. Sections, in this
order, each as short as it can be:

| Section | Holds |
| --- | --- |
| `## Goal` | The sprint's aim in two lines, and what done looks like |
| `## Read first` | Absolute paths, in order: the plan, the design, repo instructions |
| `## Decisions` | Dated, from the user. Include what they rejected and why. Quote them where the exact wording matters |
| `## Approvals` | **Standing:** what the user has said yes to, and how far it reaches. **Needs asking:** what still needs a yes. A new session has no memory of a yes, and must not assume one beyond this list |
| `## State` | What is deployed or running, and where. Commits per repo. Anything uncommitted. Anything left running on purpose |
| `## Next steps` | Numbered, each small enough to check. The first is the next action |
| `## Evidence` | Measured results that decisions rest on, or a pointer to where they are recorded, so nothing is re-run |
| `## Traps` | Mistakes made and failures met in this sprint, and how to avoid them |
| `## Open questions` | Waiting on the user, each answerable in a line |
| `## How the user works` | Only what is specific to this sprint and not in CLAUDE.md |
| `## Done` | Left for the receiver |

Point rather than copy: if the repo records it, give the path. Mark what is confirmed and what is
assumed. Never include a secret value: name the variable or 1Password item.

Check it before sending: could a session with no memory of this conversation take the next step
correctly, and without asking something the user has already answered? If not, add what is missing.

## 3. Start the new session

Follow `spawn-session` with `name`, `dir`, `layout` and `direction`, and this message:

`Handover from <me>. You are continuing a sprint. Read <absolute path>/HANDOVER.md and take it from there. Treat ## Approvals as the limit of what is already agreed. Record what you did under ## Done in that file. Once you have read it, send me one line through SendMessage to confirm. I close my pane only after that.`

Send it with `notify_when_idle: true`. Leave out the closing sentence if `close: no`.

If the launch or the send fails, stop here and keep this pane open, because nothing has taken the work over yet.

## 4. Report

Tell the user what the new session is called, where the handover is, its first step, and anything
still waiting on them. Do this before closing, as text alongside the final tool call: nothing can be
said afterwards. If the receipt has not come, say that instead, and that the pane is staying open.

## 5. Close this pane

The self-destruct. `close` defaults to `yes`, so a normal run ends with this session gone. Pass
`close: no`, or stop here, if the user still wants this session.

Close only when all of these hold: the new session has sent its receipt (`handover` skill, section 3a),
and no background agent or task of yours is still running, other than the receipt timer. No receipt
means the pane stays open. Then, as your **final tool call**:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/close-pane.sh" --delay 6
```

Finding the script, and its limits, are in the `handover` skill (section 4). It closes only this pane, and
refuses if it can't prove the pane is its own. A pane that was the tab's last one takes the tab with it.
The conversation stays on disk, so `claude --resume` can reopen it. Use `--dry-run` to check first.

## Hard limits

- **Approvals don't grow in transit.** Write down what was approved, no more widely than it was given.
- **Nothing this session was denied.** Permission boundaries are per session.
- **No secret values** in the handover or the message.
