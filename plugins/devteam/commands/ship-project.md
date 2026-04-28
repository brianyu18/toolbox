---
description: Direct SHIP — run the SHIP phase standalone. Version bump, changelog, commit, push, PR, deploy, canary, document-release. Invokes the shipper skill.
---

The user invoked `/ship-project` with: $ARGUMENTS

1. Parse $ARGUMENTS for flags (--no-state) and optional task string.
2. Verify `.devteam/state/` contains test results indicating passing status. If test results are absent or failing, warn the user and require explicit confirmation to proceed.
3. Set `.devteam/state/.started-in` to `direct` if missing (create dir if needed).
4. If `--no-state`: invoke the `shipper` skill ephemerally — skip state writes. (SHIPPER still confirms before destructive actions.)
5. Otherwise: invoke the `shipper` skill. SHIPPER handles version bump, changelog, commit, push, PR, deploy, canary, and document-release per its sequential playbook. Logs every step to `.devteam/state/ship-log.md` and to slack via `bin/slack-append.sh`.
6. On completion: report ship-log.md location and any deployed URLs.
