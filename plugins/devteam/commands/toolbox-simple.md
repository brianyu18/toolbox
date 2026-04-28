---
description: Backward-compat wrapper for /toolbox-simple — routes to the lead skill with --tier simple. Logs a deprecation notice.
---

The user invoked `/toolbox-simple` with: $ARGUMENTS

1. Append a deprecation INFO entry to slack via `bin/slack-append.sh`: `[LEAD] INFO  /toolbox-simple is deprecated; use /lead --tier simple instead. Routing now.`
2. Print to user: "Note: /toolbox-simple is deprecated. Please use /lead --tier simple going forward. Routing your request now."
3. Invoke the `lead` skill with `--tier simple` and $ARGUMENTS.
