---
description: Stop a running or paused LEAD project cleanly — preserve all state artifacts for later inspection or resume.
---

The user invoked `/lead-abort` with: $ARGUMENTS

1. Check `.devteam/state/` — if empty or absent, report "No in-flight project to abort." and exit.
2. Read `.project-name` and `.last-phase` to confirm which project is being aborted.
3. Confirm with the user before aborting: "About to abort project '<name>' (last phase: <X>). State will be preserved. Continue? [y/N]"
4. On confirm: append an INFO entry to slack via `bin/slack-append.sh`: `[LEAD] INFO  project aborted by user at phase <X>`.
5. Write `.devteam/state/.last-phase` to `aborted` to mark the project as stopped.
6. Report: "Project '<name>' aborted. Run `/lead-resume` to pick it back up, or `/lead` with a new task to start fresh."
