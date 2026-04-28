#!/bin/sh
# bin/test-devteam-watchlist.sh
# Smoke test for devteam-watchlist.sh.
# Seeds a tmp slack.md with mixed dated lines, runs analyzer, asserts output.
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SCRIPT="$SCRIPT_DIR/devteam-watchlist.sh"

PASS=0
FAIL=0

pass() { PASS=$((PASS+1)); printf "OK: %s\n" "$1"; }
fail() { FAIL=$((FAIL+1)); printf "FAIL: %s\n" "$1"; }

assert_contains() {
  label="$1"; needle="$2"; haystack="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    pass "$label"
  else
    fail "$label — expected [$needle] in output: [$haystack]"
  fi
}

assert_not_contains() {
  label="$1"; needle="$2"; haystack="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    fail "$label — did NOT expect [$needle] in: [$haystack]"
  else
    pass "$label"
  fi
}

# ---------------------------------------------------------------------------
# Helpers to create dated slack lines
# The format (from slack-append.sh) is:
#   #YY-MM-DD-HH-MM-SS  YYYY-MM-DD HH:MM:SS  [ACTOR#NN] WATCHLIST  signal=...  detail=...
# ---------------------------------------------------------------------------

# today_minus <N> → YYYY-MM-DD N days ago, using python3 for portability
days_ago() {
  python3 -W ignore -c "
import datetime
d = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=$1)
print(d.strftime('%Y-%m-%d %H:%M:%S'))
"
}

make_entry() {
  ts="$1"; signal="$2"; actor="${3:-LEAD}"
  id=$(echo "$ts" | sed 's/[-: ]/-/g' | cut -c1-17)
  printf "#%s  %s  [%s#1] WATCHLIST  signal=%s  detail=test\n" "$id" "$ts" "$actor" "$signal"
}

# ---------------------------------------------------------------------------
# Scenario A: ALL CLEAR — signals present but below thresholds
# ---------------------------------------------------------------------------
TMPROOT=$(mktemp -d)
trap 'rm -rf "$TMPROOT"' EXIT INT TERM

STATE="$TMPROOT/a/.devteam/state"
mkdir -p "$STATE"
SLACK="$STATE/slack.md"

# 3a-malformed-output threshold is 3; put only 2 within 14 days
make_entry "$(days_ago 2)" "3a-malformed-output" >> "$SLACK"
make_entry "$(days_ago 5)" "3a-malformed-output" >> "$SLACK"
# 3a-tier-flag-override threshold is 5; put only 4 within 14 days
make_entry "$(days_ago 1)" "3a-tier-flag-override" >> "$SLACK"
make_entry "$(days_ago 3)" "3a-tier-flag-override" >> "$SLACK"
make_entry "$(days_ago 6)" "3a-tier-flag-override" >> "$SLACK"
make_entry "$(days_ago 10)" "3a-tier-flag-override" >> "$SLACK"
# 3b-manual-log threshold is 2; put only 1 within 14 days
make_entry "$(days_ago 4)" "3b-manual-log" >> "$SLACK"

actual=$(DEVTEAM_STATE_DIR="$STATE" sh "$SCRIPT" 2>/dev/null)
assert_contains "all-clear scenario → ALL CLEAR" "ALL CLEAR" "$actual"
assert_not_contains "all-clear scenario → no ALERT" "ALERT" "$actual"

# ---------------------------------------------------------------------------
# Scenario B: 3a-malformed-output alert (3 in 14 days)
# ---------------------------------------------------------------------------
STATE="$TMPROOT/b/.devteam/state"
mkdir -p "$STATE"
SLACK="$STATE/slack.md"

make_entry "$(days_ago 1)" "3a-malformed-output" >> "$SLACK"
make_entry "$(days_ago 3)" "3a-malformed-output" >> "$SLACK"
make_entry "$(days_ago 7)" "3a-malformed-output" >> "$SLACK"

actual=$(DEVTEAM_STATE_DIR="$STATE" sh "$SCRIPT" 2>/dev/null)
assert_contains "3a-malformed-output alert" "ALERT" "$actual"
assert_contains "3a-malformed-output mentions signal" "3a-malformed-output" "$actual"

# ---------------------------------------------------------------------------
# Scenario C: 3a-tier-flag-override alert (5 in 14 days)
# ---------------------------------------------------------------------------
STATE="$TMPROOT/c/.devteam/state"
mkdir -p "$STATE"
SLACK="$STATE/slack.md"

make_entry "$(days_ago 1)" "3a-tier-flag-override" >> "$SLACK"
make_entry "$(days_ago 2)" "3a-tier-flag-override" >> "$SLACK"
make_entry "$(days_ago 4)" "3a-tier-flag-override" >> "$SLACK"
make_entry "$(days_ago 8)" "3a-tier-flag-override" >> "$SLACK"
make_entry "$(days_ago 12)" "3a-tier-flag-override" >> "$SLACK"

actual=$(DEVTEAM_STATE_DIR="$STATE" sh "$SCRIPT" 2>/dev/null)
assert_contains "3a-tier-flag-override alert" "ALERT" "$actual"
assert_contains "3a-tier-flag-override mentions signal" "3a-tier-flag-override" "$actual"

# ---------------------------------------------------------------------------
# Scenario D: 3b-manual-log alert (2 in 14 days)
# ---------------------------------------------------------------------------
STATE="$TMPROOT/d/.devteam/state"
mkdir -p "$STATE"
SLACK="$STATE/slack.md"

make_entry "$(days_ago 3)" "3b-manual-log" >> "$SLACK"
make_entry "$(days_ago 9)" "3b-manual-log" >> "$SLACK"

actual=$(DEVTEAM_STATE_DIR="$STATE" sh "$SCRIPT" 2>/dev/null)
assert_contains "3b-manual-log alert" "ALERT" "$actual"
assert_contains "3b-manual-log mentions signal" "3b-manual-log" "$actual"

# ---------------------------------------------------------------------------
# Scenario E: old entries do NOT count — all 3 malformed-output entries > 14 days
# ---------------------------------------------------------------------------
STATE="$TMPROOT/e/.devteam/state"
mkdir -p "$STATE"
SLACK="$STATE/slack.md"

make_entry "$(days_ago 15)" "3a-malformed-output" >> "$SLACK"
make_entry "$(days_ago 20)" "3a-malformed-output" >> "$SLACK"
make_entry "$(days_ago 30)" "3a-malformed-output" >> "$SLACK"

actual=$(DEVTEAM_STATE_DIR="$STATE" sh "$SCRIPT" 2>/dev/null)
assert_contains "old entries ignored → ALL CLEAR" "ALL CLEAR" "$actual"
assert_not_contains "old entries ignored → no ALERT" "ALERT" "$actual"

# ---------------------------------------------------------------------------
# Scenario F: archive files are also scanned
# ---------------------------------------------------------------------------
STATE="$TMPROOT/f/.devteam/state"
mkdir -p "$STATE/archive"
SLACK="$STATE/slack.md"
ARCHIVE="$STATE/archive/slack-old.md"

# 1 in main slack + 2 in archive = 3 total → alert
make_entry "$(days_ago 2)" "3a-malformed-output" >> "$SLACK"
make_entry "$(days_ago 5)" "3a-malformed-output" >> "$ARCHIVE"
make_entry "$(days_ago 8)" "3a-malformed-output" >> "$ARCHIVE"

actual=$(DEVTEAM_STATE_DIR="$STATE" sh "$SCRIPT" 2>/dev/null)
assert_contains "archive scan fires alert" "ALERT" "$actual"
assert_contains "archive alert mentions signal" "3a-malformed-output" "$actual"

# ---------------------------------------------------------------------------
# Scenario G: mixed: one ALERT, others below threshold
# ---------------------------------------------------------------------------
STATE="$TMPROOT/g/.devteam/state"
mkdir -p "$STATE"
SLACK="$STATE/slack.md"

# 3b-manual-log = 2 → alert
make_entry "$(days_ago 1)" "3b-manual-log" >> "$SLACK"
make_entry "$(days_ago 2)" "3b-manual-log" >> "$SLACK"
# 3a-malformed-output = 2 → below threshold (need 3)
make_entry "$(days_ago 1)" "3a-malformed-output" >> "$SLACK"
make_entry "$(days_ago 3)" "3a-malformed-output" >> "$SLACK"

actual=$(DEVTEAM_STATE_DIR="$STATE" sh "$SCRIPT" 2>/dev/null)
assert_contains "mixed: 3b alert present" "3b-manual-log" "$actual"
assert_not_contains "mixed: 3a-malformed not alerted" "3a-malformed-output" "$actual"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
