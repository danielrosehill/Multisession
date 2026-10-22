---
kind: note
subject: <one line>
from_repo: <absolute path of your repo>
from_agent: <your peer name, from ListAgents' "This session is ...">
to_repo: <absolute path of the target repo>
written: <YYYY-MM-DDTHH:MMZ, UTC>
status: open
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

(The sender appends dated updates here.)

## Done

(The reader appends what it did, and any reminder it set, then sets `status: done`.)
