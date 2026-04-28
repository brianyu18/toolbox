---
description: Backward-compat wrapper for /toolbox-bug — routes to the lead skill with --tier bug. Logs a deprecation notice.
---

The user invoked `/toolbox-bug` with: $ARGUMENTS

1. Append a deprecation INFO entry to slack via `bin/slack-append.sh`: `[LEAD] INFO  /toolbox-bug is deprecated; use /lead --tier bug instead. Routing now.`
2. Print to user: "Note: /toolbox-bug is deprecated. Please use /lead --tier bug going forward. Routing your request now."
3. Invoke the `lead` skill with `--tier bug` and $ARGUMENTS.
