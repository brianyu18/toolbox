# devteam — Multi-Agent Dev Team Design

**Status:** spec, awaiting user approval
**Date:** 2026-04-26
**Author:** Brian Yu (with Claude)
**Renames:** plugin `toolbox` (0.1.0) → `devteam` (1.0.0)
**Repo:** `brianyu18/devteam` (renamed from `brianyu18/toolbox`)
**Source:** `~/Desktop/claude-projects/devteam/` (renamed from `…/toolbox/`)

---

## 1. Problem & goals

### Today (toolbox 0.1.0)

Five workflow-router skills (`toolbox`, `toolbox-simple`, `toolbox-bug`, `toolbox-feature`, `toolbox-complex`) that classify a task by size and prescribe a checklist of gstack/superpowers skills to invoke sequentially in the main thread. No subagents, no persistent roles, no audit log, no parallelism, no team metaphor. The user manually drives every transition.

### Goal

A persistent virtual dev team. The user talks only to the **LEAD**, who orchestrates a roster of named specialist subagents (one per sprint phase: THINK / PLAN / BUILD / REVIEW / TEST / SHIP / REFLECT) plus utility agents (EXPLORER / CRITIC / SYNTHESIZER / INVESTIGATOR). Specialists work in fresh contexts, fan out in parallel where possible, hand off via structured artifacts, and log everything to a chronological "team slack." Two autonomy modes (Work-Together, Autonomous) and two invocation modes (LEAD, direct) accommodate both supervision and headless operation.

### Success criteria

1. User invokes `/lead "task"` and receives a final report — LEAD has classified, dispatched, funneled questions with recommendations, written artifacts, logged to slack.
2. User can invoke any specialist directly (`/think`, `/plan`, etc.) for ad-hoc use without booting the whole team.
3. Every decision and outcome appears in `.devteam/state/slack.md` as a one-line entry with timestamp, ID, actor, severity, summary.
4. Autonomous mode runs end-to-end without user input on a well-scoped task; halts cleanly with notification on hard-blocked questions.
5. Backward compat: existing `/toolbox-feature` (etc.) commands continue to work, routed to LEAD.
6. Multi-agent fan-out actually happens: BUILD spawns parallel BUILDERs per partition; REVIEW spawns parallel review specialists.

### Anti-requirements (explicit non-goals for v1)

- Multiple in-flight projects per repo (one active project; future enhancement).
- Cross-session long-lived subagents (subagents are fresh-context per dispatch; persistence via artifacts).
- Windows-native support (macOS / Linux / WSL only).
- Auto-managed `.gitignore` edits in user repos (advisory only).
- Replacing gstack or superpowers (devteam orchestrates them, not duplicates them).

---

## 2. Architecture at a glance

```
You (user)
  ↓
LEAD (skill, main thread, the only persona you talk to in LEAD mode)
  ↓ dispatches
  ├── Skill specialists (loaded into LEAD's turn for user-dialogue phases)
  │     THINKER, PLANNER, SHIPPER, REFLECTOR
  │
  └── Agent specialists (Task-tool subagents, fresh context, parallel-capable)
        BUILD-LEAD → BUILDER ×N
        REVIEW-LEAD → SECURITY / PERF / TESTING / A11Y
        TEST-LEAD → TESTER ×N
        + Utility: EXPLORER, CRITIC, SYNTHESIZER, INVESTIGATOR
        (any skill can compose utility agents internally)

State backbone:
  .devteam/state/slack.md          — chronological team audit log
  .devteam/state/<phase>.md        — per-phase artifacts
  .devteam/mode                    — work-together | autonomous
  ~/.claude/devteam/memory/        — global "team-knows-you" memory
  ~/.claude/devteam/conventions/   — per-stack convention library
  ~/.claude/devteam/projects/      — archived completed projects
```

### The skill-vs-agent rule

> **A role lives as a skill if its core work involves dialogue with you. It lives as an agent if its core work is heads-down or parallelizable.**

Skills can dispatch agents (e.g., THINKER skill dispatches `EXPLORER ×3` for shotgun mode); the skill keeps the user-facing arc, the agent does the work that doesn't need user interaction.

### The funnel

In LEAD mode, **specialists never call AskUserQuestion directly.** Question packets return to LEAD; LEAD presents to user with options, specialist's recommendation, AND LEAD's own recommendation. User answers; LEAD re-dispatches. This rule does not apply in direct mode.

---

## 3. Roster

### Skills (5)

| Role | Path | Owns | Wraps |
|---|---|---|---|
| LEAD | `skills/lead/SKILL.md` | Classification, dispatch, funnel, autonomy, reporting | (orchestrator) |
| THINKER | `skills/thinker/SKILL.md` | THINK phase | `superpowers:brainstorming` |
| PLANNER | `skills/planner/SKILL.md` | PLAN phase + critique fan-out | `superpowers:writing-plans` + `gstack:/plan-{eng,ceo,design,devex}-review` |
| SHIPPER | `skills/shipper/SKILL.md` | SHIP phase | `gstack:/ship` → `/land-and-deploy` → `/canary` (project-type aware) |
| REFLECTOR | `skills/reflector/SKILL.md` | REFLECT phase | `gstack:/retro` |

### Agents — phase (9)

| Agent | Path | Tools | Behavior |
|---|---|---|---|
| BUILD-LEAD | `agents/build-lead.md` | Read, Grep, Glob, Bash, Edit, Task | Splits BUILD into partitions; dispatches BUILDERs parallel; merges |
| BUILDER | `agents/builder.md` | Read, Grep, Glob, Bash, Edit, Write | Implements one partition with TDD |
| REVIEW-LEAD | `agents/review-lead.md` | Read, Grep, Glob, Bash, Edit, Task | Selects + dispatches review specialists; merges JSON findings |
| SECURITY-REVIEWER | `agents/review-security.md` | Read, Grep, Glob | Auth, XSS, SQLi, secrets, OWASP |
| PERF-REVIEWER | `agents/review-perf.md` | Read, Grep, Glob | Query patterns, render perf, bundle size, hot paths |
| TESTING-REVIEWER | `agents/review-testing.md` | Read, Grep, Glob | Coverage gaps, flaky patterns, missing edge cases |
| A11Y-REVIEWER | `agents/review-a11y.md` | Read, Grep, Glob | Keyboard, screen reader, contrast, semantic HTML |
| TEST-LEAD | `agents/test-lead.md` | Read, Grep, Glob, Bash, Edit, Task | Dispatches TESTERs per layer; merges |
| TESTER | `agents/tester.md` | Read, Bash | Runs one test layer; emits results JSON |

### Agents — utility (4)

| Agent | Path | Tools | Mode |
|---|---|---|---|
| EXPLORER | `agents/explorer.md` | Read, Grep, Glob, WebSearch | Divergent generation: "produce N framings/options" |
| CRITIC | `agents/critic.md` | Read, Grep, Glob | Adversarial critique: "find flaws in this draft" |
| SYNTHESIZER | `agents/synthesizer.md` | Read | Merge: "given N inputs, produce one coherent output" |
| INVESTIGATOR | `agents/investigator.md` | Read, Grep, Glob, Bash | Read-only research: "find usage / explain code" |

Review specialists are **read-only by intent** — they report; fixes happen in the next BUILD pass.

---

## 4. LEAD behavior

### Lifecycle (per task)

1. Read `.devteam/mode`, `.devteam/state/`, `~/.claude/devteam/memory/`.
2. Run dependency check (`installed_plugins.json`): superpowers required, gstack soft-required.
3. If `state/` non-empty, offer resume vs fresh.
4. **Classify** task via internal templates (simple / bug / feature / complex). Use `EXPLORER ×2` if borderline.
5. Pick phase subset for the tier:
   - simple → BUILD + TEST(verify)
   - bug → THINK(lite) + BUILD + TEST + REVIEW
   - feature → THINK + PLAN + BUILD + REVIEW + TEST + SHIP
   - complex → all 7 (THINK + PLAN + BUILD + REVIEW + TEST + SHIP + REFLECT)
6. Loop per phase: compose brief → dispatch → receive packet → handle (complete | blocked | failed) → write artifacts → phase boundary check (work-together) or proceed (autonomous).
7. Final report; archive `state/` to `~/.claude/devteam/projects/<slug>-<date>.md` on user confirm; clear `state/`.

### Question-packet contract

Every specialist returns one of three states:

```json
{ "status": "complete" | "blocked" | "failed",
  "phase": "PLAN",
  "summary": "...",
  "artifacts": ["..."],

  // status=blocked only:
  "question": "...",
  "options": [{"id":"A","label":"...","tradeoff":"..."}],
  "specialist_recommendation": "A",
  "reasoning": "...",
  "context_needed_to_resume": "...",

  // status=failed only:
  "failure_kind": "timeout|malformed_output|tool_error|agent_error",
  "details": "...",
  "partial_artifacts": ["..."]
}
```

LEAD actions per state:
- **complete** → write artifacts, advance.
- **blocked** → funnel to user with format below.
- **failed** → retry once; on second failure, escalate to user with diagnostics regardless of mode.

### Funnel format (always two recommendations)

```
🎩 [LEAD] PLANNER blocked on form library.

Question: Should the new settings page use react-hook-form or formik?

Options:
  A) react-hook-form — smaller bundle, modern API
  B) formik          — team familiarity, mature ecosystem

PLANNER recommends: A (bundle budget, RHF already in 2 forms)
LEAD recommends:     A (also: aligns with hooks-everywhere global memory)

Pick A / B / something else / "your call".
```

### Autonomy modes

| Decision point | Work-Together (default) | Autonomous |
|---|---|---|
| Classification | Confirm with user | Decide silently, mention in opening |
| Phase boundary | Check in before next | Proceed silently |
| Specialist blocked | Always funnel | Pre-flight w/ CRITIC + EXPLORER; if still ambiguous, halt cleanly + notify |
| Borderline / risky | Funnel with options | CRITIC pre-flight; proceed if clean, funnel if not |
| Destructive action | Always confirm | **Always confirm** (hard rule) |
| Final report | Detailed sections | Concise + artifact pointers |

Mode persisted in `.devteam/mode`. Mid-flight switch happens at next safe point (between dispatches), logged to slack as `MODE` entry.

### Stranded-block in autonomous mode

When LEAD cannot confidently answer a hard-blocked specialist question after pre-flight:
1. Detailed `WAITING ON USER` slack entry (full question packet, LEAD's pre-flight reasoning, utility agent outputs)
2. Detail file at `.devteam/state/slack-detail/<id>.md`
3. **PushNotification fires** (on by default in autonomous; opt-out via `--no-notify`)
4. Run exits cleanly
5. Next user invocation surfaces the pending block prominently

### LEAD's internal use of utility agents (invisible to user)

| Trigger | LEAD action |
|---|---|
| Borderline classification | `EXPLORER ×2` (argue both tiers) |
| Pre-classification context gap | `INVESTIGATOR ×1` |
| Pre-destructive-action | `CRITIC ×1` |
| Many specialist outputs to merge | `SYNTHESIZER ×1` |
| Low-confidence answer | `EXPLORER ×2-3` (alternative framings) |

User sees LEAD's recommendations sharpen; doesn't see the deliberation by default. `/lead-show-work` (or natural-language "show your work") expands on demand.

---

## 5. Artifact contracts & state

### Per-repo: `.devteam/`

```
.devteam/
├── mode                         # work-together | autonomous
├── slack.lock.d/                # mkdir-mutex (POSIX-portable)
└── state/
    ├── slack.md                 # team audit log
    ├── slack-detail/            # optional per-entry deep records
    │   └── 26-04-26-10-32-30-001.md
    ├── archive/                 # rotated slack at 2000 lines / 200 KB
    │   └── slack-2026-04-26.md
    ├── .project-name            # LEAD-managed
    ├── .last-phase              # LEAD updates after each phase
    ├── .plugin-path             # absolute install path (for subagent briefs)
    ├── .started-in              # "lead" | "direct"
    ├── think.md
    ├── plan.md
    ├── plan-partitions.md
    ├── plan-critiques/{eng,ceo,design,devex}.md
    ├── build-progress.md
    ├── build-status.json
    ├── review-findings.json
    ├── test-results.json
    ├── ship-log.md
    ├── project-type.md          # web|plugin|library|cli|static (SHIPPER detection)
    └── reflect.md
```

`.devteam/` should be in user's project `.gitignore` (advisory in README, not auto-edited).

### Global: `~/.claude/devteam/`

```
~/.claude/devteam/
├── memory/
│   ├── MEMORY.md                # index
│   └── ...                      # one file per topic (mirrors existing auto-memory format)
├── conventions/                 # seeded from plugin's conventions-seed/ on /lead-setup
│   ├── index.json               # detection signals → convention files
│   ├── README.md
│   ├── languages/pinescript.md
│   ├── frontend/{react,tailwind}.md
│   ├── backend/node.md
│   └── db/postgres.md
└── projects/
    └── <slug>-<date>.md         # archived completed projects (slack rolls here)
```

### Per-phase contracts

| Phase | Inputs | Outputs | Handover summary |
|---|---|---|---|
| THINK | user task, global memory, git log | `state/think.md` | 2-3 line slack DONE |
| PLAN | think.md, memory, conventions | `state/plan.md`, `state/plan-partitions.md`, `state/plan-critiques/*.md` | partition count + critical-path |
| BUILD | plan.md, partitions, code, conventions | code (committed), `state/build-progress.md`, `state/build-status.json` | per-partition status + blockers |
| REVIEW | code diff, plan.md | `state/review-findings.json` | counts by severity |
| TEST | code, suites | `state/test-results.json` | overall pass/fail + blocker tests |
| SHIP | passing code, version, changelog | `state/ship-log.md`, updated `VERSION`/`CHANGELOG.md`, tag, PR | deploy URL + canary status |
| REFLECT | slack.md, all artifacts, git log | `state/reflect.md`, appends to `~/.claude/devteam/memory/` | lesson count |

### Slack entry format

```
#YY-MM-DD-HH-MM-SS  YYYY-MM-DD HH:MM:SS  [ACTOR#NN]  SEVERITY  one-line description
                                                                  → detail: slack-detail/<id>.md (optional)
```

Severity tags: `INFO | DECISION | QUESTION | ANSWER | FUNNEL | BLOCKER | DESTRUCTIVE | DONE | ERROR | MODE | SUMMARY`.

Per-actor counter avoids ID collisions without millisecond precision (BSD `date` doesn't support `%3N`).

### Concurrency

| Resource | Writer model | Safety |
|---|---|---|
| `slack.md` | All actors append | `mkdir`-mutex via `bin/slack-append.sh` (POSIX-portable; no `flock` dependency) |
| `slack-detail/<id>.md` | Whoever creates the entry | Unique ID, no contention |
| `state/<phase>.md` | One specialist per phase | No contention |
| `build-status.json` | BUILD-LEAD only (after merge) | Single writer |
| Code files | BUILDERs (one per partition) | Partition-enforced ownership; BUILD-LEAD verifies non-overlapping |

**Hard rule:** no two specialists ever own the same file at the same time. PLAN's partition discipline enforces this.

### REFLECT tier-gating

| Tier | REFLECT |
|---|---|
| simple | skip |
| bug | run, focused on root cause + prevention |
| feature | run, light retro (3 bullets) |
| complex | full retro |

---

## 6. Invocation surface

### Top-level commands (19 total, including 5 backward-compat aliases)

| Command | Routes to |
|---|---|
| `/lead [task]` | LEAD skill, full team |
| `/lead-status` | LEAD status read-only |
| `/lead-mode <name> [--notify\|--no-notify]` | toggle mode |
| `/lead-abort` | clean exit, preserve state |
| `/lead-resume` | continue from pause / WAITING ON USER |
| `/lead-show-slack [phase] [--decisions]` | slack read |
| `/lead-setup` | install SessionStart hook + seed conventions |
| `/think [task]` | direct THINKER |
| `/plan [task]` | direct PLANNER |
| `/build [task]` | direct BUILD; `--parallel` to fan-out |
| `/review-project [path]` | direct REVIEW (renamed to avoid gstack `/review` collision) |
| `/test [layer]` | direct TEST |
| `/ship-project` | direct SHIP (renamed to avoid gstack `/ship` collision) |
| `/reflect` | direct REFLECT |
| `/toolbox`, `/toolbox-{simple,bug,feature,complex}` | backward-compat → LEAD with `--tier` flag |

### LEAD-recognized natural language (not separate commands)

Reduce slash-menu clutter; recognized inside LEAD's body when user types these phrases:
- "pause" / "resume"
- "tier <name>"
- "notify on" / "notify off"
- "show your work"
- "show entry #<id>"
- "project name <slug>" / "project archive" / "project clear"

### Flags

| Flag | Effect |
|---|---|
| `--tier <name>` | Force classification (simple\|bug\|feature\|complex) |
| `--mode <name>` | Set mode for this run only |
| `--notify` / `--no-notify` | Notification override |
| `--parallel` | Force fan-out for direct `/build`, `/review-project`, `/test` |
| `--no-state` | Ephemeral run; no slack/state writes (direct-mode only; rejected on `/lead`) |
| `--from <phase>` | Resume from a specific phase, validates prerequisites |
| `--dry-run` | Plan dispatches but don't execute; print intent |

### Notifications

| Trigger | Default | Override |
|---|---|---|
| Autonomous mode + WAITING ON USER block | ON | `/lead notify off` or `--no-notify` |
| Project complete | ON in autonomous, off in work-together | `/lead notify on completions` |
| Critical failure (twice-failed specialist) | ON in both modes | Cannot disable |

### Direct mode

| Behavior | Detail |
|---|---|
| Writes to slack? | YES, with `started_in: direct` marker |
| Writes to state? | YES |
| LEAD sees it next invocation? | YES — sees marker, offers continue or fresh |
| Funnel rule applies? | NO — specialist talks to user directly |
| `--no-state` flag? | Ephemeral; no writes |

---

## 7. Hooks, settings, plugin manifest

### `plugin.json`

```json
{
  "name": "devteam",
  "version": "1.0.0",
  "description": "Multi-agent dev team in a box. LEAD orchestrates THINK / PLAN / BUILD / REVIEW / TEST / SHIP / REFLECT phases via specialist subagents with parallel fan-out, structured handoffs, and a team slack audit log.",
  "author": { "name": "Brian Yu" },
  "repository": "https://github.com/brianyu18/devteam",
  "license": "MIT",
  "keywords": ["agent-team", "lead", "orchestration", "subagents", "workflow", "superpowers", "gstack", "multi-agent"],
  "requires": {
    "plugins": [
      { "name": "superpowers", "marketplace": "claude-plugins-official", "min_version": "5.0.0" },
      { "name": "gstack", "marketplace": "any", "optional": false }
    ]
  }
}
```

The `requires` field is forward-compatible self-documentation; load-bearing dep check is LEAD's runtime read of `installed_plugins.json`.

### SessionStart hook (opt-in via `/lead-setup`)

`hooks/session-start.sh`:

```sh
#!/bin/sh
set -eu
STATE_DIR="${PWD}/.devteam/state"
[ -d "$STATE_DIR" ] || exit 0

PROJECT="$(cat "$STATE_DIR/.project-name" 2>/dev/null || echo "unnamed")"
LAST_PHASE="$(cat "$STATE_DIR/.last-phase" 2>/dev/null || echo "?")"
MODE="$(cat "${PWD}/.devteam/mode" 2>/dev/null || echo "work-together")"

cat <<EOF
[devteam] Active project: $PROJECT (mode: $MODE, last phase: $LAST_PHASE)
[devteam] Run /lead-status to inspect, /lead to resume, /lead-abort to stop.
EOF
```

Silent in repos without `.devteam/state/`. Registered in `~/.claude/settings.json` only when user runs `/lead-setup`.

### `bin/slack-append.sh` (race-safe, portable)

```sh
#!/bin/sh
# bin/slack-append.sh "<entry-line>"
set -eu

STATE_DIR="${DEVTEAM_STATE_DIR:-${PWD}/.devteam/state}"
LOCKDIR="${PWD}/.devteam/slack.lock.d"
SLACK="$STATE_DIR/slack.md"

mkdir -p "$STATE_DIR"
touch "$SLACK"

# Atomic mkdir-mutex (POSIX-portable; no flock dependency)
while ! mkdir "$LOCKDIR" 2>/dev/null; do sleep 0.05; done
trap 'rmdir "$LOCKDIR"' EXIT

TS=$(date -u +"%Y-%m-%d %H:%M:%S")
ID=$(date -u +"%y-%m-%d-%H-%M-%S")

# Per-actor counter is supplied in the caller's entry-line as [ACTOR#NN]
printf "#%s  %s  %s\n" "$ID" "$TS" "$1" >> "$SLACK"
```

Subagent briefs include the absolute path resolved from `.devteam/state/.plugin-path`:
> *To log: `bash <plugin-path>/bin/slack-append.sh '[BUILDER:fe#01] DECISION  Picked react-hook-form'`*

### Settings / permissions (documented in README)

```json
{
  "permissions": {
    "allow": [
      "Bash(bash *plugins/devteam/bin/slack-append.sh:*)",
      "Bash(bash *plugins/devteam/hooks/session-start.sh)",
      "Read(./.devteam/**)",
      "Write(./.devteam/**)",
      "Edit(./.devteam/**)"
    ]
  }
}
```

Optional convenience: ship `/lead-setup-permissions` helper command (deferred).

### `.gitignore` advisory

README documents:
```
# Recommended
.devteam/
```
Devteam does not auto-edit user `.gitignore`.

---

## 8. File structure

```
plugins/devteam/                       (was plugins/toolbox/)
├── .claude-plugin/plugin.json
├── README.md
├── CHANGELOG.md
├── bin/
│   └── slack-append.sh
├── hooks/
│   ├── hooks.json.example
│   └── session-start.sh
├── conventions-seed/                  (bundled; copied to ~/.claude/devteam/conventions/ on /lead-setup)
│   ├── index.json
│   ├── README.md
│   ├── languages/pinescript.md
│   ├── frontend/{react,tailwind}.md
│   ├── backend/node.md
│   └── db/postgres.md
├── commands/                          (19 files: 7 ceo-* + 7 specialists + 5 backward-compat)
│   ├── ceo.md
│   ├── ceo-status.md
│   ├── ceo-mode.md
│   ├── ceo-abort.md
│   ├── ceo-resume.md
│   ├── ceo-show-slack.md
│   ├── ceo-setup.md
│   ├── think.md
│   ├── plan.md
│   ├── build.md
│   ├── review-project.md
│   ├── test.md
│   ├── ship-project.md
│   ├── reflect.md
│   ├── toolbox.md, toolbox-simple.md, toolbox-bug.md, toolbox-feature.md, toolbox-complex.md
├── skills/                            (5 active + 5 deprecated routers)
│   ├── ceo/SKILL.md
│   ├── thinker/SKILL.md
│   ├── planner/SKILL.md
│   ├── shipper/SKILL.md
│   ├── reflector/SKILL.md
│   └── toolbox/, toolbox-simple/, toolbox-bug/, toolbox-feature/, toolbox-complex/SKILL.md
└── agents/                            (13 files)
    ├── build-lead.md, builder.md
    ├── review-lead.md
    ├── review-security.md, review-perf.md, review-testing.md, review-a11y.md
    ├── test-lead.md, tester.md
    ├── explorer.md, critic.md, synthesizer.md, investigator.md
```

Total: ~55 files in plugin (1 manifest + 3 docs + 1 bin + 2 hooks + 7 conventions-seed + 19 commands + 10 skills + 13 agents).

---

## 9. Migration & rollout

### Implementation stages

| Stage | Deliverable | Smoke test |
|---|---|---|
| 0 | Worktree (per toolbox-complex Phase 3) | `git worktree list` shows isolated branch |
| 1 | Foundation: `slack-append.sh`, plugin.json bump, repo rename | `bash bin/slack-append.sh "[TEST] INFO test"` writes proper line; concurrent appends safe |
| 2 | LEAD + state primitives (`skills/lead/`, `.devteam/` layout, dotfiles) | `/lead` reads state correctly; dependency check fires |
| 3 | Skill specialists (thinker, planner, shipper, reflector) | Each skill loadable; writes its phase artifact standalone |
| 4 | Phase agents (build-lead, builder, review-*, test-lead, tester) | BUILD-LEAD parallel-dispatches BUILDERs; REVIEW-LEAD merges JSON |
| 5 | Utility agents (explorer, critic, synthesizer, investigator) | Each returns expected shape |
| 6 | Commands (19 + 5 wrappers) | Each command resolves; backward-compat reaches LEAD with `--tier` |
| 7 | Hooks + setup (`session-start.sh`, `/lead-setup`) | `/lead-setup` registers hook; fresh session shows project notice |
| 8 | Conventions library (seed copy on `/lead-setup`) | LEAD auto-detects stack, BUILDER brief includes correct paths |
| 9 | Docs (README rewrite, CHANGELOG 1.0.0) | README walks new user from install to first ship |
| 10 | Validation (manual matrix below) | All 14 tests pass |

### Backward compat

- Plugin name change is a clean break (parallel install, not upgrade).
- README directs: uninstall old `toolbox` plugin first.
- Devteam ships `/toolbox*` command + skill aliases as deprecated routers to LEAD with appropriate `--tier` flag.
- Aliases marked for removal in 2.0.0 (timeline deferred).

### Migration steps for users on toolbox 0.1.0

```
1. /plugin uninstall toolbox
2. /plugin marketplace remove toolbox  (if added)
3. /plugin marketplace add brianyu18/devteam
4. /plugin install devteam@devteam
5. /lead-setup                          # registers SessionStart hook + seeds conventions
6. (optional) Existing /toolbox-feature etc. still work as deprecated aliases
```

### Conventions library seeding

`/lead-setup` does:
1. Register SessionStart hook in `~/.claude/settings.json`
2. If `~/.claude/devteam/conventions/` doesn't exist: copy from `plugins/devteam/conventions-seed/` to `~/.claude/devteam/conventions/`
3. Idempotent — won't overwrite user customizations

LEAD falls back to auto-seed on first run if `/lead-setup` was skipped.

### CHANGELOG 1.0.0 seed

(Date placeholder; replace with actual release date when shipping.)

```markdown
## 1.0.0 — <release-date> — Multi-agent team redesign (rename: toolbox → devteam)

### Major
- Plugin renamed: toolbox → devteam (clean break, parallel install)
- New LEAD orchestrator skill — single user-facing persona dispatching specialists
- 7 phase specialists with parallel fan-out workers
- 4 utility agents composable from any skill
- Two invocation modes (LEAD / direct) and two autonomy modes (Work-Together / Autonomous)
- Team Slack audit log per project
- Per-project state + global memory + conventions library

### Backward compatibility
- `/toolbox*` commands and skills preserved as deprecated routers in devteam plugin
- Migration path documented in README

### Requirements
- superpowers (>= 5.0.0)
- gstack (any recent version)
- macOS / Linux / WSL
```

### README TOC (delivered as part of Stage 9)

```
1.  What is devteam?
2.  Architecture at a glance
3.  Quick start
4.  Two ways to invoke (LEAD / direct)
5.  The team
6.  The 7 phases
7.  Modes (Work-Together / Autonomous)
8.  Team Slack
9.  State, memory, conventions
10. Command reference
11. Customizing
12. Requirements
13. Migration from toolbox 0.1.0
14. Roadmap
15. Contributing
16. License
```

### Validation matrix

| ID | Scenario | Expected |
|---|---|---|
| T01 | `/lead "fix typo in README"` | Classified `simple`; BUILD only; one slack section; final report |
| T02 | `/lead "auth middleware throws on expired tokens"` | Classified `bug`; THINK lite + BUILD + TEST + REVIEW; root cause documented |
| T03 | `/lead "add dark mode toggle"` | Classified `feature`; full feature pipeline through SHIP |
| T04 | `/lead "rebuild the settings system"` | Classified `complex`; all 7 phases; BUILD fan-out |
| T05 | `/lead --mode autonomous "add settings page"` | Runs autonomously; pre-flights; final report at end |
| T06 | T05 with intentional ambiguity | LEAD halts on hard-blocked Q; sends notification; resumes via `/lead-resume` |
| T07 | `/think "explore caching"` then `/lead` | Direct mode writes state with `started_in: direct`; LEAD offers continue |
| T08 | Force a BUILDER failure | LEAD retries once, escalates with diagnostics |
| T09 | Mid-flight `/lead-mode autonomous` | Switches at next safe point; logged in slack |
| T10 | Multi-session resume | Close → reopen → SessionStart shows project notice → `/lead` resumes |
| T11 | gstack uninstalled | LEAD warns; degraded REVIEW (no /codex), degraded SHIP (no /canary) |
| T12 | Slack hits 2000 lines | Auto-archives older phases; in-progress preserved |
| T13 | `/build "add a new pinescript indicator"` | Direct mode; conventions lib auto-loads `languages/pinescript.md` |
| T14 | Each direct specialist (`/think`, `/plan`, `/build`, `/review-project`, `/test`, `/ship-project`, `/reflect`) standalone | Each writes appropriate state + slack, no LEAD orchestration |

### Acceptance criteria

1. All 11 stages pass smoke tests.
2. All 14 validation matrix tests pass.
3. README walks a fresh user from install to first ship without external help.
4. `CHANGELOG.md`, `plugin.json#version` align at 1.0.0.
5. Backward-compat: existing `/toolbox-feature` etc. invocations on devteam install produce equivalent outcomes.
6. `/lead-setup` is opt-in and idempotent.
7. `.devteam/` documented in README's `.gitignore` advisory.
8. At least 4 conventions seeded (Pine Script, React, Tailwind, Node, Postgres = 5 actually).

---

## 10. Locked-in design commitments (the contract)

1. LEAD funnel; specialists never call AskUserQuestion in LEAD mode.
2. Two invocation modes: `/lead` orchestrated + direct specialist commands.
3. Two autonomy modes: Work-Together (default) / Autonomous, toggleable, persisted in `.devteam/mode`.
4. C2 phase model — LEAD subsumes the router; 4 tier recipes (simple/bug/feature/complex) live as internal templates.
5. Persistence model — fresh dispatches + artifact-backed handover (NOT long-running subagents).
6. Parallel fan-out for BUILD, REVIEW, TEST (and optional THINK-shotgun) with leads/coordinators.
7. State location: `.devteam/state/` (per-repo) + `~/.claude/devteam/memory/` (global) + `~/.claude/devteam/conventions/` (library).
8. Roster shape: Hybrid — 5 skills, 9 phase agents, 4 utility agents = 18 component files.
9. Generalized agent dispatch — any skill role can compose utility agents (explorer, critic, synthesizer, investigator); LEAD uses them as internal cognition (invisible to user by default).
10. Team Slack — append-only chronological log, `#YY-MM-DD-HH-MM-SS` ID + per-actor counter, severity-tagged, phase-bracketed, rolling-archive at 2000 lines / 200 KB.
11. Migration: `/toolbox-{simple,bug,feature,complex}` become wrappers calling LEAD with `--tier <name>`. Zero breaking change for users (after parallel-install rename caveat).
12. Direct mode writes to slack/state with `"started_in: direct_mode"` marker.
13. Failure state added to question-packet contract: `complete | blocked | failed`. LEAD retries once on failure; escalates on second failure regardless of autonomy mode.
14. Autonomous + hard-blocked question: CRITIC + EXPLORER pre-flight; if still ambiguous, write detailed `WAITING ON USER` to slack + detail file + PushNotification (on by default), exit cleanly.
15. SHIPPER detects project type at SHIP phase start; stores in `state/project-type.md`. Playbook varies per type.
16. REFLECT tier-gating: simple = skip; bug = focused; feature = light; complex = full.
17. Command renames: `/ship` → `/ship-project`, `/review` → `/review-project` (avoid gstack collision).
18. Dependency check: declare in `plugin.json#requires` (forward-compat); LEAD runtime check via `installed_plugins.json`; README requires gstack + superpowers; graceful degradation per phase if missing.
19. Flat command names (Claude Code idiom): `/lead-status`, `/lead-mode`, etc., as separate command files.
20. Flag validation: `--from <phase>` checks prerequisites; `--no-state` rejected on `/lead`, allowed on direct specialists.
21. Slack lock = `mkdir`-mutex (POSIX-portable; no `flock` dependency).
22. Slack ID format = `#YY-MM-DD-HH-MM-SS` + per-actor counter `[ACTOR#NN]` (BSD `date` doesn't support `%3N`).
23. Per-agent tool allocation specified; review specialists are read-only by intent.
24. Plugin path resolution — LEAD writes absolute install path to `.devteam/state/.plugin-path` on startup; subagent briefs use it.
25. State dotfiles: `.project-name`, `.last-phase`, `.plugin-path`, `.started-in`.
26. `plugin.json#requires` kept as forward-compat documentation; runtime check is the load-bearing one.
27. Command count compression: 6 niche commands become LEAD-recognized natural-language phrases instead of separate files. Net 19 command files (down from 25), of which 5 are backward-compat aliases.
28. Stage-gated implementation — 11 sequenced stages (Stage 0 = worktree), each with smoke test before next.
29. Backward compat — old skills + commands preserved as deprecated routers; nothing deleted.
30. Conventions seed — Pine Script, React, Tailwind, Node, Postgres + README + index.json (5 stacks).
31. README rewrite — full TOC delivered as part of plan; written during Stage 9.
32. Validation = manual test matrix — 14 documented scenarios, re-runnable, used as acceptance gate.
33. Plugin rename: `toolbox` → `devteam` (1.0.0). All paths, env vars, marketplace identifiers updated.
34. Conventions seeding via `/lead-setup` (canonical install step); LEAD auto-fallback if dir missing.
35. README directs users to uninstall old `toolbox` plugin before installing `devteam`; backward-compat aliases preserved in devteam.
36. README adds Migration from toolbox 0.1.0 section with command equivalence table.
37. Stage 0 = create worktree before any code changes (per toolbox-complex Phase 3).
38. Validation matrix expansion: T13 (conventions auto-load via direct `/build`) + T14 (each direct specialist standalone smoke test).

---

## 11. Deferrables (revisit during plan-writing or implementation)

- Tool permissions per agent — final allocation done during impl (Stage 4–5).
- `conventions/index.json` maintenance: auto-generate from filesystem on LEAD start vs hand-curated.
- Internal templates (simple/bug/feature/complex playbooks) location — inline in LEAD skill body vs separate docs.
- Detail file cleanup policy — archive alongside slack rotations.
- Memory write format from REFLECTOR — match existing auto-memory format under `~/.claude/projects/-Users-brian/memory/`.
- PLAN critique mechanics — main-thread (clones context) vs fanned-out agents.
- Idempotent `/lead-abort` when nothing's running.
- `/lead show #<id>` lookup falling back to archived slack files.
- Default project slug when user doesn't set one (first 3 task words + date).
- Argument parsing rules (flags before task string vs anywhere).
- Pause + concurrent direct-specialist invocation behavior.
- `--mode <name>` flag scope (this run vs persistent) explicitness.
- `${CLAUDE_PLUGIN_ROOT}` expansion behavior in subagent briefs (verify during impl).
- `VERSION` file vs `plugin.json#version` — single source of truth.
- `bin/slack-append.sh` executable bit (chmod +x on install).
- CHANGELOG.md initial seed automation.
- `/lead-setup-permissions` helper command (convenience over README block).
- Hook edge cases (permissions, missing files).
- Auto-detecting first install vs upgrade for `/lead-setup`.
- Conventions cleanup on plugin uninstall (orphaned global state).
- Corrupted state recovery (LEAD detects malformed slack/state).
- Exact "abandon" / "clear state" semantics (delete vs archive).
- 2.0.0 alias removal timeline for `/toolbox*` backward-compat.

---

## 12. Open questions for plan phase

None blocking. All design forks resolved. Plan-writing should focus on:
- Per-agent prompt body content (rough cuts during Stage 4–5)
- Per-skill SKILL.md content (rough cuts during Stage 3)
- README content per TOC section (Stage 9)
- Convention file content per stack (Stage 8)

---

## 13. Out of scope for v1

- Multiple in-flight projects per repo
- Cross-session long-lived subagents
- Windows-native support (WSL is the workaround)
- Auto-managed `.gitignore` edits
- Replacing or vendoring gstack/superpowers (we orchestrate them)
- Web UI / dashboard for slack viewing (slack.md is the UI)
- Multi-user / team-account features
- Telemetry / metrics aggregation across projects
