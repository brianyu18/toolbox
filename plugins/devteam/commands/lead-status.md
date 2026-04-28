---
description: Show read-only status of LEAD and any in-flight project — current phase, mode, last activity, and pending blocks.
---

The user invoked `/lead-status` with: $ARGUMENTS

1. Read `.devteam/mode` (default: `work-together` if missing).
2. Read `.devteam/state/` — check for `.project-name`, `.last-phase`, `.started-in`; if state dir is empty or absent, report "No in-flight project."
3. Check for any `WAITING ON USER` entries in `.devteam/state/slack.md` (unresolved blockers).
4. Print a status summary:
   - Project name (or none)
   - Current / last phase
   - Autonomy mode
   - Pending blocks (if any), with question text
   - Last slack entry timestamp and text
5. No writes. This command is read-only.
