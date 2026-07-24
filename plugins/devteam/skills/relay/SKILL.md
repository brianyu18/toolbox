---
name: relay
description: Baton-pass the current mission to a FRESH session (a relay leg, not a resume). Wraps the devteam checkpoint as its durability CORE (brain/vault layers are an OPTIONAL enhancement when present), enriches the checkpoint with mission framing so an unmodified /continue picks it up, and writes/appends a relay-record (mission_id + goal + definition-of-done + per-leg trail). Use when context is filling and you want the WORK to continue in a fresh runner. Distinct from take-over/resume ("still me elsewhere") — this is "next runner, here's the mission, run to the finish line or pass it on again."
---

# /relay — pass the baton to the next runner

## Status
**Graduated at devteam 1.5.0** after the stability gate passed: live-verified end-to-end
2026-07-23 (manual pass on a real 24h mission AND the agent-os kernel's automated
button-pass on a scratch repo — handshake, light save, clone spawn, mission-named seed,
park). The cross-machine read path is closed by `/continue`'s `.relay/` mirror-fallback
(this release).

## What this is (and is NOT)
- **IS:** a *baton pass* — compress this leg's state into a durable baton, so a **fresh**
  session picks up the *mission* (goal → finish line), runs until done or until IT needs
  to pass on. Context is deliberately shed; the baton carries the thread.
- **IS NOT:** `claude --resume` / take-over — that's "still me, running elsewhere" with full
  context. If you want that, don't use this.

## Mental model
`/relay` (leg 1) → fresh session `/devteam:continue` (leg 2) → `/relay` → fresh session
`/devteam:continue` (leg 3) → … until the finish line. Every runner has the baton and can
pass it on. Durability = the devteam checkpoint at EVERY pass (the CORE this skill owns),
plus the optional brain layer when that environment is present (see step 3).

## Procedure

### 1. Resolve the checkpoint dir + slug (co-location is load-bearing)
The relay-record MUST sit next to the checkpoint so `/devteam:continue` and any external
automation (e.g. the agent-os kernel) find it. Same resolution as `/checkpoint`:
```sh
PROJ=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
SLUG=$(echo "$PROJ" | sed 's|/|-|g')          # every "/" → "-", INCLUDING the leading one
DIR="$HOME/.claude/devteam/checkpoints/$SLUG"
RELAY="$DIR/relay.json"
```
Write `relay.json` into `$DIR` **by construction** — do not recompute a slug a second way.

### 2. Read or mint the relay-record (with mission lifecycle)
First, parse the args:
- **`--attempt <id>`** (present ⇒ this run was driven by AUTOMATION — e.g. the agent-os
  relay button — not a human). Capture `<id>` — it goes into the leg you write (step 5)
  and it switches this run to NONINTERACTIVE (step 5b: no consent question; step 2
  continuity check: skipped — automation ALWAYS continues the active mission). Absent ⇒ a
  human ran `/relay` interactively.
- **`--done`** ⇒ mark the active mission COMPLETE (see step 6) instead of passing a new baton.
- Any other arg text ⇒ a goal/DoD override.

**Continuity check (MANUAL runs only — no `--attempt`).** If an ACTIVE `$RELAY` exists, before
appending, show its `goal` + `mission_id` and ASK once: "Continue mission `<goal>` (append leg
N), or start a NEW mission here?" — because a manual `/relay` might be UNRELATED work in the same
repo, and appending would conflate two missions. "New" → rotate the active record aside
(`mv "$RELAY" "$DIR/relay-<old_mission_id>.json"`) and mint fresh (LEG 1 below). "Continue" →
append (LEG N below). AUTOMATION never asks — the button is always continuing its own session's
mission, so it always appends.

**Last-writer WARN (part of the same check):** before deciding, compare the ACTIVE record's
latest leg `sid` + `updated_at` against THIS session. If a DIFFERENT sid wrote within the last
~5 minutes, warn LOUDLY first: "⚠ session `<sid>` wrote this mission's record `<N>`s ago —
another live session may be mid-relay here; continuing may clobber concurrent work. Append /
new / abort?" (Detection, not prevention — manual writes have no cross-process lock by design;
this surfaces the exact hazard instead of silently racing.)

Then decide LEG vs FRESH MISSION:
- **No `$RELAY`, OR existing `status == "complete"`, OR the continuity check said NEW → LEG 1 of
  a (new) mission.** If a COMPLETE (or continuity-superseded) record exists, ROTATE it first
  (`mv "$RELAY" "$DIR/relay-<old_mission_id>.json"`) so the trail isn't corrupted, then mint fresh. Mint:
  - `mission_id`: short stable id, e.g. `m-$(date +%s | tail -c 7)` or a short uuid.
  - `goal` (1–2 sentences) + `definition_of_done` (the finish line): from the arg override if
    given, else **synthesize from THIS conversation**. Carried to EVERY future leg unchanged —
    get the finish line right.
  - `settings`: detect what you can (model from runtime; else `null`). External automation
    (e.g. the agent-os kernel) is authoritative for managed spawns; this is a hint.
- **Existing `$RELAY` with `status == "active"` → LEG N (N = current legs + 1).** Read it; keep
  `mission_id`, `goal`, `definition_of_done`, `settings` UNCHANGED (no finish-line drift). An
  explicit arg revision to goal/DoD updates it — say so.
- **LIMIT:** one ACTIVE mission per repo. Two genuinely-different simultaneous missions in
  one repo are not supported — they'd share this record. Finish (mark `complete`) before starting
  a different mission in the same repo. (Parallel missions: use a git WORKTREE — a distinct
  cwd resolves to a distinct slug, giving each mission its own checkpoint dir + relay.json
  with zero extra machinery.)

### 3. Durability save — CORE (checkpoint) always; brain layer OPTIONAL
**CORE (always, both manual and automation): write the devteam checkpoint.** Perform the
`/checkpoint` procedure from THIS plugin's `skills/checkpoint/SKILL.md` inline (read it and
follow it exactly — do NOT try to invoke the `/checkpoint` command; the model cannot type
slash commands). This writes `$DIR/latest.md` (frontmatter + curated body, history rotation,
atomic write). The checkpoint is the baton's substance — same rigor as any explicit save.

**OPTIONAL brain layer — detect, then branch.** If this machine has the brain/claude-sync
environment (check: a `fullsave` skill is available, or `~/Desktop/claude-projects/claude-sync/skills/fullsave/SKILL.md`
exists), ALSO:
- **MANUAL run (no `--attempt`):** invoke the full `fullsave` skill INSTEAD of the bare
  checkpoint above (it performs the same checkpoint write plus brain `/save` + `/log` +
  vault push — reuse verbatim, do not re-implement).
- **AUTOMATION run (`--attempt` present): LIGHT save.** The automation blocks on the
  attempt-matched `relay.json` (step 5) under a hard save-timeout, and validates NOTHING
  beyond that record + the named baton the seed loads. So: the checkpoint CORE above, plus
  brain `/save` ONLY (one local file write — the successor's session-start hook auto-loads
  `state.md`, so skipping it would hand the next runner STALE project state). **SKIP** brain
  `/log` and the vault push (slow, network-bound, never validated by the handshake) — on
  kernel-managed sessions they ride the park-side save of the departing leg.

**No brain environment → no-op the optional layer** and add one honest line to the step-6
report: `brain layer: not present — checkpoint-only save`. The relay is fully functional
without it; this skill must NEVER hard-fail because fullsave/brain is absent.

### 4. Enrich the checkpoint with the Relay block (so unmodified `/devteam:continue` surfaces it)
AFTER step 3's save has written `$DIR/latest.md` (core or fullsave path alike), APPEND this
block to the END of `latest.md` body (it becomes part of what `/devteam:continue` loads
verbatim — no plugin edit needed):
```markdown

## Relay — mission <mission_id>, leg <N>

**Goal:** <goal>
**Finish line (done when):** <definition_of_done>

You are the next runner in a relay. `/devteam:continue <mission_id>` loads this baton (the
mission's own NAMED checkpoint slot — immune to other saves in this repo overwriting latest).
The prior leg's state is above. Carry the mission toward the finish line. When YOUR context
fills, run `/relay` to pass the baton to a fresh runner (or hold the relay button in a managed
session). Prior legs: <n> (see relay.json for the trail). On a machine with no local
checkpoint, `/devteam:continue` falls back to `.relay/baton.md` in the repo automatically.

**The mission is the FOCUS, not the whole of the work.** This baton deliberately does NOT
restate the project's full backlog — batons condense, ledgers don't. Before starting, read
the full outstanding-work ledger if present (`.devteam/state/OUTSTANDING.md` in the repo,
plus any project state your environment auto-loads) — and NEVER report the mission's items
as the only outstanding work.
```

### 4b. Save the baton into the mission's NAMED checkpoint slot (the floor — collision immunity)
`latest.md` is ONE shared slot per project: any other save in this repo (another mission's
relay, a plain checkpoint) overwrites it. The mission's authoritative baton therefore ALSO
lives in a named checkpoint — `named/` slots are NEVER rotated and are read directly by
`/devteam:continue <mission_id>` and listed by `/continue list`:
```sh
mkdir -p "$DIR/named"
cp "$DIR/latest.md" "$DIR/named/<mission_id>.md"   # mission_id already starts with m-
```
(Refresh this copy on EVERY leg — it must always hold the newest enriched baton. `latest.md`
still updates too, so plain `/devteam:continue` keeps working when this is the only mission.)

### 5. Write / append `relay.json` (portable — self-contained, do NOT import agent_os)
Write the record following THIS schema exactly (external automation — the agent-os kernel —
reads it via `agent_os.relay`; keep them in lockstep). Use a small inline `python3` heredoc so
this works in ANY project (never assume agent-os is importable):
```python
import json, os, datetime
p = os.path.expanduser("$RELAY")
now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
rec = json.load(open(p)) if os.path.exists(p) else {
    "mission_id": "<id>", "goal": "<goal>", "definition_of_done": "<dod>",
    "cwd": "<PROJ>", "settings": {"model": None, "effort": None, "permission_mode": None, "agent": None},
    "status": "active", "created_at": now, "updated_at": now, "legs": []}
# leg N = current session; set outcome (what this leg did) + next (the immediate next action).
# attempt_id: the value from --attempt (or None if a human ran this). The automation's relay
# endpoint WAITS for a leg carrying the attempt_id it injected before it treats the save as
# complete — so echoing it here is the completion handshake. Omit/None for manual runs.
# sid = the CURRENT SESSION's id (check your context/JSONL path; 'manual' if unknowable).
# NEVER put the --attempt value in sid — attempt_id has its own field below.
rec["legs"].append({
    "n": len(rec["legs"]) + 1, "sid": "<THIS session's id, or 'manual'>",
    "started_at": "<this leg start, ISO, or now>", "ended_at": now,
    "checkpoint": os.path.join(os.path.dirname(p), "latest.md"),
    "attempt_id": "<value from --attempt, or None>",
    "outcome": "<one line: what this leg accomplished / where it stopped>",
    "next": "<one line: the immediate next action for the next runner>"})
rec["updated_at"] = now
os.makedirs(os.path.dirname(p), mode=0o700, exist_ok=True)
tmp = p + ".tmp"; json.dump(rec, open(tmp, "w"), indent=1); os.chmod(tmp, 0o600); os.replace(tmp, p)
print("relay.json leg", len(rec["legs"]), "→", p)
```
Schema contract (fail-closed on the reader side — every field matters): top-level requires
`mission_id, goal, definition_of_done, cwd, settings, status, created_at, updated_at, legs`;
`settings` has exactly `model, effort, permission_mode, agent` (str or null); every leg
requires non-null strings `sid, started_at, checkpoint, outcome, next` (+ `ended_at` str/null).
A single malformed leg makes automation readers treat the WHOLE record as absent.
The `outcome`/`next` one-liners are the SAME facts the checkpoint already synthesized
(where-we-left-off, next steps) — reuse them; do not regenerate.

### 5b. Write the IN-REPO mirror (cross-machine baton)
The machine-local checkpoint is single-machine BY CONSTRUCTION (the slug embeds this machine's
absolute path). So ALSO mirror the baton into the repo.

**Precedence (load-bearing):** the machine-local checkpoint is CANONICAL; `.relay/` is a
DERIVED transport copy. Same machine → local wins, always. Another machine with no local
checkpoint → the mirror IS the baton (`/devteam:continue` falls back to it automatically).
Both carry saved_at + leg N so a reader can compare.

**Security scrub is CODE, not prose (ALWAYS, before writing — REFUSE on any doubt).** Write this
exact tested helper to a temp file and run it for EACH mirrored file; a non-zero exit means a
secret pattern survived → do NOT publish that mirror file, tell the user loudly. (Redaction is a
defense-in-depth BACKSTOP; the gitignored-by-default posture below is the real protection.
Conversation-derived state must never carry a credential into git history.)
```sh
SCRUB="$(mktemp -t relay-scrub.XXXXXX.py)"
cat > "$SCRUB" <<'PY'
import os, re, sys
_P=[r"sk-[A-Za-z0-9_-]{16,}", r"AKIA[0-9A-Z]{12,}", r"ghp_[A-Za-z0-9]{20,}",
    r"gho_[A-Za-z0-9]{20,}", r"xox[baprs]-[A-Za-z0-9-]{10,}", r"AIza[0-9A-Za-z_-]{30,}",
    r"-----BEGIN [A-Z ]*PRIVATE KEY-----", r"[Bb]earer\s+[A-Za-z0-9._-]{16,}",
    r"eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{6,}",
    r"(api[_-]?key|secret|token|password|passwd)\s*[:=]\s*['\"]?[A-Za-z0-9/_+=.-]{12,}"]
RX=re.compile("|".join(_P), re.IGNORECASE); M="[REDACTED-SECRET]"
def go(src,dst):
    raw=open(src,encoding="utf-8",errors="replace").read(); out=RX.sub(M,raw)
    if RX.search(out.replace(M,"")): raise RuntimeError("scrub incomplete; refusing")
    t=dst+".tmp"; open(t,"w",encoding="utf-8").write(out); os.chmod(t,0o600); os.replace(t,dst)
try: go(sys.argv[1],sys.argv[2])
except Exception as e:
    try: os.path.exists(sys.argv[2]) and os.remove(sys.argv[2])
    except OSError: pass
    print("relay-scrub REFUSED:",e,file=sys.stderr); sys.exit(2)
PY
mkdir -p "$PROJ/.relay"
python3 "$SCRUB" "$DIR/named/<mission_id>.md" "$PROJ/.relay/baton.md" || echo "MIRROR baton.md NOT written (secret found)"
python3 "$SCRUB" "$RELAY"                     "$PROJ/.relay/relay.json" || echo "MIRROR relay.json NOT written (secret found)"
rm -f "$SCRUB"
```
(The baton mirror sources the mission's NAMED slot — never bare `latest.md`, which a plain
checkpoint may later overwrite without the Relay block.)

**Git posture — SAFE BY DEFAULT; consent is INTERACTIVE-ONLY:**
- **If this run is AUTOMATION-driven (`--attempt` was present): NEVER ask. Default to
  local-only** — ensure `.relay/` is in `.gitignore` (append if absent), record
  `"mirror": "gitignored"` in relay.json. No prompt can stall the automation's pass.
- **Only when a HUMAN ran `/relay` (no `--attempt`) AND relay.json has no `"mirror"` key yet:**
  append `.relay/` to `.gitignore` (default local-only), then ask ONCE — "Commit the baton for
  push→continue-anywhere (solo private repos), or keep it gitignored/local-only (shared/public
  remotes)?" Record `"mirror": "committed"` (and remove the .gitignore line **only after**
  confirming `git ls-files --error-unmatch .relay/` shows nothing already tracked — never
  un-ignore a path git is already tracking) or `"mirror": "gitignored"`. Never ask again.
- If `"mirror"` is already set, honor it silently (automation and humans alike).
- On another machine (no local checkpoint): a fresh session's `/devteam:continue` reads
  `.relay/baton.md` automatically (only present there if mirror=committed).

### 6. Report
Print, verbatim, an aggregate that includes the step-3 save report (fullsave's own report on
manual brain runs; the checkpoint byte-count line otherwise, marked `light save` or
`checkpoint-only` as applicable) PLUS:
```
RELAY — baton written
  mission:  <mission_id>  (leg <N>, finish line: <one-line DoD>)
  record:   <RELAY>
  mirror:   <PROJ>/.relay/  (commit + push for cross-machine continuation)
  baton:    <DIR>/named/<mission_id>.md  (the mission's own slot — never rotated)
  next:     open a FRESH session and run /devteam:continue <mission_id>  (exact mission pickup;
            plain /devteam:continue also works when this is the repo's only mission; bare
            /continue is Claude Code's resume picker — NOT this) — or hold the relay button
            in a managed session
```
**Completion (mark the mission done so it stops accepting legs and rotates out of the next
relay's way):**
- **Explicit — `/relay --done`:** set `status: "complete"` in the record (final leg optional),
  print `RELAY — mission <id> marked COMPLETE (by you)`. No new baton is passed.
- **Judged — the finish line is now MET:** you MAY set `status: "complete"` on your own judgment,
  but you MUST INFORM the user LOUDLY and give them the veto — print
  `RELAY — I judge mission <id> COMPLETE: <one-line why the DoD is met>. Marked complete; run
  /relay to reopen/continue if you disagree.` Never mark complete silently.
- A `complete` mission is rotated aside by the NEXT `/relay` in this repo (step 2), so completing
  is what lets a fresh mission start cleanly in the same project.

## Failure modes
- **No git repo:** use `pwd` for `$PROJ` (step 1 already falls back). Everything else proceeds.
- **Step-3 save partial failure (checkpoint, fullsave, or light path):** relay STILL writes
  `relay.json` + the Relay block against whatever checkpoint the save managed to write; relay
  the save report's ✗ lines. Never roll back.
- **`relay.json` malformed on read (leg N):** treat as leg 1 (mint fresh) but WARN the user the
  prior trail was unreadable — do not silently drop lineage.
- **Brain layer absent:** not a failure — checkpoint-only save, one honest report line (step 3).

## Relationship to other skills
- `/checkpoint` — the durability CORE (this skill performs its procedure inline). Use it alone
  for a plain mid-session savepoint with no baton pass.
- `fullsave` (claude-sync/brain, OPTIONAL) — the enhanced durability layer on machines that
  have it; invoked by this skill when present, never required.
- `/devteam:continue` — the READ side: a fresh session runs it to load the baton (local slot,
  or the `.relay/` mirror on a machine with no local checkpoint). NOTE: bare `/continue` is
  Claude Code's built-in resume picker (take-over of a prior conversation) — NOT this.
- Take-over / `--resume` — the OTHER primitive (full-context relocation), not this.
