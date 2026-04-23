---
name: brains
description: Use at the start of any non-trivial development task, feature request, bug report, or project/feature kickoff, before exploring code or making edits.
---

# brains — workflow router

Classify the incoming task, then invoke the matching sub-skill. Do this BEFORE exploring code, reading files, or editing anything.

## Classify

| Task shape | Route to |
|---|---|
| One-file edit, config tweak, doc change, rename, factual question | `brains-simple` |
| Unexpected behavior, test failure, error message, regression, "why is this broken" | `brains-bug` |
| New feature of medium scope in an existing product, clear subsystem | `brains-feature` |
| New subsystem, multi-file rewrite, user-visible product change, ambiguous or cross-cutting scope | `brains-complex` |

## Tiebreakers

- Ambiguous between two tiers: pick the higher one. Underscoping is worse than overscoping.
- User handed you a finished spec: skip brainstorming in the matched playbook, jump to planning or execution.
- Bug uncovered mid-feature: complete the bug route, then resume the feature route.
- Task says "quick" or "small" but touches >2 files or cross-cutting concerns: do NOT trust the framing, pick the higher tier.

## After classifying

1. State the classification and chosen sub-skill to the user in one sentence.
2. Invoke the sub-skill via the Skill tool.
3. Follow its playbook.

Do not skip to implementation. Each sub-skill adds discipline the naked task wouldn't. If the sub-skill feels like overhead for this task, you classified too high — re-run `brains`.
