---
description: Direct REFLECT — run the REFLECT phase standalone. Mines the project for lessons, updates global memory, runs watchlist analysis. Invokes the reflector skill.
---

The user invoked `/reflect` with: $ARGUMENTS

1. Parse $ARGUMENTS for flags (--no-state, --tier) and optional task string.
2. Set `.devteam/state/.started-in` to `direct` if missing (create dir if needed).
3. If `--no-state`: invoke the `reflector` skill ephemerally — skip global memory writes and watchlist logging.
4. Otherwise: invoke the `reflector` skill. REFLECTOR reads slack.md and state artifacts, identifies lessons (scoped to tier), writes `.devteam/state/reflect.md`, appends global lessons to `~/.claude/devteam/memory/`, and logs SUMMARY + WATCHLIST entries to slack via `bin/slack-append.sh`.
5. On completion: report reflect.md location and any global memory files updated.
