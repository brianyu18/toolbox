# Changelog

## 1.0.0 — TBD-2026-04-XX — Multi-agent team redesign (rename: toolbox → devteam)

### Major
- **Plugin renamed**: `toolbox` → `devteam`. Clean break (parallel install). Old `toolbox` should be uninstalled before installing devteam.
- **LEAD orchestrator skill** — single user-facing persona. LEAD dispatches workers in parallel via the Task tool directly (no lead-agent middleware; per A1-final, lead-agents removed as vestigial once they couldn't dispatch nested subagents).
- **5 dialogue skills**: LEAD, THINKER, PLANNER (with `/autoplan` delegation in work-together mode and DESIGN.md-aware planning), SHIPPER (chains `/document-release`), REFLECTOR (tier-gated retros + watchlist integration).
- **7 worker agents**: BUILDER, review-specialist (with 6 lens spec files: security, perf, testing, a11y, data-migration, api-contract), TESTER, plus 4 utility agents (EXPLORER, CRITIC, SYNTHESIZER, INVESTIGATOR).
- **Two invocation modes**: `/lead` orchestrated + 7 direct specialist commands (`/think`, `/plan`, `/build`, `/review-project`, `/test`, `/ship-project`, `/reflect`).
- **Two autonomy modes**: Work-Together (default) and Autonomous (halts cleanly with notification on hard-blocked questions).
- **Team Slack** — append-only chronological audit log per project. Race-safe via mkdir-mutex with stale-lock detection (POSIX-portable, no flock dependency). Per-actor counters for collision-free IDs.
- **Wave-grouped partitions** — PLANNER produces `plan-partitions.md` with `dependencies: []` and `parallel_safe: true|false`. LEAD reads waves and dispatches BUILDERs in parallel per wave (per A1-final).
- **REVIEW lens selection** — `bin/devteam-pick-lenses.sh` runs deterministic regex over `git diff --name-only` to return applicable lenses (security, perf, testing, a11y, data-migration, api-contract).
- **TEST layer detection** — `bin/devteam-detect-stack.sh --tests` returns test layer names per project.
- **Watchlist mechanism** — `bin/devteam-watchlist.sh` analyzes slack for mechanical signals (`3a-malformed-output`, `3a-tier-flag-override`, `3b-manual-log`); thresholds in `WATCHLIST.md`. Replaces immediate eval/telemetry implementation; tells the user when deferred features become worth implementing.
- **Per-project state** at `.devteam/state/`, **global memory** at `~/.claude/devteam/memory/`, **conventions library** at `~/.claude/devteam/conventions/` (8 stacks seeded: Pine Script, React, Tailwind, Next.js App Router, Node, Supabase, Postgres, Claude Code plugin authoring).
- **SessionStart hook** (opt-in via `/lead-setup`) shows project status when entering a repo with active state.
- **Question-packet contract** with 3 states: `complete | blocked | failed`. Retry-once-then-escalate on failure.

### Backward compatibility
- `/toolbox*` commands preserved as deprecated routers (will be removed in 2.0.0). Five wrappers route to `/lead` with `--tier <name>`.

### Requirements
- superpowers (>= 5.0.0)
- gstack (recommended; optional)
- macOS / Linux / WSL

### Hard rules
- Destructive actions always confirm, both modes.
- Twice-failed specialist always escalates, both modes.

## 0.1.0 — 2026-04-XX — Initial release (as `toolbox`)

- 5-skill workflow router: `toolbox` + `toolbox-{simple,bug,feature,complex}` playbooks.
