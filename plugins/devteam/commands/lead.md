---
description: LEAD mode — full team orchestration. Subsumes the toolbox router. Classifies a task, dispatches specialists, funnels questions, reports.
---

The user invoked `/lead` with: $ARGUMENTS

1. Parse $ARGUMENTS for flags (--tier, --mode, --notify, --no-notify, --from, --dry-run) and the task string.
2. If `--no-state` was passed: refuse with explanation (`/lead` requires state; use a direct specialist command for ephemeral runs).
3. If `--from <phase>` was passed: validate the phase's prerequisites exist in `.devteam/state/`; if not, prompt user to back-fill or reject.
4. Invoke the `lead` skill with the parsed inputs.
5. The `lead` skill handles: dependency check, classification, dispatch loop, funnel, reporting.
