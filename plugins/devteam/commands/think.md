---
description: Direct THINK — run the THINK phase standalone. Explores intent, requirements, anti-requirements, and success criteria. Invokes the thinker skill.
---

The user invoked `/think` with: $ARGUMENTS

1. Parse $ARGUMENTS for flags (--no-state) and the task string.
2. Set `.devteam/state/.started-in` to `direct` if missing (create dir if needed).
3. If `--no-state`: invoke the `thinker` skill ephemerally — skip all state writes and slack logging.
4. Otherwise: invoke the `thinker` skill with the task string. THINKER writes `think.md` to `.devteam/state/` and appends a SUMMARY entry to slack via `bin/slack-append.sh`.
5. On completion: report the think.md location and suggest running `/plan` next (for feature/complex work).
