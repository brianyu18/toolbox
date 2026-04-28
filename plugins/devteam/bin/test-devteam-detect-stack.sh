#!/bin/sh
# bin/test-devteam-detect-stack.sh
# Smoke test for devteam-detect-stack.sh.
# Creates a temp CLAUDE_PLUGIN_ROOT with a stubbed index.json,
# runs the script with different project dirs, checks output.
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SCRIPT="$SCRIPT_DIR/devteam-detect-stack.sh"

PASS=0
FAIL=0

pass() { PASS=$((PASS+1)); printf "OK: %s\n" "$1"; }
fail() { FAIL=$((FAIL+1)); printf "FAIL: %s\n" "$1"; }

# ---------------------------------------------------------------------------
# Build temp plugin root with index.json
# ---------------------------------------------------------------------------
TMPROOT=$(mktemp -d)
trap 'rm -rf "$TMPROOT"' EXIT INT TERM

PLUGIN_ROOT="$TMPROOT/plugin"
CONV_DIR="$PLUGIN_ROOT/conventions-seed"
mkdir -p "$CONV_DIR/frontend" "$CONV_DIR/backend"

# Stub convention files (just need to exist)
touch "$CONV_DIR/frontend/react.md"
touch "$CONV_DIR/frontend/nextjs.md"
touch "$CONV_DIR/backend/supabase.md"
touch "$CONV_DIR/backend/node.md"

# index.json: 2 conventions, 2 signals each.
# React: file_exists package.json AND file_contains @supabase/ssr (for supabase)
# Test layers stored in a "tests" field (design decision: inline in same entry).
cat > "$CONV_DIR/index.json" <<'ENDJSON'
[
  {
    "convention": "frontend/react.md",
    "signals": [
      {"file_exists": "package.json"},
      {"file_contains": {"file": "package.json", "pattern": "\"react\""}}
    ],
    "tests": ["jest", "vitest"]
  },
  {
    "convention": "backend/supabase.md",
    "signals": [
      {"file_contains": {"file": "package.json", "pattern": "@supabase/ssr"}},
      {"file_contains": {"file": "package.json", "pattern": "@supabase/supabase-js"}}
    ],
    "tests": ["jest"]
  },
  {
    "convention": "backend/node.md",
    "signals": [
      {"file_exists": "package.json"},
      {"file_contains": {"file": "package.json", "pattern": "\"express\""}}
    ],
    "tests": ["jest", "bun:test"]
  },
  {
    "convention": "frontend/nextjs.md",
    "signals": [
      {"file_contains": {"file": "package.json", "pattern": "\"next\""}}
    ],
    "tests": ["jest", "vitest"]
  }
]
ENDJSON

# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------
run_detect() {
  # $1 = project dir, rest = extra flags
  proj="$1"; shift
  sh "$SCRIPT" --project-dir "$proj" "$@" 2>/dev/null
}

assert_contains() {
  label="$1"; needle="$2"; haystack="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    pass "$label"
  else
    fail "$label — expected to find [$needle] in [$haystack]"
  fi
}

assert_not_contains() {
  label="$1"; needle="$2"; haystack="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    fail "$label — did NOT expect [$needle] in [$haystack]"
  else
    pass "$label"
  fi
}

assert_empty() {
  label="$1"; val="$2"
  if [ -z "$val" ]; then
    pass "$label"
  else
    fail "$label — expected empty, got [$val]"
  fi
}

# ---------------------------------------------------------------------------
# Scenario A: project with package.json containing "react" → react.md + node.md match
# ---------------------------------------------------------------------------
PROJ_A="$TMPROOT/proj-a"
mkdir -p "$PROJ_A"
cat > "$PROJ_A/package.json" <<'EOF'
{
  "dependencies": {
    "react": "^18.0.0",
    "react-dom": "^18.0.0"
  }
}
EOF

actual=$(CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" run_detect "$PROJ_A")
assert_contains "react project → frontend/react.md" "$CONV_DIR/frontend/react.md" "$actual"
assert_contains "react project → backend/node.md" "$CONV_DIR/backend/node.md" "$actual"
assert_not_contains "react project → NOT frontend/nextjs.md" "$CONV_DIR/frontend/nextjs.md" "$actual"

# ---------------------------------------------------------------------------
# Scenario B: project with Next.js → nextjs.md matches (and react.md, node.md)
# ---------------------------------------------------------------------------
PROJ_B="$TMPROOT/proj-b"
mkdir -p "$PROJ_B"
cat > "$PROJ_B/package.json" <<'EOF'
{
  "dependencies": {
    "next": "^14.0.0",
    "react": "^18.0.0"
  }
}
EOF

actual=$(CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" run_detect "$PROJ_B")
assert_contains "next project → frontend/nextjs.md" "$CONV_DIR/frontend/nextjs.md" "$actual"
assert_contains "next project → frontend/react.md" "$CONV_DIR/frontend/react.md" "$actual"

# ---------------------------------------------------------------------------
# Scenario C: project with Supabase → supabase.md
# ---------------------------------------------------------------------------
PROJ_C="$TMPROOT/proj-c"
mkdir -p "$PROJ_C"
cat > "$PROJ_C/package.json" <<'EOF'
{
  "dependencies": {
    "next": "^14.0.0",
    "@supabase/ssr": "^0.3.0"
  }
}
EOF

actual=$(CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" run_detect "$PROJ_C")
assert_contains "supabase project → backend/supabase.md" "$CONV_DIR/backend/supabase.md" "$actual"

# ---------------------------------------------------------------------------
# Scenario D: project with NO package.json → no matches
# ---------------------------------------------------------------------------
PROJ_D="$TMPROOT/proj-d"
mkdir -p "$PROJ_D"

actual=$(CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" run_detect "$PROJ_D")
assert_empty "no package.json → no matches" "$actual"

# ---------------------------------------------------------------------------
# Scenario E: --tests flag for react project → jest and/or vitest
# ---------------------------------------------------------------------------
actual=$(CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" run_detect "$PROJ_A" --tests)
assert_contains "react --tests → jest" "jest" "$actual"
assert_contains "react --tests → vitest" "vitest" "$actual"

# ---------------------------------------------------------------------------
# Scenario F: --tests flag for supabase project → jest
# ---------------------------------------------------------------------------
actual=$(CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" run_detect "$PROJ_C" --tests)
assert_contains "supabase --tests → jest" "jest" "$actual"

# ---------------------------------------------------------------------------
# Scenario G: missing index.json → empty output (exit 0, warning to stderr)
# ---------------------------------------------------------------------------
EMPTY_ROOT="$TMPROOT/empty-plugin"
mkdir -p "$EMPTY_ROOT/conventions-seed"
actual=$(CLAUDE_PLUGIN_ROOT="$EMPTY_ROOT" run_detect "$PROJ_A" 2>/dev/null)
assert_empty "missing index.json → empty output" "$actual"

# Check exit code is 0
if CLAUDE_PLUGIN_ROOT="$EMPTY_ROOT" sh "$SCRIPT" --project-dir "$PROJ_A" 2>/dev/null; then
  pass "missing index.json → exit 0"
else
  fail "missing index.json → should exit 0 not fail"
fi

# ---------------------------------------------------------------------------
# Scenario H: malformed index.json → exit 2
# ---------------------------------------------------------------------------
BAD_ROOT="$TMPROOT/bad-plugin"
mkdir -p "$BAD_ROOT/conventions-seed"
printf 'not valid json at all }{' > "$BAD_ROOT/conventions-seed/index.json"
if CLAUDE_PLUGIN_ROOT="$BAD_ROOT" sh "$SCRIPT" --project-dir "$PROJ_A" 2>/dev/null; then
  fail "malformed json → should exit 2"
else
  CODE=$?
  if [ "$CODE" -eq 2 ]; then
    pass "malformed json → exit 2"
  else
    fail "malformed json → expected exit 2, got $CODE"
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
