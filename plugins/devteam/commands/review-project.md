---
description: Direct REVIEW — run REVIEW phase standalone on the current diff. Renamed from /review to avoid collision with gstack:/review. Invokes /lead with --from REVIEW which runs bin/devteam-pick-lenses.sh and dispatches review-specialist workers in parallel.
---

The user invoked `/review-project` with: $ARGUMENTS

1. Parse $ARGUMENTS — optional path to scope review, flags.
2. Set `.devteam/state/.started-in` to `direct` if missing.
3. Invoke the `lead` skill with `--from REVIEW` and the parsed inputs. LEAD body handles lens selection (via bin/devteam-pick-lenses.sh) + parallel review-specialist dispatch (per A1-final).
