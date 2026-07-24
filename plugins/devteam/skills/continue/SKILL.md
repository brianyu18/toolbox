---
name: continue
description: Use to resume a prior session from a saved checkpoint at the start of a new session. Loads minimal curated state by default; offers list/named/decisions-sidecar variants. Subsumes the prior /lead-resume by surfacing any WAITING ON USER block and offering to answer it.
---

# CONTINUE

You own the CONTINUE action. Load a prior checkpoint from `~/.claude/devteam/checkpoints/<slug>/` and resume work.

## Invocation forms

- `/continue` — load latest checkpoint for current project
- `/continue latest` — same as above
- `/continue list` — show menu of recent + named checkpoints; user picks
- `/continue <name>` — load named or history checkpoint by name
- `/continue --with-decisions` — load latest including decisions sidecar

## Steps

1. **Resolve paths.** Prefer the git toplevel so cwd-inside-a-subdir resolves to the
   same slug `/checkpoint` and `/relay` write (falls back to `pwd` outside a repo):
   ```sh
   PROJ=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
   SLUG=$(echo "$PROJ" | sed 's|/|-|g')
   DIR="$HOME/.claude/devteam/checkpoints/$SLUG"
   ```

2. **Branch on arg:**

   ### (a) No arg / `latest` / `--with-decisions`
   - If `$DIR/latest.md` does not exist:
     - **Mirror fallback (cross-machine relay baton).** If `$PROJ/.relay/baton.md` exists,
       this repo carries a relay mission's transport mirror (see the `relay` skill) and this
       machine simply has no local checkpoint dir — the mirror IS the baton here. Load
       `$PROJ/.relay/baton.md` as the checkpoint body (it is a full enriched `latest.md`
       copy), read `$PROJ/.relay/relay.json` for mission lineage (mission_id, legs, goal,
       finish line), print `Loaded from .relay/ mirror (no local checkpoint on this machine
       — mirror saved_at <ts>, leg <N>)`, and jump to step 3 with that content.
       Precedence rule (load-bearing): a LOCAL checkpoint is always canonical — this
       fallback fires ONLY when the local read misses; never prefer the mirror when
       `$DIR/latest.md` exists.
     - Otherwise print: `No checkpoint for <slug>. Run /checkpoint to create one.`
     - If any other `$HOME/.claude/devteam/checkpoints/*/latest.md` exists: also print `Other projects have checkpoints — run /continue list to see all.`
     - Exit.
   - Else: read frontmatter fields (`name`, `description`, `saved_at`, `has_decisions`).
   - Print header with description + relative time.
   - Use AskUserQuestion: "Load this checkpoint? [Y/n/list]". On Y → step 3; on n → exit; on list → branch (c).
   - If `--with-decisions` was passed: also read `latest-decisions.md` and include in step 3.

   ### (b) `<name>` (any non-keyword arg)
   - Look in `$DIR/named/<name>.md` first.
   - Fallback: find latest `$DIR/history/*<name>*.md` by mtime.
   - **Mirror fallback (cross-machine relay baton):** if neither local slot matches AND
     `$PROJ/.relay/relay.json` exists with `mission_id == <name>`, load
     `$PROJ/.relay/baton.md` as the baton (same precedence rule as (a): local is
     canonical, the mirror fires only on a local miss). Print the mirror provenance line.
   - If none of the above: `No checkpoint named '<name>' for <slug>` → exit.
   - Read frontmatter; jump to step 3.

   ### (c) `list`
   - Read frontmatter (name, description, saved_at, phase, has_decisions) from every `$DIR/history/*.md` and `$DIR/named/*.md`.
   - Build AskUserQuestion menu, latest first. Format each item:
     ```
     <relative-time> — <name>   <description>   [<phase>, has_decisions?]
     ```
     Named items get `[named]` prefix.
   - User picks → load that checkpoint (step 3).

3. **Load the chosen checkpoint into context:**
   - Paste `latest.md` (or chosen checkpoint) body verbatim. Do not summarize.
   - If `has_decisions: true` and sidecar was NOT explicitly requested: print `Decisions sidecar exists (N decisions). Run /continue --with-decisions to load it.`
   - If `--with-decisions` requested AND sidecar exists: also paste `latest-decisions.md` verbatim.

4. **Surface pending blocks** (devteam-aware — subsumes /lead-resume):
   - Read `.devteam/state/slack.md` if it exists. Grep most recent `WAITING ON USER` entry.
   - If found AND the checkpoint's `saved_at` predates the slack entry's timestamp: surface the pending question prominently.
   - Use AskUserQuestion: "Answer the pending question now? [Y/n]".
   - On Y: take the user's answer, re-invoke `/lead` with the answer in the brief. LEAD picks up from `.last-phase` and re-dispatches the blocked specialist.

5. **Drift check** (optional, recommended):
   - Compare `git log --since="@<saved_at-epoch>" --oneline | wc -l` against expected.
   - If new commits since checkpoint: print `⚠ Drift detected: N commits since saved_at. The checkpoint may be stale relative to current code.`

6. **Confirm to user:**
   ```
   RESUMED FROM CHECKPOINT
   ═══════════════════════
   Name:       <name>
   Saved:      <relative-time>
   Description: <description>
   Decisions loaded: yes|no
   Pending block: answered|ignored|none
   ```
