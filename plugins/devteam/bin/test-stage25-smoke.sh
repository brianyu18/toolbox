#!/bin/sh
# Stage 2.5 smoke harness — validates the dispatch/return/merge data-plumbing pattern
# without actually dispatching subagents (that validation happens organically in Stage 4
# when builder/review-specialist/tester are fleshed out).
#
# Exercises: slack-append (boot, decisions, dispatches, watchlist), watchlist analyzer,
# pick-lenses regex against a synthetic diff, detect-stack against a synthetic project,
# question-packet schema validation, per-actor counter substitution.
set -eu

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PLUGIN_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

SLACK_APPEND="$SCRIPT_DIR/slack-append.sh"
WATCHLIST="$SCRIPT_DIR/devteam-watchlist.sh"
PICK_LENSES="$SCRIPT_DIR/devteam-pick-lenses.sh"
DETECT_STACK="$SCRIPT_DIR/devteam-detect-stack.sh"
SCHEMA="$PLUGIN_DIR/docs/question-packet-schema.json"

TMPROOT=$(mktemp -d)
trap 'rm -rf "$TMPROOT"' EXIT INT TERM

PASS=0
FAIL=0

pass() { PASS=$((PASS+1)); printf "OK: %s\n" "$1"; }
fail() { FAIL=$((FAIL+1)); printf "FAIL: %s\n" "$1"; }

assert_eq() {
  label="$1"; expected="$2"; actual="$3"
  if [ "$expected" = "$actual" ]; then
    pass "$label"
  else
    fail "$label — expected [$expected] got [$actual]"
  fi
}

assert_contains() {
  label="$1"; needle="$2"; haystack="$3"
  if printf "%s" "$haystack" | grep -qF "$needle"; then
    pass "$label"
  else
    fail "$label — expected [$needle] in [$haystack]"
  fi
}

assert_not_contains() {
  label="$1"; needle="$2"; haystack="$3"
  if printf "%s" "$haystack" | grep -qF "$needle"; then
    fail "$label — did NOT expect [$needle] in [$haystack]"
  else
    pass "$label"
  fi
}

assert_ge() {
  label="$1"; min="$2"; actual="$3"
  if [ "$actual" -ge "$min" ]; then
    pass "$label"
  else
    fail "$label — expected >= $min, got $actual"
  fi
}

# Helper: create a dated watchlist entry with the exact slack.md line format
# Format: #YY-MM-DD-HH-MM-SS  YYYY-MM-DD HH:MM:SS  [ACTOR#NN] WATCHLIST  signal=<id>  detail=<text>
days_ago_ts() {
  python3 -W ignore -c "
import datetime
d = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=$1)
print(d.strftime('%Y-%m-%d %H:%M:%S'))
"
}

make_watchlist_entry() {
  ts="$1"; signal="$2"; actor="${3:-LEAD}"
  id=$(printf "%s" "$ts" | sed 's/[-: ]/-/g' | cut -c1-17)
  printf "#%s  %s  [%s#1] WATCHLIST  signal=%s  detail=test\n" "$id" "$ts" "$actor" "$signal"
}

# ---------------------------------------------------------------------------
# Scenario 1 — Boot + slack append
# ---------------------------------------------------------------------------
printf "\n=== Scenario 1: Boot + slack append ===\n"

S1_ROOT="$TMPROOT/s1"
mkdir -p "$S1_ROOT/.devteam/state"
export DEVTEAM_STATE_DIR="$S1_ROOT/.devteam/state"
cd "$S1_ROOT"

sh "$SLACK_APPEND" "[LEAD#] INFO  Booting"
sh "$SLACK_APPEND" "[LEAD#] DECISION  Tier=feature"
sh "$SLACK_APPEND" "[LEAD#] INFO  Dispatching THINKER"

SLACK_FILE="$S1_ROOT/.devteam/state/slack.md"

# Verify line count
LINES=$(wc -l < "$SLACK_FILE" | tr -d ' ')
assert_eq "3 entries written → 3 lines" "3" "$LINES"

# Verify each line starts with # (entry-id prefix)
BAD=$(grep -cv "^#" "$SLACK_FILE" || true)
assert_eq "all lines start with #" "0" "$BAD"

# Verify counter increments: lines should contain #1, #2, #3 in the actor tags
# The format is [LEAD#1], [LEAD#2], [LEAD#3]
assert_contains "first entry has LEAD#1"  "[LEAD#1]"  "$(cat "$SLACK_FILE")"
assert_contains "second entry has LEAD#2" "[LEAD#2]"  "$(cat "$SLACK_FILE")"
assert_contains "third entry has LEAD#3"  "[LEAD#3]"  "$(cat "$SLACK_FILE")"

# Verify message text is present
assert_contains "boot entry text"       "INFO  Booting"          "$(cat "$SLACK_FILE")"
assert_contains "decision entry text"   "DECISION  Tier=feature" "$(cat "$SLACK_FILE")"
assert_contains "dispatch entry text"   "Dispatching THINKER"    "$(cat "$SLACK_FILE")"

unset DEVTEAM_STATE_DIR

# ---------------------------------------------------------------------------
# Scenario 2 — Watchlist boot check (ALL CLEAR on fresh slack)
# ---------------------------------------------------------------------------
printf "\n=== Scenario 2: Watchlist boot check (ALL CLEAR) ===\n"

S2_ROOT="$TMPROOT/s2"
mkdir -p "$S2_ROOT/.devteam/state"
export DEVTEAM_STATE_DIR="$S2_ROOT/.devteam/state"
cd "$S2_ROOT"

# Fresh slack with only non-watchlist entries
sh "$SLACK_APPEND" "[LEAD#] INFO  Booting"
sh "$SLACK_APPEND" "[LEAD#] DECISION  Tier=feature"

WL_OUT=$(sh "$WATCHLIST" 2>/dev/null)
assert_contains "fresh slack → ALL CLEAR" "ALL CLEAR" "$WL_OUT"
assert_not_contains "fresh slack → no ALERT" "ALERT" "$WL_OUT"

unset DEVTEAM_STATE_DIR

# ---------------------------------------------------------------------------
# Scenario 3 — pick-lenses against a synthetic diff
# ---------------------------------------------------------------------------
printf "\n=== Scenario 3: pick-lenses against synthetic diff ===\n"

S3_REPO="$TMPROOT/s3/repo"
mkdir -p "$S3_REPO"
cd "$S3_REPO"
git init -q
git config user.email "smoke@test.com"
git config user.name "Smoke Test"

# Baseline commit
touch .gitkeep
git add .gitkeep
git commit -q -m "init"

# Create files that trigger: api-contract, data-migration, security, a11y, testing
mkdir -p app/api/users migrations src

# api-contract trigger: app/api/*/route.ts
cat > app/api/users/route.ts <<'EOF'
export async function GET(req) { return Response.json({}) }
EOF

# data-migration trigger: migrations/ path + ALTER TABLE content
cat > migrations/001_add_users.sql <<'EOF'
ALTER TABLE users ADD COLUMN email_verified boolean DEFAULT false;
EOF

# security + a11y trigger: Login.tsx (auth path → security; .tsx → a11y)
cat > src/Login.tsx <<'EOF'
export function Login() { return <form><input type="password" /></form>; }
EOF

git add app/api/users/route.ts migrations/001_add_users.sql src/Login.tsx
git commit -q -m "add synthetic changes"

LENSES=$(sh "$PICK_LENSES" --base HEAD~1 --head HEAD 2>/dev/null | sort)

assert_contains "api-contract lens fires"    "api-contract"    "$LENSES"
assert_contains "data-migration lens fires"  "data-migration"  "$LENSES"
assert_contains "security lens fires"        "security"        "$LENSES"
assert_contains "a11y lens fires"            "a11y"            "$LENSES"
assert_contains "testing lens fires"         "testing"         "$LENSES"

# ---------------------------------------------------------------------------
# Scenario 4 — detect-stack against synthetic project
# ---------------------------------------------------------------------------
printf "\n=== Scenario 4: detect-stack against synthetic project ===\n"

S4_ROOT="$TMPROOT/s4"
S4_PLUGIN="$S4_ROOT/plugin"
S4_CONV="$S4_PLUGIN/conventions-seed"
S4_PROJ="$S4_ROOT/proj"

mkdir -p "$S4_CONV/frontend" "$S4_PROJ"

# Stub convention files (need to exist for path assertions)
touch "$S4_CONV/frontend/react.md"
touch "$S4_CONV/frontend/nextjs.md"

# Synthetic index.json with react (file_contains "react") and nextjs (file_contains "next")
cat > "$S4_CONV/index.json" <<'ENDJSON'
[
  {
    "convention": "frontend/react.md",
    "signals": [
      {"file_contains": {"file": "package.json", "pattern": "\"react\""}}
    ],
    "tests": ["jest", "vitest"]
  },
  {
    "convention": "frontend/nextjs.md",
    "signals": [
      {"file_contains": {"file": "package.json", "pattern": "\"next\""}}
    ],
    "tests": ["jest", "playwright"]
  }
]
ENDJSON

# Fake package.json with both react and next
cat > "$S4_PROJ/package.json" <<'EOF'
{
  "dependencies": {
    "react": "^18.0.0",
    "react-dom": "^18.0.0",
    "next": "^14.0.0"
  }
}
EOF

STACK=$(CLAUDE_PLUGIN_ROOT="$S4_PLUGIN" sh "$DETECT_STACK" --project-dir "$S4_PROJ" 2>/dev/null)

assert_contains "react.md detected"  "$S4_CONV/frontend/react.md"  "$STACK"
assert_contains "nextjs.md detected" "$S4_CONV/frontend/nextjs.md" "$STACK"

# --tests flag returns test layer names
TESTS=$(CLAUDE_PLUGIN_ROOT="$S4_PLUGIN" sh "$DETECT_STACK" --project-dir "$S4_PROJ" --tests 2>/dev/null)

assert_contains "--tests returns jest"       "jest"       "$TESTS"
assert_contains "--tests returns vitest"     "vitest"     "$TESTS"
assert_contains "--tests returns playwright" "playwright" "$TESTS"

# ---------------------------------------------------------------------------
# Scenario 5 — Question packet schema validation
# ---------------------------------------------------------------------------
printf "\n=== Scenario 5: Question packet schema validation ===\n"

S5_DIR="$TMPROOT/s5"
mkdir -p "$S5_DIR"

# Check if jsonschema Python module is available
HAVE_JSONSCHEMA=0
if python3 -c "import jsonschema" 2>/dev/null; then
  HAVE_JSONSCHEMA=1
fi

# Write sample packets
cat > "$S5_DIR/complete.json" <<'EOF'
{
  "status": "complete",
  "phase": "BUILD",
  "summary": "Implemented user auth endpoints",
  "artifacts": ["src/auth/login.ts", "src/auth/logout.ts"],
  "next_phase_ready": true,
  "notes_for_lead": "JWT secret must be set in env before SHIP phase"
}
EOF

cat > "$S5_DIR/blocked.json" <<'EOF'
{
  "status": "blocked",
  "phase": "BUILD",
  "question": "Which ORM should I use?",
  "options": [
    {"id": "A", "label": "Prisma", "tradeoff": "type-safe, more setup"},
    {"id": "B", "label": "Drizzle", "tradeoff": "lighter, less magic"}
  ],
  "specialist_recommendation": "A",
  "reasoning": "Project already has Prisma schema files",
  "context_needed_to_resume": "ORM choice confirmed"
}
EOF

cat > "$S5_DIR/failed.json" <<'EOF'
{
  "status": "failed",
  "phase": "BUILD",
  "failure_kind": "tool_error",
  "details": "npm test exited 130 — tsc type errors in generated file",
  "partial_artifacts": ["src/generated/schema.ts"]
}
EOF

cat > "$S5_DIR/malformed.json" <<'EOF'
{
  "status": "bogus",
  "phase": "BUILD"
}
EOF

validate_packet() {
  pfile="$1"
  if [ "$HAVE_JSONSCHEMA" -eq 1 ]; then
    python3 -c "
import json, jsonschema, sys
schema = json.load(open('$SCHEMA'))
packet = json.load(open('$pfile'))
try:
    jsonschema.validate(packet, schema)
    sys.exit(0)
except jsonschema.ValidationError as e:
    sys.exit(1)
" 2>/dev/null
  else
    # Fallback: manual structural check
    python3 -c "
import json, sys
packet = json.load(open('$pfile'))
status = packet.get('status', '')
phase  = packet.get('phase', '')
valid_statuses = {'complete', 'blocked', 'failed'}
valid_phases   = {'THINK', 'PLAN', 'BUILD', 'REVIEW', 'TEST', 'SHIP', 'REFLECT'}
if status not in valid_statuses:
    sys.exit(1)
if phase not in valid_phases:
    sys.exit(1)
sys.exit(0)
" 2>/dev/null
  fi
}

validate_should_fail() {
  pfile="$1"
  if [ "$HAVE_JSONSCHEMA" -eq 1 ]; then
    python3 -c "
import json, jsonschema, sys
schema = json.load(open('$SCHEMA'))
packet = json.load(open('$pfile'))
try:
    jsonschema.validate(packet, schema)
    sys.exit(0)
except jsonschema.ValidationError:
    sys.exit(1)
" 2>/dev/null
  else
    python3 -c "
import json, sys
packet = json.load(open('$pfile'))
status = packet.get('status', '')
valid_statuses = {'complete', 'blocked', 'failed'}
if status not in valid_statuses:
    sys.exit(1)
sys.exit(0)
" 2>/dev/null
  fi
}

if validate_packet "$S5_DIR/complete.json"; then
  pass "complete packet validates"
else
  fail "complete packet should validate"
fi

if validate_packet "$S5_DIR/blocked.json"; then
  pass "blocked packet validates"
else
  fail "blocked packet should validate"
fi

if validate_packet "$S5_DIR/failed.json"; then
  pass "failed packet validates"
else
  fail "failed packet should validate"
fi

if validate_should_fail "$S5_DIR/malformed.json"; then
  fail "malformed packet should fail validation"
else
  pass "malformed packet (status=bogus) correctly fails validation"
fi

if [ "$HAVE_JSONSCHEMA" -eq 0 ]; then
  printf "  (note: jsonschema module not available — used manual structural check fallback)\n"
fi

# ---------------------------------------------------------------------------
# Scenario 6 — Per-actor counters under contention
# ---------------------------------------------------------------------------
printf "\n=== Scenario 6: Per-actor counters under contention ===\n"

S6_ROOT="$TMPROOT/s6"
mkdir -p "$S6_ROOT/.devteam/state"
export DEVTEAM_STATE_DIR="$S6_ROOT/.devteam/state"
cd "$S6_ROOT"

# Append 5 entries each from 3 actors, interleaved
i=1
while [ "$i" -le 5 ]; do
  sh "$SLACK_APPEND" "[LEAD#] INFO  lead-msg-$i" &
  sh "$SLACK_APPEND" "[BUILDER:fe#] INFO  fe-msg-$i" &
  sh "$SLACK_APPEND" "[BUILDER:api#] INFO  api-msg-$i" &
  i=$((i+1))
done
wait

SLACK6="$S6_ROOT/.devteam/state/slack.md"

# Total lines = 15
TOTAL=$(wc -l < "$SLACK6" | tr -d ' ')
assert_eq "15 total lines (5 per actor)" "15" "$TOTAL"

# All lines well-formed (start with #)
BAD=$(grep -cv "^#" "$SLACK6" || true)
assert_eq "all 15 lines well-formed" "0" "$BAD"

# Each actor ends at counter #5
LEAD_MAX=$(grep -o '\[LEAD#[0-9]*\]' "$SLACK6" | grep -o '[0-9]*' | sort -n | tail -1)
FE_MAX=$(grep -o '\[BUILDER:fe#[0-9]*\]' "$SLACK6" | grep -o '[0-9]*' | sort -n | tail -1)
API_MAX=$(grep -o '\[BUILDER:api#[0-9]*\]' "$SLACK6" | grep -o '[0-9]*' | sort -n | tail -1)

assert_eq "LEAD counter ends at #5"        "5" "$LEAD_MAX"
assert_eq "BUILDER:fe counter ends at #5"  "5" "$FE_MAX"
assert_eq "BUILDER:api counter ends at #5" "5" "$API_MAX"

# Each actor has exactly 5 entries
LEAD_CNT=$(grep -c '\[LEAD#' "$SLACK6" || true)
FE_CNT=$(grep -c '\[BUILDER:fe#' "$SLACK6" || true)
API_CNT=$(grep -c '\[BUILDER:api#' "$SLACK6" || true)

assert_eq "5 LEAD entries" "5" "$LEAD_CNT"
assert_eq "5 BUILDER:fe entries" "5" "$FE_CNT"
assert_eq "5 BUILDER:api entries" "5" "$API_CNT"

unset DEVTEAM_STATE_DIR

# ---------------------------------------------------------------------------
# Scenario 7 — Watchlist signal accumulation (3b-manual-log threshold = 2)
# ---------------------------------------------------------------------------
printf "\n=== Scenario 7: Watchlist signal accumulation ===\n"

S7_ROOT="$TMPROOT/s7"

# Sub-scenario 7a: 1 entry → ALL CLEAR (below threshold of 2)
mkdir -p "$S7_ROOT/a/.devteam/state"
make_watchlist_entry "$(days_ago_ts 3)" "3b-manual-log" >> "$S7_ROOT/a/.devteam/state/slack.md"

OUT7A=$(DEVTEAM_STATE_DIR="$S7_ROOT/a/.devteam/state" sh "$WATCHLIST" 2>/dev/null)
assert_contains "1 signal → ALL CLEAR"  "ALL CLEAR" "$OUT7A"
assert_not_contains "1 signal → no ALERT" "ALERT"  "$OUT7A"

# Sub-scenario 7b: 2 entries → ALERT fires
mkdir -p "$S7_ROOT/b/.devteam/state"
make_watchlist_entry "$(days_ago_ts 3)" "3b-manual-log" >> "$S7_ROOT/b/.devteam/state/slack.md"
make_watchlist_entry "$(days_ago_ts 7)" "3b-manual-log" >> "$S7_ROOT/b/.devteam/state/slack.md"

OUT7B=$(DEVTEAM_STATE_DIR="$S7_ROOT/b/.devteam/state" sh "$WATCHLIST" 2>/dev/null)
assert_contains "2 signals → ALERT fires"          "ALERT"        "$OUT7B"
assert_contains "2 signals → names 3b-manual-log"  "3b-manual-log" "$OUT7B"

# ---------------------------------------------------------------------------
# Scenario 8 — Concurrent slack appends under load (regression check)
# ---------------------------------------------------------------------------
printf "\n=== Scenario 8: Concurrent slack appends under load ===\n"

S8_ROOT="$TMPROOT/s8"
mkdir -p "$S8_ROOT/.devteam/state"
export DEVTEAM_STATE_DIR="$S8_ROOT/.devteam/state"
cd "$S8_ROOT"

i=0
while [ "$i" -lt 10 ]; do
  sh "$SLACK_APPEND" "[LOAD#] INFO  concurrent-msg-$i" &
  i=$((i+1))
done
wait

SLACK8="$S8_ROOT/.devteam/state/slack.md"
LINES8=$(wc -l < "$SLACK8" | tr -d ' ')
assert_eq "10 concurrent appends → 10 lines" "10" "$LINES8"

BAD8=$(grep -cv "^#" "$SLACK8" || true)
assert_eq "no malformed lines under load" "0" "$BAD8"

unset DEVTEAM_STATE_DIR

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
TOTAL_CHECKED=$((PASS + FAIL))
printf "\nStage 2.5 smoke: %d passed, %d failed\n" "$PASS" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
