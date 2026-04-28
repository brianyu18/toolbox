# Classification Signals (for LEAD's internal classifier)

## simple — signals
- Task language: "fix typo", "rename", "update doc", "small config change"
- Single file, no behavior change beyond stated, no new abstractions
- If task mentions multiple files: NOT simple, escalate

## bug — signals
- Task language: "broken", "fails", "errors", "regression", "throws"
- Stack trace / error message included
- "It used to work" / "after the last change..."

## feature — signals
- Task language: "add", "implement", "build a", "support X"
- Bounded scope: single subsystem
- User-visible or API-visible new capability

## complex — signals
- Task language: "rebuild", "redesign", "rewrite", "system", "from scratch"
- Touches multiple subsystems
- High ambiguity ("not sure how to approach")
- Significant design taste involved
- Cross-cutting concerns

## Tiebreakers
- Simple vs bug: any unexpected behavior → bug.
- Bug vs feature: was-designed-but-broken → bug; never-designed-this → feature.
- Feature vs complex: bounded + obvious design → feature; fuzzy or multiple legit approaches → complex.
- When in doubt: pick higher tier. Underscoping is worse than overscoping.

## Borderline → use EXPLORER

Dispatch in one Task message with two parallel briefs:

- Brief A: "Argue why this task is `<tier-A>`."
- Brief B: "Argue why this task is `<tier-B>`."

Read both, pick higher tier per tiebreakers above.

## User override

`--tier <name>` flag bypasses classification. Honor it; log a `DECISION` entry to slack noting the override (counts as a `3a-tier-flag-override` watchlist signal).
