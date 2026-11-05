---
name: continue-sprint
description: Refresh the context mid-sprint. Carry a long, multi-step piece of work into a fresh session without losing decisions: writes a sprint handover (what Daniel decided, in his words where it matters, plus state, plan and traps), then starts the new session through spawn-fresh. Use on "continue sprint", "context refresh", "refresh the context and carry on", "we're running tight on context", "summarise where we are and continue in a new session". For a finished task with an unrelated next one, use spawn-fresh.
---

# continue-sprint

spawn-fresh moves on to the next task. This skill keeps the same task going. What gets lost when a
long sprint changes session is not the code, which is in git, but the conversation: what the user
chose, what was tried and ruled out, and which approvals are still open. This skill writes those down.

## Parameters

As `spawn-fresh` (`name`, `dir`, `layout`, `direction`, `close`), and `name` defaults to
`<repo>-sprint-<next step slug>`. If the user wants to keep this session, pass `close: no`.

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

Follow `spawn-fresh` from section 2, with this message:

`Handover from <me>. You are continuing a sprint. Read <absolute path>/HANDOVER.md and take it from there. Treat ## Approvals as the limit of what is already agreed. Record what you did under ## Done in that file. Don't reply to me.`

## 4. Report

Tell the user what the new session is called, where the handover is, its first step, and anything
still waiting on them.

## Hard limits

- **Approvals don't grow in transit.** Write down what was approved, no more widely than it was given.
- **Nothing this session was denied.** Permission boundaries are per session.
- **No secret values** in the handover or the message.
