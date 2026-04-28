# LEAD Dispatch Recipes

Per-tier phase subsets and brief composition rules.

## Tier: simple
**Phases:** BUILD (lite) + TEST (verify only).
- Skip plan partitioning — single BUILDER.
- BUILDER brief: "Make the change. Read the file and direct dependencies. One-line test if applicable."
- TESTER brief: "Run existing suite, report pass/fail."
- No REVIEW, no REFLECT.

## Tier: bug
**Phases:** THINK (lite) + BUILD + TEST + REVIEW.
- THINK lite: "Frame the bug. Symptom? Suspected root cause? Minimal repro?"
- BUILDER: write a failing test capturing the bug FIRST (red), then fix until green.
- REVIEW: focus on root cause vs symptom.
- REFLECT: focused — root cause + prevention.

## Tier: feature
**Phases:** THINK + PLAN + BUILD + REVIEW + TEST + SHIP.
- Full PLAN with wave-grouped partitions in `state/plan-partitions.md`.
- BUILD fans out per wave when partitions are `parallel_safe: true`.
- REVIEW: lens list from `bin/devteam-pick-lenses.sh`; one `review-specialist` worker per lens, dispatched in parallel.
- TEST: layer list from `bin/devteam-detect-stack.sh --tests`; one `tester` per layer, dispatched in parallel.
- SHIP: standard project-type detection.
- REFLECT: light (3 bullets).

## Tier: complex
**Phases:** All 7 with full retro.
- THINK may use shotgun mode (3× explorer) and read `DESIGN.md` if present.
- PLAN includes parallel critique fan-out via gstack /plan-*-review (or self-fanout in autonomous).
- BUILD fans out per partition wave.
- REVIEW: maximize lens coverage; include `/codex` consult if gstack installed.
- TEST: every detected layer.
- SHIP: full sequence; chain `gstack:/document-release` after merge.
- REFLECT: full retro; include WATCHLIST analyzer output.

## Brief composition (every dispatch)

LEAD includes in every worker brief:

1. Role + current phase + tier.
2. Absolute plugin install path (read `.devteam/state/.plugin-path`; expand `${CLAUDE_PLUGIN_ROOT}` at brief time).
3. `bin/slack-append.sh` command template, with the worker's actor tag (`[BUILDER:fe#]` etc.).
4. Input artifacts (file paths to read).
5. Output contract (which files to write, which slack severity tags to log under).
6. Question-packet schema reminder (`docs/question-packet-schema.json` + `docs/question-packet.md`).
7. Funnel rule reminder: "Don't call AskUserQuestion. Return a `blocked` packet with options + your recommendation."

## Per-actor counter management

Each actor maintains its own counter via `bin/slack-append.sh`'s automatic substitution: pass `[ACTOR#]` as a placeholder; the script writes `[ACTOR#NN]` with the next per-actor counter value. LEAD does not centrally allocate. Counter files live at `.devteam/state/.counters/<actor>`.

Naming convention for fan-out workers: `BUILDER:<partition-id>` (e.g., `BUILDER:fe`, `BUILDER:api`), `REVIEW:<lens>` (e.g., `REVIEW:security`), `TESTER:<layer>` (e.g., `TESTER:vitest`). Each gets its own counter.
