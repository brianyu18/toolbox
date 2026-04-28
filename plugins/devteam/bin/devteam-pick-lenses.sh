#!/bin/sh
# bin/devteam-pick-lenses.sh
# Given a git diff, emit REVIEW lens names (one per line) that apply.
# Used by LEAD to dispatch parallel review-specialist workers.
# Ref: plan Resolved decisions A1-final, F-1, F-2.
set -eu

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Detect which review lenses apply to the current git diff.
Outputs one lens name per line (empty = no lenses → LEAD skips REVIEW).

OPTIONS:
  --base <ref>   Base git ref for diff (default: HEAD)
  --head <ref>   Head git ref for diff (default: working tree)
  -v, --verbose  Log which trigger fired (to stderr)
  -h, --help     Show this help

LENSES: security  perf  testing  a11y  data-migration  api-contract
EOF
}

BASE="HEAD"
HEAD_REF=""
VERBOSE=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -v|--verbose) VERBOSE=1; shift ;;
    --base) BASE="$2"; shift 2 ;;
    --head) HEAD_REF="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

log_verbose() {
  if [ "$VERBOSE" -eq 1 ]; then
    printf "[pick-lenses] %s\n" "$1" >&2
  fi
}

# Build diff command
if [ -n "$HEAD_REF" ]; then
  FILES=$(git diff --name-only "$BASE" "$HEAD_REF" 2>/dev/null || true)
  DIFF_CMD="git diff $BASE $HEAD_REF"
else
  FILES=$(git diff --name-only "$BASE" 2>/dev/null || true)
  DIFF_CMD="git diff $BASE"
fi

# Collect matched content lines for pattern matching (avoid repeated diff calls)
CONTENT=""
if [ -n "$FILES" ]; then
  if [ -n "$HEAD_REF" ]; then
    CONTENT=$(git diff "$BASE" "$HEAD_REF" 2>/dev/null || true)
  else
    CONTENT=$(git diff "$BASE" 2>/dev/null || true)
  fi
fi

# Track which lenses fired (using simple variables, POSIX-portable)
L_SECURITY=0
L_PERF=0
L_TESTING=0
L_A11Y=0
L_DATAMIG=0
L_APICONTRACT=0

# Helper: check if any file in FILES matches a pattern
files_match() {
  echo "$FILES" | grep -qE "$1" 2>/dev/null || return 1
}

# Helper: check if diff content matches a pattern
content_match() {
  echo "$CONTENT" | grep -qE "$1" 2>/dev/null || return 1
}

if [ -n "$FILES" ]; then

  # ---- security ----
  if files_match 'auth|login|session|signup|signin'; then
    log_verbose "security: path match (auth|login|session|signup|signin)"
    L_SECURITY=1
  fi
  if echo "$FILES" | grep -qE '\.env' 2>/dev/null; then
    log_verbose "security: .env file"
    L_SECURITY=1
  fi
  if content_match 'password|secret|bcrypt|jwt|crypto|sanitize|xss|sql injection'; then
    log_verbose "security: content match (password/secret/bcrypt/jwt/crypto/sanitize/xss/sql injection)"
    L_SECURITY=1
  fi

  # ---- perf ----
  if files_match 'app/api|server/|lib/|backend/|db/|sql/'; then
    log_verbose "perf: path match (app/api|server/|lib/|backend/|db/|sql/)"
    L_PERF=1
  fi
  if echo "$FILES" | grep -qE '\.sql$' 2>/dev/null; then
    log_verbose "perf: .sql extension"
    L_PERF=1
  fi
  # files >300 lines changed: check via diff stat
  LINES_CHANGED=$(echo "$CONTENT" | grep -cE '^\+[^+]|^-[^-]' 2>/dev/null || echo 0)
  if [ "$LINES_CHANGED" -gt 300 ]; then
    log_verbose "perf: >300 lines changed ($LINES_CHANGED)"
    L_PERF=1
  fi

  # ---- testing ----
  # Fire if ANY non-test source file changed
  # Non-test = not matching __tests__|*test*|*spec*|/test/
  NON_TEST=$(echo "$FILES" | grep -vE '__tests__|test|spec|/test/' 2>/dev/null || true)
  if [ -n "$NON_TEST" ]; then
    log_verbose "testing: non-test source file changed"
    L_TESTING=1
  fi

  # ---- a11y ----
  if files_match '\.tsx?$|\.jsx?$|\.html$|\.css$|\.scss$|\.svelte$|\.vue$'; then
    log_verbose "a11y: UI file extension"
    L_A11Y=1
  fi

  # ---- data-migration ----
  if files_match 'migrations/|db/migrations/'; then
    log_verbose "data-migration: migrations path"
    L_DATAMIG=1
  fi
  if content_match 'ALTER TABLE|CREATE POLICY|DROP TABLE|CREATE TABLE.*REFERENCES'; then
    log_verbose "data-migration: DDL content match"
    L_DATAMIG=1
  fi

  # ---- api-contract ----
  if files_match 'app/api/|app/.*/route\.(ts|js)|pages/api/'; then
    log_verbose "api-contract: API path match"
    L_APICONTRACT=1
  fi
  if content_match '^[+]export (async )?function (GET|POST|PUT|DELETE|PATCH)'; then
    log_verbose "api-contract: HTTP handler export"
    L_APICONTRACT=1
  fi

fi

# Emit matched lenses (each printed once)
if [ "$L_SECURITY"    -eq 1 ]; then echo "security"; fi
if [ "$L_PERF"        -eq 1 ]; then echo "perf"; fi
if [ "$L_TESTING"     -eq 1 ]; then echo "testing"; fi
if [ "$L_A11Y"        -eq 1 ]; then echo "a11y"; fi
if [ "$L_DATAMIG"     -eq 1 ]; then echo "data-migration"; fi
if [ "$L_APICONTRACT" -eq 1 ]; then echo "api-contract"; fi
