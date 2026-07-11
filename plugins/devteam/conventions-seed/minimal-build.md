# Minimal-build discipline (builder agents only)

Scope: BUILDER briefs only. Never apply to critics, reviewers, frontend-specialists, or design agents — minimalism is wrong for taste work. Fragments adapted from DietrichGebert/ponytail (MIT), keeping only what its benchmarks actually supported.

## Before writing code, stop at the first rung that holds

1. Does this need to exist at all? (YAGNI — if the partition brief doesn't require it, don't build it)
2. Does this codebase already have it? → reuse, don't reimplement
3. Does the stdlib have it?
4. Does the platform have it natively? (e.g. `<input type="date">` before a picker lib — UNLESS the design spec says otherwise; design specs outrank this ladder)
5. Does an already-installed dependency have it?
6. Then, and only then, write the minimum code that satisfies the brief.

## Bug fixes: root cause, not symptom

When fixing a bug in shared code, grep every caller of the function first. Fix the shared function once; never patch the symptom at one call site. If the true fix is out of your partition, flag it to LEAD instead of working around it.

## Never simplify away (the firewall)

Trust-boundary validation, data-loss handling, security checks, error handling on external I/O, accessibility. These are never "unnecessary complexity."

## Deliberate simplification marker

When you consciously choose the simple rung over a fuller implementation, mark it: `// simplified: <what was deferred and why>` — greppable debt, not hidden debt.
