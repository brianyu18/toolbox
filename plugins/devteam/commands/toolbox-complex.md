---
description: Backward-compat wrapper for /toolbox-complex — routes to the lead skill with --tier complex. Logs a deprecation notice.
---

The user invoked `/toolbox-complex` with: $ARGUMENTS

1. Append a deprecation INFO entry to slack via `bin/slack-append.sh`: `[LEAD] INFO  /toolbox-complex is deprecated; use /lead --tier complex instead. Routing now.`
2. Print to user: "Note: /toolbox-complex is deprecated. Please use /lead --tier complex going forward. Routing your request now."
3. Invoke the `lead` skill with `--tier complex` and $ARGUMENTS.
