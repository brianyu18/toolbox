---
description: One-time devteam setup — registers the SessionStart hook, seeds global convention directories, and verifies required plugin dependencies.
---

The user invoked `/lead-setup` with: $ARGUMENTS

1. Check for required dependencies: verify `superpowers` plugin is in `~/.claude/plugins/installed_plugins.json`. Warn (do not block) if `gstack` is absent.
2. Create required directories if missing:
   - `~/.claude/devteam/memory/`
   - `~/.claude/devteam/conventions/`
   - `~/.claude/devteam/projects/`
3. Seed `~/.claude/devteam/conventions/index.json` with an empty array `[]` if the file does not yet exist.
4. Register the SessionStart hook: add a `sessionStart` entry to `.claude/settings.json` in the current project pointing to the devteam hook (path from plugin root). Skip if already registered.
5. Ensure `bin/slack-append.sh` is executable (`chmod +x`).
6. Report: list each step as OK / SKIPPED / WARN, then print "Setup complete. Run `/lead <task>` to start your first project."
