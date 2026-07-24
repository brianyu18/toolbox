---
description: Pass the mission baton to a fresh session (relay leg, not a resume). Args — none (manual pass), --attempt <id> (automation handshake), --done (mark mission complete), or a goal/DoD override.
---

Invoke the `relay` skill. Pass `$ARGUMENTS` verbatim — the skill parses `--attempt <id>` (automation, noninteractive), `--done` (complete the mission), and free text (goal/definition-of-done override).
