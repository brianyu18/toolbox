---
description: Toggle or display the LEAD autonomy mode — work-together (check-in at each phase boundary) or autonomous (proceed silently, notify on blocks).
---

The user invoked `/lead-mode` with: $ARGUMENTS

1. Parse $ARGUMENTS for a mode name: `work-together` or `autonomous`. If no argument given, display current mode and exit.
2. Validate the mode name. If unrecognized, print valid options and exit.
3. Write the mode name to `.devteam/mode` (create `.devteam/` dir if missing).
4. Append an INFO entry to slack via `bin/slack-append.sh`: `[LEAD] MODE  switched to <mode>`.
5. Confirm to the user: "Mode set to <mode>. Takes effect on next `/lead` invocation."
