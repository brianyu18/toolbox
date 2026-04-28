---
description: Backward-compat wrapper for /toolbox — routes to the lead skill with no --tier flag (LEAD classifies). Logs a deprecation notice.
---

The user invoked `/toolbox` with: $ARGUMENTS

1. Append a deprecation INFO entry to slack via `bin/slack-append.sh`: `[LEAD] INFO  /toolbox is deprecated; use /lead instead. Routing now.`
2. Print to user: "Note: /toolbox is deprecated. Please use /lead going forward. Routing your request now."
3. Invoke the `lead` skill with $ARGUMENTS (no --tier override; LEAD classifies the task tier automatically).
