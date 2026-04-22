---
name: brains-bug
description: Use when investigating unexpected behavior, test failures, error messages, regressions, or any "why is this broken" / "this isn't working" question.
---

# brains-bug

Find the root cause. Reproduce it with a test. Fix it. Verify. Do not patch symptoms.

## Playbook

1. **Investigate.** Invoke `/investigate` (gstack) when the bug involves a running system, build pipeline, deployment, or browser. Invoke `superpowers:systematic-debugging` when it's a library/logic bug with no live system in the loop. Pick one.
2. **Reproduce as a test.** Invoke `superpowers:test-driven-development`. Write a failing test that captures the bug. Watch it fail. Do NOT start fixing until the repro test is red.
3. **Fix.** Make the smallest change that turns the test green. No opportunistic refactors, no drive-by cleanups.
4. **Verify.** Invoke `superpowers:verification-before-completion`. Run the full test suite, not just the new test. Confirm no regressions.
5. **Review.** Invoke `/review` (gstack) on the diff before committing.
6. **Commit.** Single commit, message describes root cause, not symptom.

## Red flags — stop, restart at the right step

| Red flag | Action |
|---|---|
| "This looks like the issue, let me just fix it" (no repro test) | Back to step 2 |
| Multiple unrelated changes in the diff | Revert the extras; single-responsibility |
| Can't write a repro test | You don't yet understand the bug. Back to step 1 |
| Fix works but you can't explain why | Back to step 1; symptom-patching suspected |
| Test is flaky after fix | Back to step 1; not fully reproduced |

## Escalate

If the bug reveals a systemic issue touching many files or requires redesign: abort and invoke `brains-complex`. Record what you learned so the complex route can start with it.
