---
description: Continue a paused or WAITING ON USER LEAD project — optionally supply an answer to the pending block before resuming.
---

The user invoked `/lead-resume` with: $ARGUMENTS

1. Check `.devteam/state/` — if empty or absent, report "No in-flight project to resume." and exit.
2. Read `.project-name`, `.last-phase`, `.started-in` to reconstruct context.
3. Scan `.devteam/state/slack.md` for the most recent `WAITING ON USER` entry. If found, surface the pending question prominently.
4. If $ARGUMENTS includes an answer (any non-flag text), treat it as the user's answer to the pending block.
5. Invoke the `lead` skill with the reconstructed context and any supplied answer. LEAD resumes from `.last-phase`, re-dispatching the blocked specialist with the answer in the brief.
6. Log a `[LEAD] INFO  resumed from <phase>` entry to slack via `bin/slack-append.sh`.
