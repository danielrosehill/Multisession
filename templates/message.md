---
kind: note
subject: <one line>
from_repo: <absolute path of your repo>
from_agent: <your peer name, from ListAgents' "This session is ...">
to_repo: <absolute path of the target repo>
written: <YYYY-MM-DDTHH:MMZ, UTC>
updated: <YYYY-MM-DDTHH:MMZ, UTC; set on every revision>
revision: 1
status: open
# Optional. Ask the reader to re-read this on an interval because you will keep revising it.
watch: 30m
# Optional. Delete if you are not asking the reader to set a reminder.
schedule:
  - at: <YYYY-MM-DDTHH:MMZ, UTC>
    do: <what the reader should do at that time, readable cold>
---

# <subject>

<!--
The reader has no memory of your session and cannot see your repo's context. Name paths,
identifiers and versions explicitly. Mark which facts you measured and which you inferred.
-->

## What you need to know

## What to do

1. 

## How to tell it is ready

<!-- For anything time-dependent: a command or check that tests the thing itself, so the reader
does not act on the ETA alone. Delete if nothing is pending. -->

## Update

(The sender adds one line per revision, newest first: `r2, 15:40Z: what changed`.)

## Done

(The reader appends what it did, and any reminder it set, then sets `status: done`.)
