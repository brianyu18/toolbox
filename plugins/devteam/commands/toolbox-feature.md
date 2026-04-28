---
description: Backward-compat wrapper for /toolbox-feature — routes to the lead skill with --tier feature. Logs a deprecation notice.
---

The user invoked `/toolbox-feature` with: $ARGUMENTS

1. Append a deprecation INFO entry to slack via `bin/slack-append.sh`: `[LEAD] INFO  /toolbox-feature is deprecated; use /lead --tier feature instead. Routing now.`
2. Print to user: "Note: /toolbox-feature is deprecated. Please use /lead --tier feature going forward. Routing your request now."
3. Invoke the `lead` skill with `--tier feature` and $ARGUMENTS.
