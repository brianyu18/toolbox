---
name: brains-simple
description: Use for trivial development tasks — one-file edits, config tweaks, doc changes, rename refactors, or factual questions where full brainstorm/plan/review discipline would be pure overhead.
---

# brains-simple

Small tasks need correctness, not ceremony.

## Playbook

1. Read the target file and anything it depends on or is depended by.
2. Make the change.
3. Invoke `superpowers:verification-before-completion` to confirm the edit actually did what you claimed — run the relevant command, don't assert success from reading alone.
4. Report what changed in one sentence.

## When to escalate — re-invoke `brains`

If any of these appear mid-task, stop and reclassify:
- You need to touch more than 2 files.
- You find unexpected behavior (→ likely `brains-bug`).
- The change implies new behavior, not just modified existing behavior (→ likely `brains-feature`).
- The "simple" change reveals structural problems in the surrounding code.

## What to skip on this route

- Brainstorming
- Written plans
- TDD ceremony (but: if the file has a test suite and you changed logic, add or update one test)
- Multi-agent review

## What NOT to skip

- Reading before writing. Always.
- Verification. "Looks right" is not verification.
