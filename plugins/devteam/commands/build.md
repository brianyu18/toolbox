---
description: Direct BUILD — run BUILD phase standalone. Reads plan-partitions.md if present. Invokes /lead with --from BUILD which handles serial/parallel dispatch.
---

The user invoked `/build` with: $ARGUMENTS

1. Parse $ARGUMENTS for flags (--no-state) and task string.
2. Set `.devteam/state/.started-in` to `direct` if missing (create dir if needed).
3. If `--no-state`: dispatch a single `builder` agent via Task tool with the task as a single-partition brief. Skip slack/state writes.
4. Otherwise: invoke the `lead` skill with `--from BUILD` and the user's task. LEAD's body handles partition wave grouping and parallel BUILDER fan-out (per A1-final).
