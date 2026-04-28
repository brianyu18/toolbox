---
description: Display the team slack audit log for the current project — with optional phase filter and --decisions flag to show only DECISION entries.
---

The user invoked `/lead-show-slack` with: $ARGUMENTS

1. Parse $ARGUMENTS for:
   - `--phase <name>` — filter output to entries from a specific phase (e.g., `BUILD`, `REVIEW`).
   - `--decisions` — show only entries with `DECISION` severity.
   - `--tail <N>` — show only the last N entries (default: all).
2. Read `.devteam/state/slack.md`. If absent, report "No slack log found for the current project." and exit.
3. Apply filters from step 1.
4. Display the filtered entries in a readable format, preserving the `[AGENT#NN] SEVERITY  <text>` line structure.
5. If no entries match the filter, report "No matching entries."
6. No writes. This command is read-only.
