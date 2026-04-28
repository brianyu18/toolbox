---
description: One-time devteam setup — registers the SessionStart hook in ~/.claude/settings.json, seeds the conventions library to ~/.claude/devteam/conventions/ from the bundled conventions-seed/, and verifies plugin dependencies. Idempotent — safe to run repeatedly.
---

The user invoked `/lead-setup` with: $ARGUMENTS

1. **Resolve plugin install path.** Use `${CLAUDE_PLUGIN_ROOT}` if set; otherwise read `~/.claude/plugins/installed_plugins.json` and locate the `devteam` entry. Stash as `$PLUGIN_PATH`.

2. **Dependency check.** Read `~/.claude/plugins/installed_plugins.json`:
   - `superpowers` (REQUIRED) — refuse with install command + exit if absent.
   - `gstack` (SOFT) — warn that REVIEW + SHIP will degrade if absent.

3. **Create global directories** (idempotent, no overwrite):
   - `~/.claude/devteam/memory/`
   - `~/.claude/devteam/conventions/`
   - `~/.claude/devteam/projects/`

4. **Seed conventions library.** If `~/.claude/devteam/conventions/index.json` does NOT exist, copy contents of `$PLUGIN_PATH/conventions-seed/` to `~/.claude/devteam/conventions/`. If `index.json` already exists: print `[lead-setup] Conventions library exists at ~/.claude/devteam/conventions/ — no changes.` and skip — never overwrite user customizations.

5. **Register SessionStart hook.** Use the `update-config` skill (or edit directly) to add an entry to `~/.claude/settings.json`:
   ```json
   {
     "hooks": {
       "SessionStart": [
         {
           "type": "command",
           "command": "$PLUGIN_PATH/hooks/session-start.sh"
         }
       ]
     }
   }
   ```
   If the entry is already present (exact path match): print `[lead-setup] Hook already registered.` and skip.

6. **Ensure bin scripts are executable.** `chmod +x $PLUGIN_PATH/bin/*.sh` (idempotent).

7. **Report.** Print one line per step: `OK` / `SKIPPED` / `WARN`. Final line:
   - First-run: `[lead-setup] Setup complete. Run /lead <task> to start your first project.`
   - Idempotent re-run with no changes: `[lead-setup] Hook already registered. Conventions library exists at ~/.claude/devteam/conventions/ — no changes.` (matches T15 validation expected output exactly.)
