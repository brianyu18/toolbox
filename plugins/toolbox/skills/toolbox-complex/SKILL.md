---
name: toolbox-complex
description: Use for new subsystems, multi-file rewrites, user-visible product changes with design stakes, or tasks with ambiguous scope or significant cross-cutting impact.
---

# toolbox-complex

High-stakes or high-ambiguity work. Maximum discipline, multi-angle plan review, parallelized execution.

## Playbook

### Phase 1 — Brainstorm & plan

1. `superpowers:brainstorming` — user intent, requirements, anti-requirements, success criteria.
2. `superpowers:writing-plans` — first-draft written plan.

### Phase 2 — Multi-role plan review

3. `/plan-eng-review` (gstack) — architecture, data flow, edge cases, test coverage. **Non-skippable.**
4. `/plan-ceo-review` (gstack) — scope challenge, is this the 10-star version. Skip only if scope is already hard-locked by external constraint.
5. `/plan-design-review` (gstack) — required if there's any UI surface. Skip if purely backend/infrastructure.
6. `/plan-devex-review` (gstack) — required if this is a developer-facing surface (API, CLI, SDK). Skip otherwise.
7. `/autoplan` (gstack) — batch auto-review pipeline to surface taste decisions not caught above.
8. **Align with user.** Share the refined plan. Do not proceed until green-lit.

### Phase 3 — Execute

9. `superpowers:using-git-worktrees` — isolate the work from the current workspace. **Non-skippable.**
10. `superpowers:subagent-driven-development` for independent parallelizable tasks, OR `superpowers:executing-plans` for sequential work with shared state.
11. `superpowers:test-driven-development` within each task. **Non-skippable per task.**

### Phase 4 — Verify & ship

12. `superpowers:verification-before-completion` — full suite, end-to-end.
13. `/qa` (gstack) — real-browser QA if there is any UI. Use `/qa-only` first for a report, then fix, then `/qa` for verification.
14. `/review` (gstack) — pre-landing Claude-side review.
15. `/codex` (gstack) in review mode — independent non-Claude second opinion. **Non-skippable.**
16. `/ship` (gstack) → `/land-and-deploy` → `/canary` (gstack) for production-visible changes.

## Decision gates

- **End of phase 1:** If the plan fits in a single subsystem with clear bounds and no UI/product/DX stakes, de-escalate to `toolbox-feature`.
- **End of phase 2:** Minimum bar to leave review = `/plan-eng-review` + `/autoplan` completed. Skipping CEO/design/devex is a judgment call; state the reason to the user.
- **During phase 3:** Prefer `subagent-driven-development` when tasks are truly independent; fall back to `executing-plans` when shared state or ordering matters.

## Non-skippable

- Written plan reviewed by at least `/plan-eng-review`.
- Worktree isolation.
- TDD per task.
- `/review` + `/codex` before shipping.

Shortcutting any of these means you are doing `toolbox-feature`, not `toolbox-complex`. Re-classify honestly via `toolbox`.

## Escalation the other direction

This is the top of the ladder. If a task exceeds even this — e.g., a new product line, a migration spanning multiple services — break it into multiple complex tasks and run the router on each.
