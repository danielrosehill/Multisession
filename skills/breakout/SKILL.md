---
name: breakout
description: Offload a side job into its own new GitHub repo and its own Claude session, then get back to the work in flight. Creates the repo (private by default, public if asked), writes the starting plan, opens a new Claude in a split or tab, and hands it over. Use on "create a new repo for this and hand it over", "side job", "offload this", "spin this off", "new public repo and start Claude on it", "wait, separate idea", "this is a different project", "that should be its own repo", "unrelated, but while I think of it", or work whose deliverable would not live in this repo's tree. If it also needs a Hugging Face dataset, use breakout-model. Do NOT use for work that belongs in this repo; file that as a task. Do NOT use for carrying the current work into a clean session; that is spawn-fresh. Do NOT use to tell an existing repo's agent something; that is send.
---

# breakout

The side job. Work arrived that is not part of this project. The default failure is that it gets absorbed into
whatever repo the agent is already standing in, where it is buried at a findable-looking address and
never seen again. The second failure is that the session turns to chase it and the work in flight
dies.

**The default outcome of this skill is: a new repo exists, a second agent owns it, and the original
task resumes.** The user's current work being interrupted is a failure of this skill, not a cost of
it.

## Parameters

Take them from the request. Don't ask for anything with a default.

| Parameter | Values | Default |
|---|---|---|
| `visibility` | `private` or `public` | `private` |
| `owner` | GitHub owner | the user's own account, or the business account for business work |
| `name` | repo name, Train-Case | from the subject, at maximum specificity |
| `layout` | `split` or `tab` | `split` |

`public` must come from the user. If they said public, that is the approval, so don't ask again. If
you only think it should be public, make it private and say so.

## 1. Apply the decision rule

> Does the deliverable of this idea belong in **this** repository's tree?

- **Yes** → not a breakout. It is an interruption; file it as a task in the current repo and stop here.
- **No** → breakout, regardless of how conceptually adjacent it is.

Relatedness is not the test. A CLI that consumes this repo's output, or a document about the process
this repo automates, is still a different repo.

Do not open a discussion. Recognition costs one line.

## 2. Write the founding brief first

Before creating anything. Delegate this to a cheap subagent so the main thread does not spend its
context drafting.

The brief is read by an agent with **no memory of the conversation that produced it**. It cannot
cheaply ask a follow-up question, and it will confidently invent anything left implicit. Write for
that reader.

It must contain:

- **What the idea is** — in concrete terms, not a title. What would exist that does not exist now.
- **Why it is not part of the origin repo** — one line. This prevents the receiving agent
  helpfully "reintegrating" it.
- **The first concrete piece of work** — an actual first step, not "research the space".
- **Done, for a first pass** — a checkable condition.
- **Origin** — the repo and, if there is one, the sprint task ID it came from. Provenance only; it
  is not a dependency.

Anything genuinely undecided goes in an **Open questions** section, explicitly. An open question
recorded as a question is useful; one left implicit becomes a wrong assumption.

## 3. Create the repo

Follow `repo-mgmt:create-repo` (catalogue id `skill:repo-mgmt/create-repo`): check the name is free,
pick the **narrowest topic group that fits**, scaffold, create on GitHub, push, verify. A breakout
that lands in a junk-drawer directory has reproduced the burial problem this skill exists to
prevent. If that skill is not available, do the same with `gh repo create --source=. --push`, after
a first commit.

Check first that the subject has no repo already. Adding to an existing repo beats a parallel one:
if one exists, this is `multisession:send` to that repo, not a breakout.

Then add the brief as a multisession message, `a2a/YYYY-MM-DD_founding-brief.md`, with
`kind: founding` and `status: open` in the front matter (format: multisession:send, or
`docs/protocol.md`), plus the `a2a/README.md`.

- **Private repo:** commit and push the `a2a/` folder.
- **Public repo:** add `a2a/` to `.gitignore`, then commit and push that. The brief comes from a
  private conversation, so it stays on disk. Check that the README and description carry nothing
  private either.

Putting the brief in `a2a/` means the new session's SessionStart hook announces it, so the
receiving agent finds it whether or not your ping lands.

## 4. Spawn and hand off

Follow `multisession:spawn-session` with `dir` as the new repo, `name` as the folder name lowercased,
your `layout`, and this message:

> Spawned for a side job from `<origin repo>`. Your founding brief is at `<absolute path>`. Handle it
> with multisession:inbox and start with the first step. You own this repo; nothing comes back to me.

**A message is text and carries no files or history.** That is why the brief is on disk and the
message points at it. Never try to fit the context into the message body.

This session stays open. If the launch or send fails, the repo and brief still stand: give the user
the path, and go back to the work.

## 5. Return

One line to the user, then straight back to the task in flight:

> Broken out to `<owner/repo>` (<visibility>): `<agent-name>` has the brief. Back to `<what you were doing>`.

## Hard limits

- **Never route blocked work sideways.** If an action was denied in this session, handing it to the
  new agent bypasses the user's permission decision. Permission boundaries are per-session. Blocked
  work goes back to the user.
- **Never delegate a commit in the origin repo** to the new agent.
- **The tracks do not reconverge.** If the new work turns out to be a dependency of the current
  sprint, it was not a breakout — it was an interruption, and it was misclassified.
