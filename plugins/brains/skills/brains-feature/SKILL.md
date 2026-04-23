---
name: brains-feature
description: Use when adding a new feature of medium scope to an existing product — clear intent, bounded surface area, single subsystem, user-visible or not.
---

# brains-feature

Medium-scope work gets full discipline but skips the multi-role review gauntlet reserved for complex work.

## Playbook

1. **Brainstorm.** Invoke `superpowers:brainstorming`. Explore user intent, requirements, and explicit non-requirements. Do NOT skip even if the user handed you a clear spec — the skill surfaces hidden assumptions.
2. **Plan.** Invoke `superpowers:writing-plans`. Produce a written plan before any code.
3. **Align with user.** Share the plan. Wait for green light. Do not implement against an unconfirmed plan.
4. **TDD implementation.** Invoke `superpowers:test-driven-development` per implementation unit. Red → green → refactor.
5. **Verify.** Invoke `superpowers:verification-before-completion`. Full suite. If there's a UI, exercise the feature end-to-end manually or via `/browse`.
6. **Review — two angles.**
   - `/review` (gstack) for Claude-side pre-landing review.
   - `/codex` (gstack) in review mode for an independent non-Claude second opinion.
   Address substantive feedback from both before shipping.
7. **Ship.** Invoke `/ship` (gstack).

## Decision gates

- **After step 2 (plan written):** If the plan reveals multi-subsystem scope or high ambiguity, escalate to `brains-complex`.
- **After step 4 (implementation complete):** If this touches a running product, insert `/qa` (gstack) between steps 5 and 6.
- **Before step 7 (ship):** If this touches production-visible behavior, follow `/ship` with `/land-and-deploy` + `/canary` (gstack).

## Skip list — these belong to the complex playbook

- `/plan-ceo-review`, `/plan-design-review`, `/plan-devex-review`
- `/autoplan`
- Worktree isolation + `superpowers:subagent-driven-development`

Using them here is overkill. If you think you need them, you're probably doing `brains-complex`.

## Escalate

- Scope creeps beyond one subsystem → `brains-complex`.
- Plan review finds the premise is wrong → back to step 1, possibly re-classify.
