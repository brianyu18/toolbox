#!/bin/sh
# bin/test-devteam-pick-lenses.sh
# Smoke test for devteam-pick-lenses.sh
# Creates a tmp git repo, stages various file combinations, asserts lens output.
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SCRIPT="$SCRIPT_DIR/devteam-pick-lenses.sh"
PASS=0
FAIL=0

pass() { PASS=$((PASS+1)); printf "OK: %s\n" "$1"; }
fail() { FAIL=$((FAIL+1)); printf "FAIL: %s\n" "$1"; }

assert_lenses() {
  # assert_lenses <label> <expected_sorted> <actual_sorted>
  label="$1"; expected="$2"; actual="$3"
  if [ "$expected" = "$actual" ]; then
    pass "$label"
  else
    fail "$label — expected: [$expected] got: [$actual]"
  fi
}

# ---------------------------------------------------------------------------
# Set up a throw-away git repo
# ---------------------------------------------------------------------------
TMPROOT=$(mktemp -d)
trap 'rm -rf "$TMPROOT"' EXIT INT TERM

REPO="$TMPROOT/repo"
mkdir -p "$REPO"
cd "$REPO"
git init -q
git config user.email "test@test.com"
git config user.name "Test"

# Helper: run lenses script from $REPO comparing HEAD..WORK
run_lenses() {
  sh "$SCRIPT" "$@" 2>/dev/null | sort || true
}

# ---------------------------------------------------------------------------
# Scenario 0: empty diff → no lenses
# ---------------------------------------------------------------------------
touch init.txt
git add init.txt
git commit -q -m "init"

actual=$(run_lenses)
assert_lenses "empty diff → no lenses" "" "$actual"

# ---------------------------------------------------------------------------
# Scenario 1: security — auth path
# ---------------------------------------------------------------------------
mkdir -p app/auth
cat > app/auth/login.ts <<'EOF'
export function login() { /* password check */ }
EOF
git add app/auth/login.ts
git commit -q -m "add login"

actual=$(run_lenses --base HEAD~1 --head HEAD)
# expect: a11y (tsx? — no, it's .ts which matches tsx?), security, testing
# .ts matches \.tsx?  yes. also non-test file → testing. auth path → security.
expected=$(printf "a11y\nsecurity\ntesting" | sort)
assert_lenses "auth file → security+testing+a11y" "$expected" "$actual"

# ---------------------------------------------------------------------------
# Scenario 2: data migration path
# ---------------------------------------------------------------------------
mkdir -p db/migrations
cat > db/migrations/001_add_users.sql <<'EOF'
ALTER TABLE users ADD COLUMN verified boolean;
EOF
git add db/migrations/001_add_users.sql
git commit -q -m "add migration"

actual=$(run_lenses --base HEAD~1 --head HEAD)
# .sql → perf. db/migrations/ → data-migration. ALTER TABLE in content → data-migration.
# .sql file is non-test → testing also fires.
expected=$(printf "data-migration\nperf\ntesting" | sort)
assert_lenses "migration sql → data-migration+perf+testing" "$expected" "$actual"

# ---------------------------------------------------------------------------
# Scenario 3: API route → api-contract
# ---------------------------------------------------------------------------
mkdir -p app/api/users
cat > app/api/users/route.ts <<'EOF'
export async function GET(req) { return Response.json({}) }
export async function POST(req) { return Response.json({}) }
EOF
git add app/api/users/route.ts
git commit -q -m "add api route"

actual=$(run_lenses --base HEAD~1 --head HEAD)
# app/api path → perf+api-contract; export GET/POST content → api-contract; .ts → a11y; non-test → testing
expected=$(printf "a11y\napi-contract\nperf\ntesting" | sort)
assert_lenses "api route.ts → api-contract+perf+a11y+testing" "$expected" "$actual"

# ---------------------------------------------------------------------------
# Scenario 4: test file only → testing lens NOT fired
# ---------------------------------------------------------------------------
mkdir -p __tests__
cat > __tests__/foo.test.ts <<'EOF'
test("foo", () => expect(1).toBe(1));
EOF
git add __tests__/foo.test.ts
git commit -q -m "add test file"

actual=$(run_lenses --base HEAD~1 --head HEAD)
# test file → a11y fires (it's .ts), but NOT testing (it's a test file)
expected=$(printf "a11y" | sort)
assert_lenses "test file only → a11y but not testing" "$expected" "$actual"

# ---------------------------------------------------------------------------
# Scenario 5: .env file → security
# ---------------------------------------------------------------------------
cat > .env.local <<'EOF'
DATABASE_URL=postgres://...
EOF
git add .env.local
git commit -q -m "add env"

actual=$(run_lenses --base HEAD~1 --head HEAD)
# .env is non-test → testing fires too
expected=$(printf "security\ntesting" | sort)
assert_lenses ".env file → security+testing" "$expected" "$actual"

# ---------------------------------------------------------------------------
# Scenario 6: CSS file → a11y only
# ---------------------------------------------------------------------------
cat > styles.css <<'EOF'
body { margin: 0; }
EOF
git add styles.css
git commit -q -m "add css"

actual=$(run_lenses --base HEAD~1 --head HEAD)
# .css is non-test → testing fires too
expected=$(printf "a11y\ntesting" | sort)
assert_lenses ".css → a11y+testing" "$expected" "$actual"

# ---------------------------------------------------------------------------
# Scenario 7: -h / --help flag doesn't crash and exits 0
# ---------------------------------------------------------------------------
if sh "$SCRIPT" --help >/dev/null 2>&1; then
  pass "--help exits 0"
else
  fail "--help exits non-zero"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
