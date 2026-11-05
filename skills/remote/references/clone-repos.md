# Clone repos to the same paths

**Template.** Keeping the same path on both machines means paths in skills, docs and transcripts hold on both.

- **One repo:** on H, `mkdir -p <parent> && git clone <url> <path> && git -C <path> checkout <branch>`, using this
  machine's path and current branch. Skip it if it exists.
- **In bulk:** build `path url branch` lines here, for repos with a commit in the last N days. Copy the list to H and
  run the loop in the background with `nohup`, logging to a file. Check the log for failures.
- **A GitHub API limit is shared across machines.** Check `gh api rate_limit` before more than about 100 repos, and
  stop under about 500.
- **"Could not resolve to a Repository" on an org repo** means H's `gh` login can't see that org. A person has to fix
  that, with `gh auth login` on H.

Report counts: OK, skipped, failed, with the reason for each failure.
