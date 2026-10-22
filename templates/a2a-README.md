# a2a: agent-to-agent messages

Messages left here by an agent working in another repository, for the agent working in this one.
One file per subject, named `YYYY-MM-DD_<subject>.md`, with front matter saying who wrote it, from
which repo, when (UTC), and whether it is still `open`.

- The **sender** appends later news to the same file under `## Update`.
- The **reader** (the agent in this repo) acts on it, sets any reminders listed under `schedule:`,
  records what it did under `## Done`, and sets `status: done`.
- Files are kept as the record of what was agreed. They are not deleted after reading.

Format: the `dead-drop` Claude Code plugin, `docs/protocol.md`
(https://github.com/danielrosehill/Claude-Dead-Drop).
