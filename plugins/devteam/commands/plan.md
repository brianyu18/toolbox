---
description: Direct PLAN — run the PLAN phase standalone. Converts think.md into a concrete implementation plan with wave-grouped partitions. Invokes the planner skill.
---

The user invoked `/plan` with: $ARGUMENTS

1. Parse $ARGUMENTS for flags (--no-state) and optional task string.
2. Verify `.devteam/state/think.md` exists. If missing and no task string given, prompt user to run `/think` first or provide a task string directly.
3. Set `.devteam/state/.started-in` to `direct` if missing (create dir if needed).
4. If `--no-state`: invoke the `planner` skill ephemerally — skip state writes and slack logging.
5. Otherwise: invoke the `planner` skill. PLANNER writes `plan.md` and `plan-partitions.md` to `.devteam/state/` and appends a SUMMARY entry to slack via `bin/slack-append.sh`.
6. On completion: report the plan.md and plan-partitions.md locations and suggest running `/build` next.
