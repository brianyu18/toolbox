# devteam 1.0.0 — Validation Matrix

18 scenario tests covering core flows, edge cases, and regression guards.

Architecture note: Tests reflect A1-final. There are no BUILD-LEAD, REVIEW-LEAD, or TEST-LEAD agents. LEAD dispatches workers directly via the Task tool.

---

## How to run

These are manually executed smoke tests against a real project directory. Each test describes the invocation, what to observe, and what constitutes a pass.

For automated smoke tests (bin scripts), run:

```bash
plugins/devteam/bin/test-slack-append.sh
plugins/devteam/bin/test-devteam-pick-lenses.sh
plugins/devteam/bin/test-devteam-detect-stack.sh
plugins/devteam/bin/test-devteam-watchlist.sh
plugins/devteam/bin/test-stage25-smoke.sh
```

---

## Tests

### T01 — Simple tier: single BUILD pass

**Scenario:** `/lead "fix typo in README"`

**Expected:**
- LEAD classifies tier as `simple` (no confirmation in autonomous; confirm prompt in work-together).
- Phase subset: BUILD + TEST (verify). THINK and PLAN are skipped.
- One slack section; entries for BUILD DONE and TEST DONE.
- Final report summarizes change.
- No `plan-partitions.md` written (simple tier skips PLAN).

**Pass criteria:** Final report delivered. `state/build-status.json` written. Slack contains fewer than 15 entries. No `state/think.md` or `state/plan.md` produced.

---

### T02 — Bug tier: THINK lite + BUILD + TEST + REVIEW

**Scenario:** `/lead "auth middleware throws on expired tokens"`

**Expected:**
- LEAD classifies as `bug`.
- Phase subset: THINK (lite) + BUILD + TEST + REVIEW.
- `state/think.md` contains root-cause hypothesis.
- REVIEW runs with `security.md` and `testing.md` lenses (expired-token auth touches both).
- Root cause documented in `state/reflect.md` if complex enough to trigger reflection.

**Pass criteria:** `state/think.md` present. `state/review-findings.json` present. Slack has `DONE` entries for THINK, BUILD, TEST, REVIEW phases in that order.

---

### T03 — Feature tier: full pipeline through SHIP

**Scenario:** `/lead "add dark mode toggle to settings page"`

**Expected:**
- LEAD classifies as `feature`.
- All phases except REFLECT run: THINK → PLAN → BUILD → REVIEW → TEST → SHIP.
- `state/plan-partitions.md` written with at least one partition.
- SHIPPER detects project type and writes `state/project-type.md`.
- `state/ship-log.md` written with deploy outcome.

**Pass criteria:** All 6 state artifacts present. `state/project-type.md` has a non-empty value (web / plugin / library / cli / static). Slack has `DONE` entry for each phase in correct order.

---

### T04 — Complex tier: all 7 phases with parallel BUILD fan-out

**Scenario:** `/lead "rebuild the settings system"`

**Expected:**
- LEAD classifies as `complex`.
- All 7 phases run.
- PLANNER produces `state/plan-partitions.md` with multiple partitions where `parallel_safe: true` for at least two.
- LEAD reads `plan-partitions.md` and fans out BUILDERs per wave in parallel via Task tool (not via a BUILD-LEAD intermediary — A1-final architecture).
- REVIEW runs applicable lenses in parallel.
- REFLECTOR runs full retro; appends lesson(s) to `~/.claude/devteam/memory/`.

**Pass criteria:** `state/plan-partitions.md` contains more than one partition. Slack has multiple `[BUILDER*]` entries logged in overlapping time ranges. `state/reflect.md` present.

---

### T05 — Autonomous mode: end-to-end without interruption

**Scenario:** `/lead --mode autonomous "add settings page"` on a well-scoped task with no hard-blocked questions.

**Expected:**
- LEAD mentions its classification decision at the start but does not prompt for confirmation.
- Phase boundaries proceed without check-in.
- Final report delivered without any funnel prompts.
- `.devteam/mode` stays `autonomous` after run (flag is run-only override if set that way; persistent if set via `/lead-mode`).

**Pass criteria:** Run completes without AskUserQuestion. Final report appears. Slack has no `FUNNEL` entries.

---

### T06 — Autonomous mode with intentional ambiguity: halt + notify

**Scenario:** `/lead --mode autonomous "migrate the database"` where the migration strategy is genuinely ambiguous (forward-only vs reversible).

**Expected:**
- LEAD's pre-flight (CRITIC + EXPLORER) cannot resolve the ambiguity.
- LEAD writes a `WAITING ON USER` slack entry with full question packet and pre-flight reasoning.
- Detail file written to `state/slack-detail/<id>.md`.
- PushNotification fires (default ON in autonomous).
- Run exits cleanly.
- Next invocation of `/lead-resume` surfaces the pending block prominently.

**Pass criteria:** `state/slack-detail/<id>.md` present. Slack contains `BLOCKER` entry. Run exits (does not hang). `/lead-resume` resumes from the blocked state.

---

### T07 — Direct mode interop: specialist writes state, LEAD offers continue

**Scenario:** Run `/think "explore caching strategies"` without invoking LEAD first.

**Expected:**
- `state/think.md` written.
- Slack entry for THINK with `started_in: direct` marker.
- Next `/lead "implement best caching approach"` invocation sees the direct-mode marker.
- LEAD presents option: continue from existing think.md, or start fresh.

**Pass criteria:** `state/think.md` present after `/think`. Slack has `started_in: direct` in the THINK entry. LEAD's opening message on subsequent invocation references the existing state.

---

### T08 — Specialist failure: retry once, escalate on second failure

**Scenario:** Force a BUILDER to return `status: failed` (e.g., by making the partition brief reference a non-existent file).

**Expected:**
- LEAD retries the BUILDER once with an addendum brief acknowledging the failure.
- If the second attempt also fails, LEAD escalates to user with full diagnostics regardless of autonomy mode.
- Slack has `ERROR` entry on first failure, `ERROR` entry on second failure, then `FUNNEL` / `BLOCKER` for escalation.

**Pass criteria:** Exactly two BUILDER `ERROR` entries in slack before escalation. Escalation message includes `failure_kind`, `details`, and any `partial_artifacts`.

---

### T09 — Mid-flight mode switch

**Scenario:** Start a feature task in work-together mode. After PLAN phase, run `/lead-mode autonomous`.

**Expected:**
- LEAD acknowledges the switch at the next safe point (between dispatches, not mid-agent).
- Switch logged to slack as a `MODE` entry.
- Remaining phases (BUILD, REVIEW, TEST, SHIP) run in autonomous mode without phase-boundary check-ins.

**Pass criteria:** Slack has one `MODE` entry with `work-together → autonomous` transition. No phase-boundary prompts appear after the switch.

---

### T10 — Multi-session resume via SessionStart hook

**Scenario:** Start a feature task, reach PLAN phase, close the Claude Code session. Reopen the repo.

**Expected:**
- SessionStart hook fires (`hooks/session-start.sh`).
- Session opening shows: `[devteam] Active project: <name> (mode: work-together, last phase: PLAN)`
- `[devteam] Run /lead-status to inspect, /lead to resume, /lead-abort to stop.`
- `/lead` picks up from PLAN phase without re-running THINK.

**Pass criteria:** Session opening message matches the format above. `/lead` does not re-run THINK when `state/think.md` and `state/plan.md` already exist.

---

### T11 — gstack absent: graceful degradation

**Scenario:** Remove or disable gstack plugin. Run `/lead "add new endpoint"` as a feature task.

**Expected:**
- LEAD warns at startup: gstack absent; REVIEW (`/codex`) and SHIP (`/canary`) will degrade.
- PLAN critiques (`gstack:/plan-*-review`) are skipped; PLANNER notes in plan.
- SHIP runs without canary deploy step; `state/ship-log.md` notes degraded mode.
- Run completes (does not abort).

**Pass criteria:** LEAD opening message includes degradation warning. Run completes. `state/ship-log.md` present and notes gstack-absent. No unhandled errors from missing gstack commands.

---

### T12 — Slack rotation at 2000 lines

**Scenario:** Seed `state/slack.md` with 1999 lines. Run a single BUILDER that appends one more line.

**Expected:**
- After the 2000th line is appended, `bin/slack-append.sh` rotates the file.
- Current slack contents move to `state/archive/slack-<date>.md`.
- New `state/slack.md` starts with the in-progress phase entries preserved.
- No data loss; archived file is readable.

**Pass criteria:** `state/archive/slack-<date>.md` exists after the append. New `state/slack.md` has fewer than 2000 lines. Line count of archived file + new file equals the pre-rotation count plus the new entry.

---

### T13 — Conventions auto-load in direct build mode

**Scenario:** Run `/build "add a new pinescript indicator"` in a repo that contains `*.pine` files.

**Expected:**
- `bin/devteam-detect-stack.sh` detects Pine Script from file presence signal.
- BUILDER's brief includes the path to `~/.claude/devteam/conventions/languages/pinescript.md`.
- BUILDER uses Pine Script conventions (e.g., correct v5 syntax, proper `indicator()` call signature).

**Pass criteria:** BUILDER's dispatch brief (logged to slack as `INFO`) references `~/.claude/devteam/conventions/languages/pinescript.md`. No Pine Script anti-patterns in the generated code.

---

### T14 — Each direct specialist runs standalone

**Scenario:** Invoke each of the 7 specialist commands independently, without `/lead`.

```bash
/think "explore notification approaches"
/plan "new notification system"
/build "stub notification component"
/review-project
/test unit
/ship-project
/reflect
```

**Expected:**
- Each command runs to completion without requiring LEAD orchestration.
- Each writes its corresponding state artifact.
- Each appends to slack with `started_in: direct` marker.
- No cross-contamination: running `/build` without a `state/plan.md` degrades gracefully (BUILDER uses task description alone).

**Pass criteria:** Each state artifact present after its command runs. Seven `started_in: direct` slack entries total. No command exits with an error due to missing upstream artifact.

---

### T15 — `/lead-setup` idempotent re-run

**Scenario:** Run `/lead-setup` on a machine where setup was already completed (hook registered, conventions already seeded).

**Expected:**
- Setup detects existing hook registration and existing conventions library.
- Prints per-step status, then final line:

  ```
  [lead-setup] Hook already registered. Conventions library exists at ~/.claude/devteam/conventions/ — no changes.
  ```

- No files overwritten. User's customized convention files preserved.

**Pass criteria:** Final printed line matches the expected text exactly. `~/.claude/devteam/conventions/index.json` mtime is unchanged after the re-run.

---

### T16 — Question-packet schema validation (T1)

**Scenario:** Inject a malformed question packet — missing required `phase` field, status set to an invalid value `"pending"`.

```json
{ "status": "pending", "summary": "Done" }
```

**Expected:**
- LEAD's packet parser detects the schema violation.
- Logs a `WATCHLIST` entry with `signal=3a-malformed-output` to slack.
- Treats the packet as `status: failed` and applies the failure protocol (retry once, escalate on second failure).

**Pass criteria:** Slack contains `WATCHLIST signal=3a-malformed-output`. Packet is not silently accepted. Failure protocol activates.

Verify schema file: `docs/question-packet-schema.json` has `"required": ["status", "phase"]` and `"status": { "enum": ["complete", "blocked", "failed"] }`.

---

### T17 — Slack entry format regex (T3)

**Scenario:** After running a simple task (T01 or T14 `/build` pass), inspect `state/slack.md` and validate every line matches the expected format.

**Regex (single space after `]` — the slack-append convention preserves caller's `[ACTOR#] SEV` formatting and prefixes with `#<id>  <ts>  `):**
```
^#\d{2}-\d{2}-\d{2}-\d{2}-\d{2}-\d{2}  \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}  \[[A-Za-z0-9_:/-]+#[0-9]+\] (INFO|DECISION|QUESTION|ANSWER|FUNNEL|BLOCKER|DESTRUCTIVE|DONE|ERROR|MODE|SUMMARY|WATCHLIST)  .+$
```

**Expected:**
- Every non-blank, non-comment line matches the regex.
- No partial writes (no truncated entries from concurrent append failures).
- `[ACTOR#NN]` field has numeric counter (e.g., `[LEAD#1]`, `[BUILDER:fe#3]`).

**Pass criteria:** `grep -vE '<regex>' .devteam/state/slack.md | grep -v '^$'` returns 0 lines. If the counter substitution in `bin/slack-append.sh` works correctly, no `[ACTOR#]` literal (with empty counter) appears.

---

### T18 — toolbox → devteam migration smoke (T3)

**Scenario:** On a machine with `toolbox` 0.1.0 installed, follow the migration steps from README.

```bash
/plugin uninstall toolbox
/plugin marketplace add brianyu18/devteam
/plugin install devteam@devteam
/lead-setup
/toolbox-feature "add export button"
```

**Expected:**
- After uninstall, `/toolbox-feature` is not available (pre-migration).
- After devteam install, `/toolbox-feature` resolves to the deprecated wrapper in devteam.
- `/toolbox-feature "add export button"` routes to `/lead --tier feature "add export button"`.
- LEAD runs the feature tier pipeline.
- Slack entry shows `[LEAD#1] INFO  invoked via deprecated alias toolbox-feature (--tier feature)`.

**Pass criteria:** `/toolbox-feature` works post-devteam-install. LEAD output matches a standard `/lead --tier feature` run. Slack has the deprecated-alias INFO entry.

---

## Acceptance gate

All 18 tests passing is required before tagging devteam 1.0.0. Automated smoke tests (T16 schema, T17 format regex) can be run as part of CI once distribution CI/CD lands (see TODOS.md Tier 1).

| Test | Type | Status |
|---|---|---|
| T01 — simple tier | Manual | — |
| T02 — bug tier | Manual | — |
| T03 — feature tier | Manual | — |
| T04 — complex tier, parallel fan-out | Manual | — |
| T05 — autonomous mode, clean run | Manual | — |
| T06 — autonomous mode, halt + notify | Manual | — |
| T07 — direct mode interop | Manual | — |
| T08 — failure + retry + escalate | Manual | — |
| T09 — mid-flight mode switch | Manual | — |
| T10 — multi-session resume | Manual | — |
| T11 — gstack absent, degraded | Manual | — |
| T12 — slack rotation | Manual | — |
| T13 — conventions auto-load | Manual | — |
| T14 — each specialist standalone | Manual | — |
| T15 — lead-setup idempotent | Manual | — |
| T16 — question-packet schema validator | Automated (future CI) | — |
| T17 — slack format regex | Automated (future CI) | — |
| T18 — toolbox→devteam migration smoke | Manual | — |
