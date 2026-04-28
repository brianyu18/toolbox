---
description: Direct TEST — run TEST phase standalone. Optional layer arg: unit | integration | e2e | all (default: all). Invokes /lead with --from TEST which runs bin/devteam-detect-stack.sh --tests and dispatches tester workers per layer.
---

The user invoked `/test` with: $ARGUMENTS

1. Parse $ARGUMENTS — optional layer name.
2. Set `.devteam/state/.started-in` to `direct` if missing.
3. Invoke the `lead` skill with `--from TEST` and the parsed inputs. LEAD body handles layer detection + parallel tester dispatch (per A1-final).
