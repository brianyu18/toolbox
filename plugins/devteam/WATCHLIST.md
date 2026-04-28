# devteam — WATCHLIST

Single source of truth for what to watch and at what threshold to act. Used by `bin/devteam-watchlist.sh`.

Each section maps a deferred feature (in TODOS.md) to one or more **mechanical** signals. When a signal exceeds its threshold in the trailing 14-day window, the analyzer surfaces an `ALERT` and the user (or system) decides whether to pull the deferred feature into a task.

---

## How a signal is logged

Agents and the user both write `WATCHLIST` lines into `.devteam/state/slack.md` via `bin/slack-append.sh`. Format:

```
[ACTOR#NN] WATCHLIST  signal=<id>  detail=<one-line context>
```

The analyzer (`bin/devteam-watchlist.sh`) groups by `signal=<id>`, counts entries within the trailing 14 days (across `slack.md` and `archive/*.md`), and compares against the thresholds below.

User-driven manual signals are recorded via:

```sh
bash "$CLAUDE_PLUGIN_ROOT/bin/devteam-watchlist-log.sh" "<one-line concern>"
```

---

## Feature 3a — Prompt regression eval suite

**Why deferred:** v1 prompts are still iterating. Building eval baselines now would lock in a moving target. Once prompts stabilize, evals catch silent regressions across model upgrades.

**Mechanical signals:**

| Signal ID | What it means | Threshold | Detector |
|---|---|---|---|
| `3a-malformed-output` | A specialist returned a `failed` packet with `failure_kind: malformed_output`. Indicates the prompt did not constrain output shape. | 3 in 14 days | LEAD logs this when parsing a returned packet and the schema check fails. |
| `3a-tier-flag-override` | User invoked LEAD with explicit `--tier <name>` flag, overriding LEAD's classification. | 5 in 14 days | LEAD logs this when parsing the invocation if `--tier` is present. |

**How to revisit:** Pull "Prompt regression eval suite (3a)" from TODOS.md Tier 1 into a real task. Pick 5–10 representative invocations, capture expected outputs, run them against current model + after each upgrade.

---

## Feature 3b — Usage telemetry

**Why deferred:** Telemetry instrumentation on changing code is wasted work. Once the code stops moving and there's a real question telemetry would answer, build it.

**Mechanical signals:**

| Signal ID | What it means | Threshold | Detector |
|---|---|---|---|
| `3b-manual-log` | User explicitly recorded a usage-related concern via `devteam-watchlist-log.sh`. | 2 in 14 days | User runs the helper script. |

**How to revisit:** Pull "Usage telemetry (3b)" from TODOS.md Tier 1 into a real task. Local-only JSONL at `~/.claude/devteam/telemetry/<date>.jsonl`. Capture: invocation timestamp, classification, mode, phases run, durations, retries, escalations. No network calls. No cross-project aggregation.

---

## Removed signals (intentionally NOT watched)

These were proposed during early design but require LLM judgment (unreliable) or fingerprinting (undefined):

- `3a-classification-override` — linguistic dissent detection. Too noisy.
- `3a-behavior-drift` — task-type fingerprinting. No stable definition.
- `3b-usage-question` — intent detection from user prompts. Too noisy.
- `3b-blind-iteration` — subjective retro signal. Not mechanically defined.

If a need emerges, prefer adding mechanical signals (file checks, exit codes, exact-string match) over LLM-judgment signals.
